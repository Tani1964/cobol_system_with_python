#!/usr/bin/env bash
# Shared helpers for the project scripts (sourced, not executed).
# Resolves the project root so scripts work from any directory.
CBS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CBS_ROOT

cbs_require_cobc() {
    if ! command -v cobc >/dev/null 2>&1; then
        echo "ERROR: GnuCOBOL compiler 'cobc' not found in PATH." >&2
        echo "Install it first, e.g. 'sudo apt-get install gnucobol'" \
             "(Debian/Ubuntu) or 'brew install gnucobol' (macOS)." >&2
        exit 2
    fi
}

cbs_require_binaries() {
    if [ ! -x "$CBS_ROOT/bin/cbs" ] || [ ! -x "$CBS_ROOT/bin/cbs-cli" ]
    then
        echo "ERROR: binaries not found. Run ./scripts/build.sh first." >&2
        exit 2
    fi
}

# Default runtime locations (can be overridden by the caller).
cbs_default_env() {
    export CBS_DATA_DIR="${CBS_DATA_DIR:-$CBS_ROOT/data}"
    export CBS_REPORT_DIR="${CBS_REPORT_DIR:-$CBS_ROOT/reports}"
    export CBS_CONFIG_FILE="${CBS_CONFIG_FILE:-$CBS_ROOT/config/cbs.conf}"
    mkdir -p "$CBS_DATA_DIR" "$CBS_REPORT_DIR"
}
