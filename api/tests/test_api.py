"""End-to-end API tests: HTTP -> FastAPI -> bin/cbs-api (real COBOL)
-> data files, with the read model in mongomock."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal

from tests.conftest import idem, setup_accounts


def dep(e, acct, amount, ref="TEST-DEP", headers=None):
    return e["client"].post(f"/v1/accounts/{acct}/deposits",
                            headers=headers or idem(e["teller"]),
                            json={"amount": amount, "reference": ref})


# --- ops / auth -------------------------------------------------------
def test_health(env):
    r = env["client"].get("/health")
    assert r.status_code == 200
    assert r.json()["checks"] == {"cobol": True, "mongodb": True}


def test_missing_and_invalid_key(env):
    c = env["client"]
    assert c.get("/v1/accounts/1000000001").status_code == 401
    assert c.get("/v1/accounts/1000000001",
                 headers={"X-API-Key": "nope"}).status_code == 401


def test_teller_cannot_use_supervisor_endpoints(env):
    setup_accounts(env)
    c, t = env["client"], env["teller"]
    assert c.patch("/v1/accounts/1000000001/status", headers=t,
                   json={"status": "B"}).status_code == 403
    assert c.post("/v1/reports/daily", headers=t).status_code == 403


def test_revoked_key_rejected(env):
    env["db"].api_keys.update_many({"operator": "TELLER01"},
                                   {"$set": {"active": False}})
    assert env["client"].get("/v1/customers/C0000001",
                             headers=env["teller"]).status_code == 401


# --- customers / accounts --------------------------------------------
def test_customer_lifecycle(env):
    c, t = env["client"], env["teller"]
    body = {"customer_id": "C0000009", "full_name": "Bo Quill",
            "phone": "+15550100009", "email": "bo@example.com",
            "date_of_birth": "1990-01-01"}
    r = c.post("/v1/customers", headers=t, json=body)
    assert r.status_code == 201 and r.json()["full_name"] == "Bo Quill"
    dup = c.post("/v1/customers", headers=t, json=body)
    assert dup.status_code == 409
    assert dup.json()["error"]["code"] == "103"
    bad = c.post("/v1/customers", headers=t,
                 json={**body, "customer_id": "C0000010",
                       "email": "not-an-email"})
    assert bad.status_code == 400
    assert bad.json()["error"]["field"] == "EMAIL"
    assert c.get("/v1/customers/C0000009", headers=t).status_code == 200
    assert c.get("/v1/customers/C0999999", headers=t).status_code == 404


def test_pipe_injection_rejected_before_cobol(env):
    r = env["client"].post("/v1/customers", headers=env["teller"], json={
        "customer_id": "C0000001", "full_name": "A|B",
        "phone": "1", "email": "x", "date_of_birth": "1990-01-01"})
    assert r.status_code == 422


def test_unknown_fields_rejected(env):
    r = env["client"].post("/v1/customers", headers=env["teller"], json={
        "customer_id": "C0000001", "full_name": "Ann Lee",
        "phone": "+15550100001", "email": "a@example.com",
        "date_of_birth": "1990-01-01", "operator": "SUPERV01"})
    assert r.status_code == 422


def test_account_rules_come_from_cobol(env):
    setup_accounts(env)
    c, t = env["client"], env["teller"]
    base = {"account_number": "1000000009", "customer_id": "C0000001",
            "currency": "USD"}
    r = c.post("/v1/accounts", headers=t, json={**base, "type": "XYZ"})
    assert r.status_code == 400 and r.json()["error"]["code"] == "107"
    r = c.post("/v1/accounts", headers=t,
               json={**base, "type": "SAV", "overdraft_limit": "100"})
    assert r.status_code == 400 and r.json()["error"]["code"] == "101"
    r = c.get("/v1/accounts/1000000002", headers=t).json()
    assert r["type"] == "CUR" and r["overdraft_limit"] == "500.00"
    accts = c.get("/v1/customers/C0000001/accounts", headers=t).json()
    assert [a["id"] for a in accts["accounts"]] == [
        "1000000001", "1000000002", "1000000003"]


# --- money movement ---------------------------------------------------
def test_deposit_withdraw_and_errors(env):
    setup_accounts(env)
    c, t = env["client"], env["teller"]
    r = dep(env, "1000000001", "250.75")
    assert r.status_code == 201
    assert r.json()["balance"] == "250.75"
    assert r.json()["transaction_id"].startswith("TXN")
    r = c.post("/v1/accounts/1000000001/withdrawals", headers=idem(t),
               json={"amount": "1000", "reference": "ATM"})
    assert r.status_code == 422
    assert r.json()["error"]["name"] == "INSUFFICIENT_FUNDS"
    assert dep(env, "1000000001", "0").status_code == 400
    assert dep(env, "1000000001", "-5").status_code == 400
    assert dep(env, "9999999999", "5").status_code == 404
    assert dep(env, "1000000001", "1.005").status_code == 422  # 2 dp
    r = c.post("/v1/accounts/1000000002/withdrawals", headers=idem(t),
               json={"amount": 400, "reference": "OVERDRAFT"})
    assert r.status_code == 201 and r.json()["balance"] == "-400.00"


def test_idempotency(env):
    setup_accounts(env)
    h = idem(env["teller"])
    first = dep(env, "1000000001", "100.00", headers=h)
    retry = dep(env, "1000000001", "100.00", headers=h)
    assert first.status_code == retry.status_code == 201
    assert retry.json() == first.json()
    assert retry.headers.get("Idempotent-Replayed") == "true"
    bal = env["client"].get("/v1/accounts/1000000001",
                            headers=env["teller"]).json()
    assert bal["available_balance"] == "100.00"        # not 200
    other = dep(env, "1000000001", "999.00", headers=h)
    assert other.status_code == 422
    nokey = env["client"].post("/v1/accounts/1000000001/deposits",
                               headers=env["teller"],
                               json={"amount": "1", "reference": "X"})
    assert nokey.status_code == 400


def test_transfer_and_history(env):
    setup_accounts(env)
    c, t = env["client"], env["teller"]
    dep(env, "1000000001", "1000")
    r = c.post("/v1/transfers", headers=idem(t), json={
        "source_account": "1000000001",
        "destination_account": "1000000002",
        "amount": "300", "reference": "RENT"})
    assert r.status_code == 201
    assert r.json()["source_balance"] == "700.00"
    assert r.json()["destination_balance"] == "300.00"
    fx = c.post("/v1/transfers", headers=idem(t), json={
        "source_account": "1000000001",
        "destination_account": "1000000003",
        "amount": "1", "reference": "FX"})
    assert fx.status_code == 422 and fx.json()["error"]["code"] == "110"
    same = c.post("/v1/transfers", headers=idem(t), json={
        "source_account": "1000000001",
        "destination_account": "1000000001",
        "amount": "1", "reference": "SELF"})
    assert same.json()["error"]["code"] == "105"
    h = c.get("/v1/accounts/1000000001/transactions", headers=t).json()
    assert [x["type"] for x in h["transactions"]] == ["TRANSFER",
                                                     "DEPOSIT"]
    assert h["transactions"][0]["source_balance_after"] == "700.00"
    page = c.get("/v1/accounts/1000000001/transactions?limit=1",
                 headers=t).json()
    assert page["count"] == 1 and page["next_before"]
    one = c.get(f"/v1/transactions/{r.json()['transaction_id']}",
                headers=t).json()
    assert one["amount"] == "300.00" and one["operator"] == "TELLER01"


def test_reversal_and_status_need_supervisor(env):
    setup_accounts(env)
    c, s = env["client"], env["super"]
    txn = dep(env, "1000000001", "80").json()["transaction_id"]
    r = c.post(f"/v1/transactions/{txn}/reversal",
               headers=idem(env["teller"]), json={"reference": "X"})
    assert r.status_code == 403
    r = c.post(f"/v1/transactions/{txn}/reversal", headers=idem(s),
               json={"reference": "KEYING-ERROR"})
    assert r.status_code == 201 and r.json()["balance"] == "0.00"
    again = c.post(f"/v1/transactions/{txn}/reversal", headers=idem(s),
                   json={"reference": "AGAIN"})
    assert again.status_code == 409
    r = c.patch("/v1/accounts/1000000001/status", headers=s,
                json={"status": "B"})
    assert r.status_code == 200 and r.json()["status"] == "B"
    blocked = dep(env, "1000000001", "5")
    assert blocked.status_code == 409
    assert blocked.json()["error"]["name"] == "ACCOUNT_BLOCKED"
    proj = env["db"].accounts.find_one({"_id": "1000000001"})
    assert proj["status"] == "B"                       # read model synced


def test_operator_comes_from_key_not_client(env):
    setup_accounts(env)
    dep(env, "1000000001", "10")
    entry = env["db"].audit.find_one({"operation": "DEPOSIT"})
    assert entry["operator"] == "TELLER01"


def test_daily_report_and_audit(env):
    setup_accounts(env)
    dep(env, "1000000001", "20000")
    env["client"].post("/v1/accounts/1000000001/withdrawals",
                       headers=idem(env["teller"]),
                       json={"amount": "999999", "reference": "NOPE"})
    r = env["client"].post("/v1/reports/daily", headers=env["super"])
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["deposits"] == {"count": 1, "value": "20000.00"}
    assert d["exceptions"]["large_transactions"] == 1
    assert d["exceptions"]["rejected_operations"] == 1
    bad = env["client"].post("/v1/reports/daily", headers=env["super"],
                             json={"business_date": "2026-13-45"})
    assert bad.status_code == 422
    a = env["client"].get("/v1/audit?failures_only=true",
                          headers=env["super"]).json()["entries"]
    assert a[0]["status_name"] == "INSUFFICIENT_FUNDS"


# --- read model -------------------------------------------------------
def test_read_model_matches_cobol_and_rebuilds(env):
    setup_accounts(env)
    for amt in ("10", "20", "30"):
        dep(env, "1000000002", amt)
    db = env["db"]
    ledger = (env["settings"].data_dir / "transactions.dat") \
        .read_text().splitlines()
    assert db.transactions.count_documents({}) == len(ledger) == 3
    cobol = env["client"].get("/v1/accounts/1000000002",
                              headers=env["teller"]).json()
    proj = db.accounts.find_one({"_id": "1000000002"})
    assert str(proj["available_balance"].to_decimal()) == \
        cobol["available_balance"] == "60.00"
    db.transactions.delete_many({})                 # lose the projection
    env["client"].app.state.projector.sync(force_rebuild=True)
    assert db.transactions.count_documents({}) == 3


def test_concurrent_deposits_are_serialised(env):
    """40 parallel deposits of 1.00 must give exactly 40.00. Without the
    lock in CobolBridge, read-modify-write races lose updates."""
    setup_accounts(env)

    def one(i):
        return dep(env, "1000000001", "1.00", ref=f"PAR-{i}").status_code

    with ThreadPoolExecutor(max_workers=8) as pool:
        codes = list(pool.map(one, range(40)))
    assert codes == [201] * 40
    bal = env["client"].get("/v1/accounts/1000000001",
                            headers=env["teller"]).json()
    assert Decimal(bal["available_balance"]) == Decimal("40.00")
    ids = [d["_id"] for d in env["db"].transactions.find()]
    assert len(ids) == len(set(ids)) == 40
