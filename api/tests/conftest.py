"""Test fixtures: a fresh COBOL data directory and an in-memory
MongoDB (mongomock) per test, with one teller and one supervisor key.
Requires bin/cbs-api (./scripts/build.sh)."""
from __future__ import annotations

import itertools
from pathlib import Path

import mongomock
import pytest
from fastapi.testclient import TestClient

from app.auth import create_key
from app.config import REPO_ROOT, Settings
from app.main import create_app

BIN = REPO_ROOT / "bin" / "cbs-api"
_keys = itertools.count(1)


@pytest.fixture
def env(tmp_path: Path):
    if not BIN.exists():
        pytest.skip("bin/cbs-api not built - run ./scripts/build.sh")
    settings = Settings(cobol_bin=BIN, data_dir=tmp_path / "data",
                        report_dir=tmp_path / "reports",
                        config_file=REPO_ROOT / "config" / "cbs.conf",
                        mongo_uri="mongomock://", mongo_db="cbs_test",
                        cobol_timeout=30)
    db = mongomock.MongoClient(tz_aware=True)["cbs_test"]
    app = create_app(settings, db=db)
    with TestClient(app) as client:
        yield {"client": client, "db": db, "settings": settings,
               "teller": {"X-API-Key": create_key(db, "TELLER01",
                                                  "teller")},
               "super": {"X-API-Key": create_key(db, "SUPERV01",
                                                 "supervisor")}}


def idem(headers: dict) -> dict:
    """Headers plus a fresh Idempotency-Key."""
    return {**headers, "Idempotency-Key": f"test-{next(_keys)}"}


def setup_accounts(e) -> None:
    """Customer C0000001 with SAV 1000000001 (USD) and CUR 1000000002
    (USD, overdraft 500) and SAV 1000000003 (EUR)."""
    c, t = e["client"], e["teller"]
    assert c.post("/v1/customers", headers=t, json={
        "customer_id": "C0000001", "full_name": "Ada Testwright",
        "phone": "+15550100001", "email": "ada@example.com",
        "date_of_birth": "1985-02-14"}).status_code == 201
    for acct, typ, ccy, od in (("1000000001", "SAV", "USD", "0"),
                               ("1000000002", "CUR", "USD", "500"),
                               ("1000000003", "SAV", "EUR", "0")):
        r = c.post("/v1/accounts", headers=t, json={
            "account_number": acct, "customer_id": "C0000001",
            "type": typ, "currency": ccy, "overdraft_limit": od})
        assert r.status_code == 201, r.text
