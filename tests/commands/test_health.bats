#!/usr/bin/env bats

# Test health command

load bats_helper

setup() {
    skip_without_pg
}

@test "health command exits successfully" {
    run "$PG_SCRIPT" health
    [ $status -eq 0 ]
}

@test "health output contains health indicators" {
    run "$PG_SCRIPT" health
    [ $status -eq 0 ]
    # Should contain health status info
    echo "$output" | grep -qi "uptime\|health\|ok\|status"
}

@test "health --help shows usage" {
    run "$PG_SCRIPT" health --help
    [ $status -eq 0 ]
}