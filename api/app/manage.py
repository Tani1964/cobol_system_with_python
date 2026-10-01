"""Admin commands.

  python -m app.manage create-key --operator TELLER01 --role teller
  python -m app.manage list-keys
  python -m app.manage revoke-key --operator TELLER01
  python -m app.manage resync          # rebuild the Mongo read model
"""
from __future__ import annotations

import argparse
import sys

from .auth import create_key
from .cobol import CobolBridge
from .config import load_settings
from .db import connect, ensure_indexes
from .sync import Projector


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="python -m app.manage")
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("create-key")
    c.add_argument("--operator", required=True)
    c.add_argument("--role", choices=["teller", "supervisor"],
                   required=True)
    sub.add_parser("list-keys")
    r = sub.add_parser("revoke-key")
    r.add_argument("--operator", required=True)
    sub.add_parser("resync")
    args = p.parse_args(argv)

    settings = load_settings()
    db = connect(settings.mongo_uri, settings.mongo_db)
    ensure_indexes(db)
    if args.cmd == "create-key":
        key = create_key(db, args.operator, args.role)
        print(f"API key for {args.operator.upper()} ({args.role}). "
              "Shown ONCE - store it safely:")
        print(key)
    elif args.cmd == "list-keys":
        for d in db.api_keys.find().sort("operator", 1):
            print(f"{d['operator']:<8} {d['role']:<10} "
                  f"{'active' if d['active'] else 'revoked'}  "
                  f"created {d['created_at']:%Y-%m-%d}")
    elif args.cmd == "revoke-key":
        n = db.api_keys.update_many({"operator": args.operator.upper()},
                                    {"$set": {"active": False}})
        print(f"revoked {n.modified_count} key(s)")
    elif args.cmd == "resync":
        stats = Projector(db, CobolBridge(settings)).sync(
            force_rebuild=True)
        print(f"rebuilt read model: {stats.transactions} transactions, "
              f"{stats.audit} audit entries, {len(stats.accounts)} "
              f"accounts, {stats.malformed} malformed ledger lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
