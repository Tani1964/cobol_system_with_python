"""MongoDB access.

MongoDB is NOT the system of record - the COBOL files are. Mongo holds:
  * API state:    api_keys, idempotency
  * a read model: customers, accounts, transactions, audit - projected
    from the COBOL files by sync.py, rebuildable at any time.
"""
from __future__ import annotations

from datetime import datetime, timezone

from pymongo import ASCENDING, DESCENDING, MongoClient
from pymongo.database import Database

IDEMPOTENCY_TTL_SECONDS = 24 * 3600


def connect(uri: str, db_name: str) -> Database:
    if uri.startswith("mongomock://"):          # tests / offline demo
        import mongomock
        return mongomock.MongoClient(tz_aware=True)[db_name]
    client: MongoClient = MongoClient(
        uri, serverSelectionTimeoutMS=3000, tz_aware=True)
    return client[db_name]


def ensure_indexes(db: Database) -> None:
    db.api_keys.create_index("key_hash", unique=True)
    db.idempotency.create_index(
        [("operator", ASCENDING), ("key", ASCENDING)], unique=True)
    db.idempotency.create_index(
        "created_at", expireAfterSeconds=IDEMPOTENCY_TTL_SECONDS)
    db.accounts.create_index("customer_id")
    db.transactions.create_index(
        [("accounts", ASCENDING), ("_id", DESCENDING)])
    db.transactions.create_index("business_date")
    db.audit.create_index([("entity_id", ASCENDING), ("_id", DESCENDING)])


def now() -> datetime:
    return datetime.now(timezone.utc)
