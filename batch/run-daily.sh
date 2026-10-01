#!/usr/bin/env bash
# ================================================================
# run-daily.sh - end-of-day job wrapper (cron/scheduler friendly).
# Optionally posts a batch file, then runs DAILY-PROCESS.
#   ./batch/run-daily.sh [YYYYMMDD] [batch-input-file]
# Exit code: highest return code of the steps (0/4/8/12/16).
# ================================================================
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/common.sh"
cbs_require_binaries
cbs_default_env
export CBS_OPERATOR="${CBS_OPERATOR:-EODBATCH}"

DATE="${1:-}"
INPUT="${2:-}"
maxrc=0

if [ -n "$INPUT" ]; then
    echo "== Step 1: batch posting of $INPUT"
    "$CBS_ROOT/bin/cbs-cli" post "$INPUT"
    rc=$?
    echo "   step 1 rc=$rc"
    [ "$rc" -gt "$maxrc" ] && maxrc=$rc
    if [ "$rc" -ge 12 ]; then
        echo "Batch posting failed - daily processing not started" >&2
        exit "$rc"
    fi
fi

echo "== Step 2: daily processing ${DATE:-(today)}"
if [ -n "$DATE" ]; then
    "$CBS_ROOT/bin/cbs-cli" daily "$DATE"
else
    "$CBS_ROOT/bin/cbs-cli" daily
fi
rc=$?
echo "   step 2 rc=$rc"
[ "$rc" -gt "$maxrc" ] && maxrc=$rc
exit "$maxrc"
