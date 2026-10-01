#!/usr/bin/env bash
# ================================================================
# build.sh - compile every COBOL module and link the executables.
#   bin/cbs        interactive teller menu (CBSMAIN)
#   bin/cbs-cli    command-line batch/report driver (CBSCLI)
#   bin/cbs-api    one-request-per-run interface used by the HTTP API
#   bin/tests/*    test drivers (only with --tests)
# Fails with a non-zero exit code on the first compile/link error.
# Usage: ./scripts/build.sh [--tests] [--clean]
# ================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cbs_require_cobc

BUILD_TESTS=0
for arg in "$@"; do
    case "$arg" in
        --tests) BUILD_TESTS=1 ;;
        --clean) rm -rf "$CBS_ROOT/bin/obj" "$CBS_ROOT/bin/tests" \
                        "$CBS_ROOT/bin/cbs" "$CBS_ROOT/bin/cbs-cli" "$CBS_ROOT/bin/cbs-api" ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

cd "$CBS_ROOT"
OBJ=bin/obj
mkdir -p "$OBJ"
COBFLAGS=(-Wall -Wcolumn-overflow -fstatic-call -I copybooks)

# Some distro GCC builds print harmless _FORTIFY_SOURCE redefinition
# notes through cobc; filter exactly those, keep everything else.
filter_noise() {
    grep -v -E '_FORTIFY_SOURCE|previous definition|^<command-line>|^In file included|^ *\| *\^|^ *[0-9]+ \| #' || true
}

echo "== COBOL Core Banking build ($(cobc --version | head -1))"

# ---- 1. lint: fixed-format sources must fit in columns 1-72 ----
lint_fail=0
while IFS= read -r f; do
    bad=$(awk 'length > 72 {print FILENAME ":" FNR ": line exceeds 72 columns"}' "$f")
    if [ -n "$bad" ]; then echo "$bad" >&2; lint_fail=1; fi
done < <(find src batch copybooks tests/suites tests/copybooks \
              -name '*.cob' -o -name '*.cpy' 2>/dev/null | sort)
if [ "$lint_fail" -ne 0 ]; then
    echo "BUILD FAILED: column lint errors" >&2
    exit 1
fi

# ---- 2. compile modules ----
compile() {   # $1 source, $2 object, $3.. extra flags
    local src="$1" obj="$2"; shift 2
    local out
    if ! out=$(cobc -c "${COBFLAGS[@]}" "$@" -o "$obj" "$src" 2>&1); then
        echo "$out" | filter_noise >&2
        echo "BUILD FAILED: compile error in $src" >&2
        exit 1
    fi
    out=$(echo "$out" | filter_noise)
    if [ -n "$out" ]; then echo "$out"; fi
}

MODULE_OBJS=()
count=0
for src in $(find src/persistence src/validation src/services \
                  src/reporting batch -name '*.cob' | sort); do
    name=$(basename "$src" .cob)
    compile "$src" "$OBJ/$name.o"
    MODULE_OBJS+=("$OBJ/$name.o")
    count=$((count + 1))
done
echo "   compiled $count modules"

# ---- 3. main programs ----
link() {   # $1 main source, $2 output binary
    local src="$1" exe="$2" name
    name=$(basename "$src" .cob)
    compile "$src" "$OBJ/$name.o" -x
    local out
    if ! out=$(cobc -x -o "$exe" "$OBJ/$name.o" "${MODULE_OBJS[@]}" 2>&1)
    then
        echo "$out" | filter_noise >&2
        echo "BUILD FAILED: link error for $exe" >&2
        exit 1
    fi
    echo "   linked $exe"
}

link src/programs/CBSMAIN.cob bin/cbs
link src/programs/CBSCLI.cob  bin/cbs-cli
link src/programs/CBSAPI.cob  bin/cbs-api

# ---- 4. optional test drivers ----
if [ "$BUILD_TESTS" -eq 1 ]; then
    mkdir -p bin/tests
    tcount=0
    for src in $(find tests/suites -name '*.cob' | sort); do
        name=$(basename "$src" .cob)
        compile "$src" "$OBJ/$name.o" -x -I tests/copybooks
        if ! out=$(cobc -x -o "bin/tests/$name" "$OBJ/$name.o" \
                        "${MODULE_OBJS[@]}" 2>&1); then
            echo "$out" | filter_noise >&2
            echo "BUILD FAILED: link error for test $name" >&2
            exit 1
        fi
        tcount=$((tcount + 1))
    done
    echo "   built $tcount test drivers in bin/tests"
fi

echo "BUILD SUCCESSFUL"
