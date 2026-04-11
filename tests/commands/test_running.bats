#!/usr/bin/env bats

# Test running command

load bats_helper

setup() {
    skip_without_pg
}

@test "running command exits successfully" {
    run "$PG_SCRIPT" running
    [ $status -eq 0 ]
}

@test "running command output format" {
    run "$PG_SCRIPT" running
    [ $status -eq 0 ]
    # May be empty if no active queries, but should not error
}

@test "running with limit parameter" {
    run "$PG_SCRIPT" running 5
    [ $status -eq 0 ]
}

@test "running --help shows usage" {
    run "$PG_SCRIPT" running --help
    [ $status -eq 0 ]
}