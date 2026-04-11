#!/usr/bin/env bats

# Test blocking command

load bats_helper

setup() {
    skip_without_pg
}

@test "blocking command exits successfully" {
    run "$PG_SCRIPT" blocking
    [ $status -eq 0 ]
}

@test "blocking output format" {
    run "$PG_SCRIPT" blocking
    [ $status -eq 0 ]
    # May be empty if no blocking
}

@test "blocking --help shows usage" {
    run "$PG_SCRIPT" blocking --help
    [ $status -eq 0 ]
}