"""Projection of the COBOL files into MongoDB (the read model).

The ledger (transactions.dat) and audit trail (audit.log) are
append-only text files, so the projector remembers how many bytes it
has already consumed and only reads what was appended since. From the
new lines it also learns which customers/accounts changed and
refreshes those documents through the COBOL lookups (GETCUST/GETACCT),
because customers.dat/accounts.dat are binary indexed files.

If a file shrank or was replaced (e.g. scripts/reset-data.sh) the whole
read model is dropped and rebuilt from offset 0. Everything here can be
deleted and regenerated: the COBOL files remain the truth.

Must run while holding CobolBridge.exclusive() so the files do not
change underneath it.
"""
from __future__ import annotations

import logging
import os
import re
from dataclasses import dataclass, field
from decimal import Decimal

from bson.decimal128 import Decimal128
from pymongo.database import Database

from .cobol import CobolBridge

log = logging.getLogger("cbs.sync")
TXN_ID = re.compile(r"^TXN\d{12}$")
STATE_ID = "files"


def d128(value: Decimal) -> Decimal128:
    return Decimal128(value.quantize(Decimal("0.01")))


def _minor(text: str) -> Decimal:
    """'+000000000250000' or '000000000250000' -> Decimal('2500.00')."""
    return (Decimal(int(text)) / 100).quantize(Decimal("0.01"))


@dataclass
class SyncStats:
    transactions: int = 0
    audit: int = 0
    malformed: int = 0
    customers: set[str] = field(default_factory=set)
    accounts: set[str] = field(default_factory=set)
    rebuilt: bool = False


