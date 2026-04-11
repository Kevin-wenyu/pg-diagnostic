#!/usr/bin/env bats

# Test slow command

load bats_helper

setup() {
    skip_without_pg
}

@test "slow command exits successfully" {
    run "$PG_SCRIPT" slow
    [ $status -eq 0 ]
}

@test "slow with time parameter" {
    run "$PG_SCRIPT" slow 10
    [ $status -eq 0 ]
}

@test "slow --help shows usage" {
    run "$PG_SCRIPT" slow --help
    [ $status -eq 0 ]
}

@test "slow command output format" {
    run "$PG_SCRIPT" slow 1
    [ $status -eq 0 ]
    # May be empty if no slow queries
}