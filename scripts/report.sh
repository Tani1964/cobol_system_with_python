#!/usr/bin/env bash
# ================================================================
# report.sh - generate reports without the interactive menu.
#   ./scripts/report.sh daily [YYYYMMDD]
#   ./scripts/report.sh history <account>
#   ./scripts/report.sh summary <customer-id>
#   ./scripts/report.sh failed [YYYYMMDD|ALL]
# Reports are written to $CBS_REPORT_DIR (default ./reports).
# ================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cbs_require_binaries
cbs_default_env
if [ $# -lt 1 ]; then
    "$CBS_ROOT/bin/cbs-cli" help
    exit 16
fi
exec "$CBS_ROOT/bin/cbs-cli" "$@"
