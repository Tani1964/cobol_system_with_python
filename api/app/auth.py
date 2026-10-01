"""API-key authentication and roles.

Keys are random, shown once at creation and stored only as SHA-256
hashes. Each key belongs to an operator ID, which the API passes to
COBOL as the operator of every request - clients can never choose it.
Roles: teller < supervisor (reversals, status changes, daily run,
audit queries).
"""
from __future__ import annotations

import hashlib
import re
import secrets
from dataclasses import dataclass

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import APIKeyHeader
from pymongo.database import Database

from .db import now

ROLES = {"teller": 1, "supervisor": 2}
OPERATOR_RE = re.compile(r"^[A-Z0-9_-]{1,8}$")
header = APIKeyHeader(name="X-API-Key", auto_error=False)


@dataclass(frozen=True)
class Principal:
    operator: str
    role: str


def hash_key(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()


def create_key(db: Database, operator: str, role: str) -> str:
    operator = operator.upper()
    if not OPERATOR_RE.match(operator):
        raise ValueError("operator must be 1-8 chars A-Z 0-9 - _")
    if role not in ROLES:
        raise ValueError(f"role must be one of {sorted(ROLES)}")
    key = "cbs_" + secrets.token_urlsafe(32)
    db.api_keys.insert_one({"key_hash": hash_key(key),
                            "operator": operator, "role": role,
                            "active": True, "created_at": now()})
    return key


def require(min_role: str):
    def dependency(request: Request,
                   key: str | None = Depends(header)) -> Principal:
        if not key:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED,
                                "missing X-API-Key header")
        db: Database = request.app.state.db
        doc = db.api_keys.find_one({"key_hash": hash_key(key),
                                    "active": True})
        if not doc:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED,
                                "invalid or revoked API key")
        if ROLES[doc["role"]] < ROLES[min_role]:
            raise HTTPException(status.HTTP_403_FORBIDDEN,
                                f"requires role {min_role}")
        return Principal(doc["operator"], doc["role"])
    return dependency
