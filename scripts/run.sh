#!/usr/bin/env bash
# ================================================================
# run.sh - start the interactive teller menu (bin/cbs).
# Seeds the data directory on first use if it has no accounts.
# Usage: ./scripts/run.sh            (interactive)
#        ./scripts/run.sh < input    (scripted session)
# ================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cbs_require_binaries
cbs_default_env

if [ ! -f "$CBS_DATA_DIR/accounts.dat" ]; then
    echo "No data found in $CBS_DATA_DIR - loading seed data first."
    "$CBS_ROOT/scripts/reset-data.sh"
fi
exec "$CBS_ROOT/bin/cbs"
