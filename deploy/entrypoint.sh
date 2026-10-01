#!/usr/bin/env bash
# Container start-up: optionally load the fictional demo data on the
# very first start (empty volume), then run the API.
# ONE worker only: the COBOL file store is single-writer (the API
# also holds a file lock, but one worker keeps latency predictable).
set -euo pipefail
if [ "${CBS_SEED_ON_FIRST_START:-false}" = "true" ] \
   && [ ! -f "$CBS_DATA_DIR/accounts.dat" ]; then
    echo "First start: loading fictional seed data"
    /app/scripts/reset-data.sh
fi
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1 \
     --proxy-headers --forwarded-allow-ips='*'
