#!/usr/bin/env bats

# Test ps command

load bats_helper

setup() {
    skip_without_pg
}

@test "ps command exits successfully" {
    run "$PG_SCRIPT" ps
    [ $status -eq 0 ]
}

@test "ps command output contains column headers" {
    run "$PG_SCRIPT" ps
    [ $status -eq 0 ]
    # Output should contain pid, usename, state, query columns
    echo "$output" | grep -q "pid\|PID"
}

@test "ps --help shows usage" {
    run "$PG_SCRIPT" ps --help
    [ $status -eq 0 ]
    assert_output_contains "Process"
}

@test "ps with connection parameters" {
    run "$PG_SCRIPT" -h "$PGHOST" -p "$PGPORT" -u "$PGUSER" -d "$PGDATABASE" ps
    [ $status -eq 0 ]
}

@test "ps output is not empty" {
    run "$PG_SCRIPT" ps
    [ -n "$output" ]
}