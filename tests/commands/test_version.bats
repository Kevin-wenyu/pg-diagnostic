#!/usr/bin/env bats

# Test version command

load bats_helper

setup() {
    skip_without_pg
}

@test "version command exits successfully" {
    run "$PG_SCRIPT" version
    [ $status -eq 0 ]
}

@test "version output contains PostgreSQL version" {
    run "$PG_SCRIPT" version
    [ $status -eq 0 ]
    # Should contain version info like "PostgreSQL X.Y"
    echo "$output" | grep -qi "postgres"
}

@test "version output contains tool version" {
    run "$PG_SCRIPT" version
    [ $status -eq 0 ]
    # Should contain version number
    echo "$output" | grep -qE "[0-9]+\.[0-9]+"
}

@test "version --help shows usage" {
    run "$PG_SCRIPT" version --help
    [ $status -eq 0 ]
}