#!/usr/bin/env bats

# Test conn command

load bats_helper

setup() {
    skip_without_pg
}

@test "conn command exits successfully" {
    run "$PG_SCRIPT" conn
    [ $status -eq 0 ]
}

@test "conn output contains connection info" {
    run "$PG_SCRIPT" conn
    [ $status -eq 0 ]
    # Should contain connection stats
    echo "$output" | grep -qi "connect\|total\|used"
}

@test "conn --help shows usage" {
    run "$PG_SCRIPT" conn --help
    [ $status -eq 0 ]
}