class Projector:
    def __init__(self, db: Database, bridge: CobolBridge):
        self.db = db
        self.bridge = bridge
        self.ledger = bridge.settings.data_dir / "transactions.dat"
        self.audit = bridge.settings.data_dir / "audit.log"

    # ---------------------------------------------------------------
    def sync(self, force_rebuild: bool = False) -> SyncStats:
        stats = SyncStats()
        with self.bridge.exclusive():
            state = self.db.sync_state.find_one({"_id": STATE_ID}) or {}
            if force_rebuild or self._replaced(state):
                self._drop_read_model()
                state, stats.rebuilt = {}, True
            led_off = self._consume(self.ledger, state.get("ledger", {}),
                                    self._ledger_line, stats)
            aud_off = self._consume(self.audit, state.get("audit", {}),
                                    self._audit_line, stats)
            for cust in sorted(stats.customers):
                self.refresh_customer(cust)
            for acct in sorted(stats.accounts):
                self.refresh_account(acct)
            self.db.sync_state.replace_one(
                {"_id": STATE_ID},
                {"_id": STATE_ID, "ledger": led_off, "audit": aud_off,
                 "malformed_ledger_lines":
                     state.get("malformed_ledger_lines", 0)
                     + stats.malformed},
                upsert=True)
        if stats.transactions or stats.audit or stats.rebuilt:
            log.info("sync: %d txns, %d audit, %d malformed, rebuilt=%s",
                     stats.transactions, stats.audit, stats.malformed,
                     stats.rebuilt)
        return stats

    def _replaced(self, state: dict) -> bool:
        for path, key in ((self.ledger, "ledger"), (self.audit, "audit")):
            saved = state.get(key)
            if not saved:
                continue
            if not path.exists():
                return True
            st = os.stat(path)
            if st.st_ino != saved["inode"] or st.st_size < saved["offset"]:
                return True
        return False

    def _drop_read_model(self) -> None:
        for name in ("customers", "accounts", "transactions", "audit"):
            self.db[name].delete_many({})
        self.db.sync_state.delete_many({})

    def _consume(self, path, saved, handler, stats) -> dict:
        offset = saved.get("offset", 0)
        line_no = saved.get("lines", 0)
        if not path.exists():
            return {"offset": 0, "lines": 0, "inode": None}
        with open(path, "rb") as fh:
            fh.seek(offset)
            chunk = fh.read()
            inode = os.fstat(fh.fileno()).st_ino
        end = chunk.rfind(b"\n") + 1          # only complete lines
        for raw in chunk[:end].splitlines():
            line_no += 1
            handler(raw.decode("ascii", errors="replace"), line_no, stats)
        return {"offset": offset + end, "lines": line_no, "inode": inode}

    # --- ledger ------------------------------------------------------
    def _ledger_line(self, line: str, line_no: int, stats: SyncStats):
        f = [p.strip() for p in line.split("|")]
        try:
            if len(f) != 14 or not TXN_ID.match(f[0]):
                raise ValueError("layout")
            doc = {
                "_id": f[0], "timestamp": f[1], "business_date": f[2],
                "type": f[3], "source_account": f[4] or None,
                "destination_account": f[5] or None,
                "amount": d128(_minor(f[6])), "currency": f[7],
                "reference": f[8], "status": f[9], "operator": f[10],
                "reversal_of": f[11] or None,
                "source_balance_after":
                    d128(_minor(f[12])) if f[4] else None,
                "destination_balance_after":
                    d128(_minor(f[13])) if f[5] else None,
                "accounts": [a for a in (f[4], f[5]) if a],
                "ledger_line": line_no,
            }
        except (ValueError, ArithmeticError):
            stats.malformed += 1
            log.warning("ledger line %d malformed, not projected", line_no)
            return
        self.db.transactions.replace_one({"_id": doc["_id"]}, doc,
                                         upsert=True)
        stats.transactions += 1
        stats.accounts.update(doc["accounts"])

    # --- audit -------------------------------------------------------
    def _audit_line(self, line: str, line_no: int, stats: SyncStats):
        f = [p.strip() for p in line.split("|")]
        if len(f) != 11 or not f[8].isdigit():
            return
        try:
            amount = d128(_minor(f[5]))
        except (ValueError, ArithmeticError):
            amount = None
        doc = {"_id": line_no, "timestamp": f[0], "date": f[1],
               "operation": f[2], "entity_id": f[3],
               "counterparty": f[4] or None, "amount": amount,
               "txn_id": f[6] or None, "operator": f[7],
               "status_code": f[8], "status_name": f[9],
               "message": f[10]}
        self.db.audit.replace_one({"_id": line_no}, doc, upsert=True)
        stats.audit += 1
        if f[8] == "000":
            if f[2] == "CUSTOMER-CREATE":
                stats.customers.add(f[3])
            elif f[2] in ("ACCOUNT-CREATE", "ACCOUNT-STATUS"):
                stats.accounts.add(f[3])

    # --- refresh from COBOL -----------------------------------------
    def refresh_customer(self, cust_id: str) -> dict | None:
        res = self.bridge.call("GETCUST", cust_id)
        if not res.ok or "CUSTOMER" not in res.records:
            return None
        doc = customer_doc(res.records["CUSTOMER"])
        self.db.customers.replace_one({"_id": doc["_id"]}, doc,
                                      upsert=True)
        return doc

    def refresh_account(self, acct: str) -> dict | None:
        res = self.bridge.call("GETACCT", acct)
        if not res.ok or "ACCOUNT" not in res.records:
            return None
        doc = account_doc(res.records["ACCOUNT"])
        self.db.accounts.replace_one({"_id": doc["_id"]}, doc,
                                     upsert=True)
        return doc


def customer_doc(r: list[str]) -> dict:
    return {"_id": r[0], "full_name": r[1], "phone": r[2], "email": r[3],
            "date_of_birth": r[4], "status": r[5], "created_at": r[6]}


def account_doc(r: list[str]) -> dict:
    return {"_id": r[0], "customer_id": r[1], "type": r[2],
            "currency": r[3], "status": r[4],
            "available_balance": d128(Decimal(r[5])),
            "ledger_balance": d128(Decimal(r[6])),
            "overdraft_limit": d128(Decimal(r[7])),
            "created_date": r[8], "last_updated": r[9],
            "last_txn_id": r[10] or None}
