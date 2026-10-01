"""HTTP API in front of the COBOL Core Banking System.

Writes and single-record reads go to COBOL (bin/cbs-api) - the system
of record. List/search reads (history, accounts of a customer, audit)
come from the MongoDB read model, which is synced from the COBOL files
after every write and before every list read.
"""
from __future__ import annotations

import logging
import re
from contextlib import asynccontextmanager
from decimal import Decimal

from bson.decimal128 import Decimal128
from fastapi import Depends, FastAPI, Header, HTTPException, Path, Query
from fastapi import Request
from fastapi.responses import JSONResponse
from pymongo.errors import PyMongoError

from . import idempotency
from .auth import Principal, require
from .cobol import CobolBridge, CobolBridgeError, CobolResult
from .config import Settings, load_settings
from .db import connect, ensure_indexes
from .schemas import (AccountCreate, CustomerCreate, DailyRun, Movement,
                      Reversal, StatusChange, Transfer)
from .sync import Projector, account_doc, customer_doc

log = logging.getLogger("cbs.api")
if not logging.getLogger("cbs").handlers:          # app log lines
    _h = logging.StreamHandler()
    _h.setFormatter(logging.Formatter("%(levelname)s: %(name)s: %(message)s"))
    logging.getLogger("cbs").addHandler(_h)
    logging.getLogger("cbs").setLevel(logging.INFO)

# COBOL status code -> HTTP status (see docs/api.md)
HTTP_FOR = {0: 200, 101: 400, 107: 400, 102: 404, 103: 409, 106: 409,
            104: 422, 105: 422, 110: 422, 108: 500, 109: 500}

ID = r"^[A-Za-z0-9_-]{1,15}$"        # path ids: transport-safe only
teller = require("teller")
supervisor = require("supervisor")


def money(v) -> str | None:
    if v is None:
        return None
    if isinstance(v, Decimal128):
        v = v.to_decimal()
    return str(Decimal(v).quantize(Decimal("0.01")))


def jsonable(doc: dict) -> dict:
    out = {}
    for k, v in doc.items():
        out["id" if k == "_id" else k] = (
            money(v) if isinstance(v, Decimal128) else v)
    return out


def error_body(r: CobolResult) -> dict:
    return {"error": {"code": f"{r.code:03d}", "name": r.name,
                      "field": r.error_field or None,
                      "message": r.message}}


