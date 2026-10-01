"""Idempotency keys for money-moving requests.

A client that retries a deposit after a timeout must not deposit twice.
The client sends an Idempotency-Key header; the first response for
(operator, key) is stored and replayed for every retry with the same
body. The same key with a different body is rejected (422).
Records expire after 24 hours (TTL index, see db.py).

Runs inside CobolBridge.exclusive(), so check-then-execute is atomic.
Server failures (5xx) are not stored, so they can safely be retried:
the COBOL posting engine rolls back failed postings.
"""
from __future__ import annotations

import hashlib
import json
from typing import Callable

from fastapi import HTTPException
from pymongo.database import Database

from .auth import Principal
from .db import now

MAX_KEY_LENGTH = 100


def run(db: Database, who: Principal, key: str | None, endpoint: str,
        payload: dict,
        execute: Callable[[], tuple[int, dict]]) -> tuple[int, dict, bool]:
    if not key or len(key) > MAX_KEY_LENGTH:
        raise HTTPException(400, "Idempotency-Key header (1-100 chars) "
                                 "is required for this operation")
    digest = hashlib.sha256(json.dumps(
        {"endpoint": endpoint, "payload": payload},
        sort_keys=True, default=str).encode()).hexdigest()
    found = db.idempotency.find_one({"operator": who.operator, "key": key})
    if found:
        if found["request_hash"] != digest:
            raise HTTPException(422, "Idempotency-Key was already used "
                                     "with a different request")
        return found["status"], found["body"], True
    status, body = execute()
    if status < 500:
        db.idempotency.insert_one({
            "operator": who.operator, "key": key, "request_hash": digest,
            "status": status, "body": body, "created_at": now()})
    return status, body, False
