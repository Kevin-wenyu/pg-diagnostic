#!/usr/bin/env bats

# Integration tests for pg-diagnostic

load bats_helper

setup() {
    skip_without_pg
}

@test "Full workflow: connect and query" {
    # Test connection
    run "$PG_SCRIPT" ps
    [ $status -eq 0 ]

    # Test version
    run "$PG_SCRIPT" version
    [ $status -eq 0 ]

    # Test health
    run "$PG_SCRIPT" health
    [ $status -eq 0 ]
}

@test "Multiple commands in sequence" {
    run "$PG_SCRIPT" conn
    [ $status -eq 0 ]

    run "$PG_SCRIPT" running
    [ $status -eq 0 ]

    run "$PG_SCRIPT" locks
    [ $status -eq 0 ]
}

@test "Error handling with invalid command" {
    run "$PG_SCRIPT" nonexistent_command
    [ $status -ne 0 ]
}

@test "Environment variable based connection" {
    export PGHOST="$PGHOST"
    export PGPORT="$PGPORT"
    export PGUSER="$PGUSER"
    export PGDATABASE="$PGDATABASE"

    run "$PG_SCRIPT" ps
    [ $status -eq 0 ]
}

@test "Password file connection" {
    # Test with .pgpass file if exists
    if [ -f "$PG_SCRIPT/.pgpass" ]; then
        run "$PG_SCRIPT" -P "$PG_SCRIPT/.pgpass" ps
        [ $status -eq 0 ]
    else
        skip ".pgpass file not found"
    fi
}