def create_app(settings: Settings | None = None, db=None) -> FastAPI:
    settings = settings or load_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.settings = settings
        app.state.db = db if db is not None else connect(
            settings.mongo_uri, settings.mongo_db)
        app.state.bridge = CobolBridge(settings)
        app.state.projector = Projector(app.state.db, app.state.bridge)
        try:
            ensure_indexes(app.state.db)
            app.state.projector.sync()
        except PyMongoError as exc:     # start anyway; /health shows it
            log.error("MongoDB not ready at start-up: %s", exc)
        yield

    app = FastAPI(title="COBOL Core Banking API", version="1.0.0",
                  description="Personal project - fictional data only. "
                              "Not a production banking system.",
                  lifespan=lifespan)

    @app.exception_handler(PyMongoError)
    async def mongo_down(_: Request, exc: PyMongoError):
        log.error("MongoDB error: %s", exc)
        return JSONResponse(status_code=503, content={"error": {
            "code": "DB_UNAVAILABLE", "message": "database unavailable"}})

    @app.exception_handler(CobolBridgeError)
    async def cobol_down(_: Request, exc: CobolBridgeError):
        log.error("COBOL bridge error: %s", exc)
        return JSONResponse(status_code=503, content={"error": {
            "code": "CORE_UNAVAILABLE",
            "message": "core banking engine unavailable"}})

    # ---------------------------------------------------------------
    def st(request: Request):
        return request.app.state

    def call(request: Request, *fields: str) -> CobolResult:
        return st(request).bridge.call(*fields)

    def sync_quietly(request: Request) -> None:
        """Projection lag is acceptable; a failed sync must never turn
        an already-posted transaction into an error response."""
        try:
            st(request).projector.sync()
        except PyMongoError as exc:
            log.error("read-model sync failed (will retry): %s", exc)

    def reply(r: CobolResult, ok_status: int, body: dict) -> tuple:
        if r.ok:
            return ok_status, body
        return HTTP_FOR.get(r.code, 500), error_body(r)

    def respond(status: int, body: dict, replayed: bool = False):
        headers = {"Idempotent-Replayed": "true"} if replayed else None
        return JSONResponse(status_code=status, content=body,
                            headers=headers)

    def posting(r: CobolResult, two_sided: bool = False) -> dict:
        body = {"transaction_id": r.txn_id, "message": r.message}
        if two_sided:
            body["source_balance"] = money(r.source_balance)
            body["destination_balance"] = money(r.dest_balance)
        else:
            body["balance"] = money(r.new_balance)
        if r.warning:
            body["warning"] = r.warning
        return body

    def money_move(request, who, key, endpoint, payload, fields,
                   two_sided=False):
        s = st(request)
        with s.bridge.exclusive():
            def execute():
                r = s.bridge.call(*fields)
                if r.ok:
                    sync_quietly(request)
                return reply(r, 201, posting(r, two_sided))
            status, body, replayed = idempotency.run(
                s.db, who, key, endpoint, payload, execute)
        return respond(status, body, replayed)

    # --- health -------------------------------------------------------
    @app.get("/health", tags=["ops"])
    def health(request: Request):
        s = st(request)
        checks = {"cobol": s.settings.cobol_bin.exists()}
        try:
            s.db.command("ping")
            checks["mongodb"] = True
        except Exception:                        # noqa: BLE001
            checks["mongodb"] = False
        ok = all(checks.values())
        return JSONResponse(status_code=200 if ok else 503,
                            content={"status": "ok" if ok else "degraded",
                                     "checks": checks})

    # --- customers ----------------------------------------------------
    @app.post("/v1/customers", status_code=201, tags=["customers"])
    def create_customer(body: CustomerCreate, request: Request,
                        who: Principal = Depends(teller)):
        r = call(request, "CUST", body.customer_id.upper(),
                 body.full_name, body.phone, body.email,
                 body.date_of_birth.strftime("%Y%m%d"), who.operator)
        if not r.ok:
            return respond(*reply(r, 201, {}))
        sync_quietly(request)
        got = call(request, "GETCUST", body.customer_id.upper())
        return respond(201, jsonable(customer_doc(got.records["CUSTOMER"])))

    @app.get("/v1/customers/{customer_id}", tags=["customers"])
    def get_customer(request: Request,
                     customer_id: str = Path(pattern=ID),
                     who: Principal = Depends(teller)):
        r = call(request, "GETCUST", customer_id.upper())
        if not r.ok:
            return respond(*reply(r, 200, {}))
        return jsonable(customer_doc(r.records["CUSTOMER"]))

    @app.get("/v1/customers/{customer_id}/accounts", tags=["customers"])
    def customer_accounts(request: Request,
                          customer_id: str = Path(pattern=ID),
                          who: Principal = Depends(teller)):
        sync_quietly(request)
        docs = st(request).db.accounts.find(
            {"customer_id": customer_id.upper()}).sort("_id", 1)
        return {"customer_id": customer_id.upper(),
                "accounts": [jsonable(d) for d in docs]}

    # --- accounts -----------------------------------------------------
    @app.post("/v1/accounts", status_code=201, tags=["accounts"])
    def create_account(body: AccountCreate, request: Request,
                       who: Principal = Depends(teller)):
        r = call(request, "ACCT", body.account_number,
                 body.customer_id.upper(), body.type.upper(),
                 (body.currency or "").upper(),
                 str(body.overdraft_limit), who.operator)
        if not r.ok:
            return respond(*reply(r, 201, {}))
        sync_quietly(request)
        got = call(request, "GETACCT", body.account_number)
        return respond(201, jsonable(account_doc(got.records["ACCOUNT"])))

    @app.get("/v1/accounts/{account}", tags=["accounts"])
    def get_account(request: Request, account: str = Path(pattern=ID),
                    who: Principal = Depends(teller)):
        r = call(request, "GETACCT", account)
        if not r.ok:
            return respond(*reply(r, 200, {}))
        return jsonable(account_doc(r.records["ACCOUNT"]))

    @app.patch("/v1/accounts/{account}/status", tags=["accounts"])
    def set_status(body: StatusChange, request: Request,
                   account: str = Path(pattern=ID),
                   who: Principal = Depends(supervisor)):
        r = call(request, "STAT", account, body.status, who.operator)
        if not r.ok:
            return respond(*reply(r, 200, {}))
        sync_quietly(request)
        return jsonable(account_doc(r.records["ACCOUNT"]))

    @app.get("/v1/accounts/{account}/transactions", tags=["accounts"])
    def history(request: Request, account: str = Path(pattern=ID),
                limit: int = Query(50, ge=1, le=500),
                before: str | None = Query(None, pattern=ID),
                who: Principal = Depends(teller)):
        r = call(request, "GETACCT", account)       # 404 if unknown
        if not r.ok:
            return respond(*reply(r, 200, {}))
        sync_quietly(request)
        query: dict = {"accounts": account}
        if before:
            query["_id"] = {"$lt": before}
        docs = list(st(request).db.transactions.find(query)
                    .sort("_id", -1).limit(limit))
        items = [jsonable(d) for d in docs]
        return {"account": account, "count": len(items),
                "next_before": items[-1]["id"] if len(items) == limit
                else None,
                "transactions": items}

    # --- money movement (idempotent) ------------------------------
    @app.post("/v1/accounts/{account}/deposits", status_code=201,
              tags=["transactions"])
    def deposit(body: Movement, request: Request,
                account: str = Path(pattern=ID),
                idempotency_key: str | None = Header(None),
                who: Principal = Depends(teller)):
        return money_move(request, who, idempotency_key, "deposit",
                          {"account": account, **body.model_dump()},
                          ("DEP", account, str(body.amount),
                           body.reference, who.operator))

    @app.post("/v1/accounts/{account}/withdrawals", status_code=201,
              tags=["transactions"])
    def withdraw(body: Movement, request: Request,
                 account: str = Path(pattern=ID),
                 idempotency_key: str | None = Header(None),
                 who: Principal = Depends(teller)):
        return money_move(request, who, idempotency_key, "withdrawal",
                          {"account": account, **body.model_dump()},
                          ("WDL", account, str(body.amount),
                           body.reference, who.operator))

    @app.post("/v1/transfers", status_code=201, tags=["transactions"])
    def transfer(body: Transfer, request: Request,
                 idempotency_key: str | None = Header(None),
                 who: Principal = Depends(teller)):
        return money_move(request, who, idempotency_key, "transfer",
                          body.model_dump(),
                          ("TRF", body.source_account,
                           body.destination_account, str(body.amount),
                           body.reference, who.operator),
                          two_sided=True)

    @app.post("/v1/transactions/{txn_id}/reversal", status_code=201,
              tags=["transactions"])
    def reverse(body: Reversal, request: Request,
                txn_id: str = Path(pattern=ID),
                idempotency_key: str | None = Header(None),
                who: Principal = Depends(supervisor)):
        return money_move(request, who, idempotency_key, "reversal",
                          {"txn_id": txn_id.upper(), **body.model_dump()},
                          ("REV", txn_id.upper(), body.reference,
                           who.operator))

    @app.get("/v1/transactions/{txn_id}", tags=["transactions"])
    def get_transaction(request: Request, txn_id: str = Path(pattern=ID),
                        who: Principal = Depends(teller)):
        sync_quietly(request)
        doc = st(request).db.transactions.find_one({"_id": txn_id.upper()})
        if not doc:
            raise HTTPException(404, "transaction not found")
        return jsonable(doc)

    # --- reports and audit (supervisor) -------------------------
    @app.post("/v1/reports/daily", tags=["reports"])
    def daily(request: Request, body: DailyRun | None = None,
              who: Principal = Depends(supervisor)):
        day = body.business_date.strftime("%Y%m%d") \
            if body and body.business_date else ""
        r = call(request, "DAILY", day, who.operator)
        if not r.ok:
            return respond(*reply(r, 200, {}))
        sync_quietly(request)
        d = r.records["DAILY"]
        pair = lambda i: {"count": int(d[i]), "value": d[i + 1]}  # noqa
        return {"business_date": d[0], "deposits": pair(1),
                "withdrawals": pair(3), "transfers": pair(5),
                "reversals": pair(7), "total": pair(9),
                "exceptions": {"ledger_records_read": int(d[11]),
                               "malformed_ledger_records": int(d[12]),
                               "rejected_operations": int(d[13]),
                               "large_transactions": int(d[14])},
                "report_file": d[15].rsplit("/", 1)[-1]}

    @app.get("/v1/audit", tags=["reports"])
    def audit(request: Request,
              entity_id: str | None = Query(None, pattern=ID),
              failures_only: bool = False,
              limit: int = Query(100, ge=1, le=1000),
              who: Principal = Depends(supervisor)):
        sync_quietly(request)
        query: dict = {}
        if entity_id:
            query["entity_id"] = entity_id.upper()
        if failures_only:
            query["status_code"] = {"$ne": "000"}
        docs = st(request).db.audit.find(query).sort("_id", -1).limit(limit)
        return {"entries": [jsonable(d) for d in docs]}

    return app


app = create_app()
