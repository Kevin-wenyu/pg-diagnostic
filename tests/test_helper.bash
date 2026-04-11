#!/usr/bin/env bash
# Test helper functions for pg-diagnostic

# Database connection setup
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGDATABASE="${PGDATABASE:-postgres}"

# Test constants
TEST_DB_NAME="pg_diagnostic_test"
TEST_TIMEOUT=30

# Check if PostgreSQL is available
pg_is_ready() {
    pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1
}

# Get PostgreSQL version
get_pg_version() {
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -A -c "SELECT current_setting('server_version_num')" 2>/dev/null
}

# Check if connection works
check_pg_connection() {
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "SELECT 1" >/dev/null 2>&1
}

# Create test table
create_test_table() {
    local table_name="$1"
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "
        CREATE TABLE IF NOT EXISTS $table_name (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            created_at TIMESTAMP DEFAULT NOW()
        );
    " >/dev/null 2>&1
}

# Drop test table
drop_test_table() {
    local table_name="$1"
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "DROP TABLE IF EXISTS $table_name CASCADE" >/dev/null 2>&1
}

# Insert test data
insert_test_data() {
    local table_name="$1"
    local count="${2:-10}"
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "
        INSERT INTO $table_name (name)
        SELECT 'test_' || generate_series FROM generate_series(1, $count);
    " >/dev/null 2>&1
}

# Get pg_stat_statements extension status
check_pg_stat_statements() {
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -A -c "
        SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements';
    " 2>/dev/null | grep -q "1"
}