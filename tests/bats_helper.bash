#!/usr/bin/env bash
# bats helper for pg-diagnostic tests

# Source the test helper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helper.bash"

# Path to pg script
PG_SCRIPT="${SCRIPT_DIR}/../pg"

# Run pg command and capture output
run_pg() {
    local cmd="$1"
    shift
    "$PG_SCRIPT" "$@" "$cmd" 2>&1
}

# Assert command exits successfully
assert_success() {
    if [ $1 -ne 0 ]; then
        echo "Expected exit code 0, got $1"
        echo "Output: $output"
        return 1
    fi
}

# Assert command fails
assert_failure() {
    if [ $1 -eq 0 ]; then
        echo "Expected non-zero exit code, got 0"
        echo "Output: $output"
        return 1
    fi
}

# Assert output contains string
assert_output_contains() {
    local expected="$1"
    if ! echo "$output" | grep -q "$expected"; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
    fi
}

# Assert output is not empty
assert_output_not_empty() {
    if [ -z "$output" ]; then
        echo "Expected non-empty output"
        return 1
    fi
}

# Skip test if pg_stat_statements not available
skip_without_pg_stat_statements() {
    if ! check_pg_stat_statements; then
        skip "pg_stat_statements extension not available"
    fi
}

# Skip test if PostgreSQL not available
skip_without_pg() {
    if ! pg_is_ready; then
        skip "PostgreSQL not available"
    fi
}