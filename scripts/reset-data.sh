#!/usr/bin/env bash
# ================================================================
# reset-data.sh - wipe runtime data and rebuild it from the seed.
#   1. removes customers/accounts/ledger/audit/sequence files in
#      $CBS_DATA_DIR (default ./data) and generated reports
#   2. posts data/seed/seed-data.txt through BATCH-POST
#   3. posts data/seed/sample-exceptions.txt (expected rejections)
#   4. refreshes data/sample/ with copies of the generated ledger
#      and audit log (only when using the default data directory)
# Usage: ./scripts/reset-data.sh [--empty]   (--empty = no seed)
# ================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cbs_require_binaries
cbs_default_env

EMPTY=0
[ "${1:-}" = "--empty" ] && EMPTY=1

echo "Resetting data in $CBS_DATA_DIR"
rm -f "$CBS_DATA_DIR"/customers.dat "$CBS_DATA_DIR"/accounts.dat \
      "$CBS_DATA_DIR"/transactions.dat "$CBS_DATA_DIR"/audit.log \
      "$CBS_DATA_DIR"/txn-sequence.dat "$CBS_DATA_DIR"/txn-sequence.tmp
rm -f "$CBS_DATA_DIR"/*.dat.* 2>/dev/null || true
find "$CBS_REPORT_DIR" -maxdepth 1 -name '*.txt' -delete

if [ "$EMPTY" -eq 1 ]; then
    echo "Data files removed (empty system)."
    exit 0
fi

export CBS_OPERATOR=SEED
set +e
"$CBS_ROOT/bin/cbs-cli" post "$CBS_ROOT/data/seed/seed-data.txt"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "ERROR: seed posting failed (rc=$rc) - see run log above" >&2
    exit 1
fi

set +e
"$CBS_ROOT/bin/cbs-cli" post \
    "$CBS_ROOT/data/seed/sample-exceptions.txt" >/dev/null
rc=$?
set -e
if [ "$rc" -ne 4 ]; then
    echo "ERROR: sample exceptions expected RC 4, got $rc" >&2
    exit 1
fi
echo "Sample exception file posted (all lines rejected as intended)."

if [ "$CBS_DATA_DIR" = "$CBS_ROOT/data" ]; then
    mkdir -p "$CBS_ROOT/data/sample"
    cp "$CBS_DATA_DIR/transactions.dat" \
       "$CBS_ROOT/data/sample/sample-transactions.dat"
    cp "$CBS_DATA_DIR/audit.log" "$CBS_ROOT/data/sample/sample-audit.log"
fi
echo "Reset complete."
