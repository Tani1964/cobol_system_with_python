"""Bridge to the COBOL system (bin/cbs-api).

Each call starts bin/cbs-api, sends ONE pipe-delimited request line on
stdin and parses the pipe-delimited response lines from stdout. The
COBOL services keep every business rule; this module only transports.

CONCURRENCY: the COBOL system has no record locking. Every call runs
inside `exclusive()`, which holds a process-wide re-entrant lock AND an
OS file lock on <data_dir>/.cbs-api.lock, so requests are serialised
even across several API worker processes on the same machine.
"""
from __future__ import annotations

import fcntl
import logging
import os
import subprocess
import threading
from contextlib import contextmanager
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Iterator

from .config import Settings

log = logging.getLogger("cbs.cobol")

FORBIDDEN = set("|\r\n\x00")


class CobolBridgeError(RuntimeError):
    """The COBOL program could not be run or answered garbage."""


@dataclass
class CobolResult:
    code: int
    name: str
    error_field: str
    message: str
    txn_id: str
    new_balance: Decimal
    source_balance: Decimal
    dest_balance: Decimal
    warning: str
    records: dict[str, list[str]] = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return self.code == 0


def _dec(text: str) -> Decimal:
    return Decimal(text) if text else Decimal("0.00")


class CobolBridge:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._lock = threading.RLock()
        self._local = threading.local()
        settings.data_dir.mkdir(parents=True, exist_ok=True)
        settings.report_dir.mkdir(parents=True, exist_ok=True)
        self._lock_path = settings.data_dir / ".cbs-api.lock"

    @contextmanager
    def exclusive(self) -> Iterator[None]:
        """Serialise access to the COBOL data files (re-entrant)."""
        with self._lock:
            depth = getattr(self._local, "depth", 0)
            if depth == 0:
                fh = open(self._lock_path, "a+")
                fcntl.flock(fh, fcntl.LOCK_EX)
                self._local.fh = fh
            self._local.depth = depth + 1
            try:
                yield
            finally:
                self._local.depth -= 1
                if self._local.depth == 0:
                    fcntl.flock(self._local.fh, fcntl.LOCK_UN)
                    self._local.fh.close()

    def call(self, *fields: str) -> CobolResult:
        for f in fields:
            if any(ch in FORBIDDEN for ch in f):
                # Schemas reject these first; this is a last line of
                # defence against request-line injection.
                raise ValueError("field contains a forbidden character")
        line = "|".join(fields) + "\n"
        env = dict(os.environ,
                   CBS_DATA_DIR=str(self.settings.data_dir),
                   CBS_REPORT_DIR=str(self.settings.report_dir),
                   CBS_CONFIG_FILE=str(self.settings.config_file))
        env.pop("CBS_TEST_MODE", None)          # never inject faults
        env.pop("CBS_FAULT_INJECT", None)
        with self.exclusive():
            try:
                proc = subprocess.run(
                    [str(self.settings.cobol_bin)], input=line,
                    capture_output=True, text=True, env=env,
                    timeout=self.settings.cobol_timeout, check=False)
            except (OSError, subprocess.TimeoutExpired) as exc:
                raise CobolBridgeError(f"cbs-api failed: {exc}") from exc
        if proc.stderr.strip():
            log.warning("cbs-api stderr: %s", proc.stderr.strip())
        return self._parse(proc.stdout)

    @staticmethod
    def _parse(stdout: str) -> CobolResult:
        result: CobolResult | None = None
        records: dict[str, list[str]] = {}
        for raw in stdout.splitlines():
            parts = raw.rstrip().split("|")
            if parts[0] == "RESULT" and len(parts) == 10:
                result = CobolResult(
                    code=int(parts[1]), name=parts[2],
                    error_field=parts[3], message=parts[4],
                    txn_id=parts[5], new_balance=_dec(parts[6]),
                    source_balance=_dec(parts[7]),
                    dest_balance=_dec(parts[8]), warning=parts[9])
            elif parts[0] in ("CUSTOMER", "ACCOUNT", "DAILY"):
                records[parts[0]] = parts[1:]
        if result is None:
            raise CobolBridgeError(f"no RESULT line in output: {stdout!r}")
        result.records = records
        return result
