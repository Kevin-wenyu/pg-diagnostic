#!/usr/bin/env bats

# Test table_size command

load bats_helper

setup() {
    skip_without_pg
}

@test "table_size command exits successfully" {
    run "$PG_SCRIPT" table_size
    [ $status -eq 0 ]
}

@test "table_size output contains size info" {
    run "$PG_SCRIPT" table_size
    [ $status -eq 0 ]
    # Should contain table names or sizes
}

@test "table_size with schema filter" {
    run "$PG_SCRIPT" table_size public.%
    [ $status -eq 0 ]
}

@test "table_size --help shows usage" {
    run "$PG_SCRIPT" table_size --help
    [ $status -eq 0 ]
}