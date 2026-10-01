"""Runtime settings, read from environment variables once at start-up."""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Settings:
    cobol_bin: Path          # bin/cbs-api, the COBOL request/response program
    data_dir: Path           # COBOL system of record (CBS_DATA_DIR)
    report_dir: Path         # COBOL reports (CBS_REPORT_DIR)
    config_file: Path        # COBOL config (CBS_CONFIG_FILE)
    mongo_uri: str           # mongodb://... or mongomock:// (tests only)
    mongo_db: str
    cobol_timeout: float     # seconds per COBOL call


def load_settings() -> Settings:
    env = os.environ.get
    return Settings(
        cobol_bin=Path(env("CBS_API_BIN", REPO_ROOT / "bin" / "cbs-api")),
        data_dir=Path(env("CBS_DATA_DIR", REPO_ROOT / "data")),
        report_dir=Path(env("CBS_REPORT_DIR", REPO_ROOT / "reports")),
        config_file=Path(env("CBS_CONFIG_FILE",
                             REPO_ROOT / "config" / "cbs.conf")),
        mongo_uri=env("MONGO_URI", "mongodb://localhost:27017"),
        mongo_db=env("MONGO_DB", "cbs"),
        cobol_timeout=float(env("CBS_COBOL_TIMEOUT", "30")),
    )
