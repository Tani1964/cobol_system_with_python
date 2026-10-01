#!/usr/bin/env bash
# ================================================================
# run_tests.sh - automated test suite for the COBOL Core Banking
# System. Builds the project (incl. test drivers), runs every
# suite against its own fresh temporary data directory (the real
# ./data is never touched), then runs CLI smoke tests.
#
# Usage:  ./tests/run_tests.sh [-v]      (-v = show every assertion)
# Exit :  0 when every assertion passed, 1 otherwise, 2 build error
# ================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

echo "Building (with test drivers)..."
if ! ./scripts/build.sh --tests > /tmp/cbs-test-build.log 2>&1; then
    cat /tmp/cbs-test-build.log
    echo "BUILD FAILED - tests not run"
    exit 2
fi
echo

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cbs-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

TOTAL=0; PASSED=0; FAILED=0; SUITE_FAIL=0

# label | driver
SUITES=(
  "Customer Tests|TEST-CUSTOMER"
  "Account Tests|TEST-ACCOUNT"
  "Deposit Tests|TEST-DEPOSIT"
  "Withdrawal Tests|TEST-WITHDRAW"
  "Transfer Tests|TEST-TRANSFER"
  "Ledger Tests|TEST-LEDGER"
  "Audit Tests|TEST-AUDIT"
  "Batch Tests|TEST-BATCH"
  "Report Tests|TEST-REPORTS"
)

print_line() {   # $1 label  $2 PASS/FAIL  $3 detail
    local dots
    dots=$(printf '%*s' $((28 - ${#1})) '' | tr ' ' '.')
    printf '%s %s %s %s\n' "$1" "$dots" "$2" "$3"
}

for entry in "${SUITES[@]}"; do
    label="${entry%%|*}"; driver="${entry##*|}"
    dir="$WORK/$driver"; mkdir -p "$dir/data" "$dir/reports"
    log="$dir/output.log"
    CBS_DATA_DIR="$dir/data" CBS_REPORT_DIR="$dir/reports" \
    CBS_CONFIG_FILE="$ROOT/config/cbs.conf" \
    CBS_FIXTURE_DIR="$ROOT/tests/fixtures" CBS_TEST_MODE=Y \
    CBS_FAULT_INJECT="" \
        "$ROOT/bin/tests/$driver" > "$log" 2>&1
    rc=$?
    p=$(grep -c '^  PASS' "$log"); f=$(grep -c '^  FAIL' "$log")
    TOTAL=$((TOTAL + p + f)); PASSED=$((PASSED + p))
    FAILED=$((FAILED + f))
    if [ "$rc" -eq 0 ] && [ "$f" -eq 0 ] && grep -q '^RESULT' "$log"
    then
        print_line "$label" "PASS" "($p checks)"
    else
        print_line "$label" "FAIL" "($f of $((p + f)) failed, rc=$rc)"
        SUITE_FAIL=1
        if ! grep -q '^RESULT' "$log"; then
            FAILED=$((FAILED + 1)); TOTAL=$((TOTAL + 1))
            echo "    driver did not finish - output follows:"
            sed 's/^/    /' "$log"
        fi
    fi
    if [ "$VERBOSE" -eq 1 ] || [ "$f" -gt 0 ]; then
        grep -E '^  (PASS|FAIL)' "$log" | \
            { if [ "$VERBOSE" -eq 1 ]; then cat; else grep FAIL; fi; } |
            sed 's/^/  /'
    fi
done

# ---- CLI smoke tests (end-to-end through bin/cbs-cli) ----------
dir="$WORK/cli"; mkdir -p "$dir/data" "$dir/reports"
export CBS_DATA_DIR="$dir/data" CBS_REPORT_DIR="$dir/reports"
export CBS_CONFIG_FILE="$ROOT/config/cbs.conf" CBS_OPERATOR=TESTER
cli_p=0; cli_f=0
cli_check() {   # $1 description  $2 expected rc  $3.. command args
    local desc="$1" want="$2"; shift 2
    "$ROOT/bin/cbs-cli" "$@" > "$dir/cli.out" 2>&1
    local got=$?
    if [ "$got" -eq "$want" ]; then
        cli_p=$((cli_p + 1))
        [ "$VERBOSE" -eq 1 ] && echo "    PASS  $desc"
    else
        cli_f=$((cli_f + 1))
        echo "    FAIL  $desc - expected rc $want got $got"
    fi
}
cli_check "post seed file (rc 0)"              0 post "$ROOT/data/seed/seed-data.txt"
cli_check "post exception file (rc 4)"         4 post "$ROOT/data/seed/sample-exceptions.txt"
cli_check "daily report today (rc 0)"          0 daily
cli_check "daily report bad date (rc 8)"       8 daily 20261399
cli_check "account history (rc 0)"             0 history 1000000001
cli_check "history unknown account (rc 8)"     8 history 9999999999
cli_check "customer summary (rc 0)"            0 summary C0000001
cli_check "failed report ALL (rc 0)"           0 failed ALL
cli_check "missing batch file (rc 8)"          8 post /nonexistent/file.txt
cli_check "unknown command (rc 16)"           16 bogus
TOTAL=$((TOTAL + cli_p + cli_f)); PASSED=$((PASSED + cli_p))
FAILED=$((FAILED + cli_f))
if [ "$cli_f" -eq 0 ]; then
    print_line "CLI Smoke Tests" "PASS" "($cli_p checks)"
else
    print_line "CLI Smoke Tests" "FAIL" "($cli_f of $((cli_p + cli_f)) failed)"
    SUITE_FAIL=1
fi

# ---- HTTP API tests (Python; skipped if dependencies missing) ----
if python3 -c "import fastapi, pymongo, mongomock, pytest, httpx" \
        2>/dev/null; then
    out=$(cd "$ROOT/api" && python3 -m pytest -q -p no:cacheprovider \
          2>&1)
    ap=$(echo "$out" | awk '{for(i=2;i<=NF;i++) if($i ~ /^passed/) s+=$(i-1)} END{print s+0}')
    af=$(echo "$out" | awk '{for(i=2;i<=NF;i++) if($i ~ /^(failed|error)/) s+=$(i-1)} END{print s+0}')
    TOTAL=$((TOTAL + ap + af)); PASSED=$((PASSED + ap))
    FAILED=$((FAILED + af))
    if [ "$af" -eq 0 ] && [ "$ap" -gt 0 ]; then
        print_line "API Tests" "PASS" "($ap checks)"
    else
        print_line "API Tests" "FAIL" "($af failed)"
        echo "$out" | tail -30 | sed 's/^/    /'
        SUITE_FAIL=1
    fi
    if [ "$VERBOSE" -eq 1 ]; then
        (cd "$ROOT/api" && python3 -m pytest -v -p no:cacheprovider \
            2>&1 | grep -E 'PASSED|FAILED' | sed 's/^/    /')
    fi
else
    print_line "API Tests" "SKIP" \
        "(pip install -r api/requirements-dev.txt)"
fi

echo
echo "TOTAL: $TOTAL"
echo "PASSED: $PASSED"
echo "FAILED: $FAILED"
if [ "$FAILED" -eq 0 ] && [ "$SUITE_FAIL" -eq 0 ]; then
    echo "ALL TESTS PASSED"
    exit 0
fi
echo "TESTS FAILED"
exit 1
