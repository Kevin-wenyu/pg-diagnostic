# Partition Command Design Specification

> **Feature:** Add `partition` command group for PostgreSQL table partitioning
> **Date:** 2026-04-07
> **Status:** Approved

---

## Overview

Add a `partition` command group to the pg diagnostic tool, providing three subcommands for complete table partitioning lifecycle management:
- `partition advice` - Analyze tables and recommend partitioning strategies
- `partition ddl` - Generate partition DDL statements
- `partition info` - Display existing partitioned table information

## Goals

1. Help DBAs identify candidates for partitioning
2. Generate production-ready partition DDL with migration scripts
3. Monitor and visualize existing partitioned tables
4. Support RANGE, LIST, and HASH partitioning types

## Architecture

### Command Structure

```
pg partition advice <table>          # Analyze and recommend
pg partition ddl <table> [options]   # Generate DDL
pg partition info [table]            # Show partition info
```

### Component Design

#### 1. partition advice

**Purpose:** Analyze a table's structure, data distribution, and query patterns to recommend optimal partitioning strategies.

**Input:**
- Table name (required)

**Output:**
- Table statistics (rows, size, primary key)
- Candidate columns for partitioning
- Query pattern analysis
- Specific recommendations with performance estimates

**Analysis Factors:**
- Table size (>10GB recommended for partitioning)
- Row count (>10M rows)
- Time-based column presence (strong indicator for RANGE)
- Categorical columns (candidate for LIST)
- Query patterns from pg_stat_statements

**Implementation:**
```bash
cmd_partition_advice() {
  local table="$1"
  # 1. Validate table exists
  # 2. Gather table stats
  # 3. Analyze column types
  # 4. Query pg_stat_statements for access patterns
  # 5. Generate recommendations
}
```

#### 2. partition ddl

**Purpose:** Generate complete DDL statements for creating partitioned tables.

**Input:**
- Table name (required)
- Partition type: `--type={range|list|hash}` (optional, defaults to range)
- Partition column: `--column=<name>` (optional, auto-detected)
- For RANGE: `--interval={daily|weekly|monthly|yearly}` or `--start/--end`
- For LIST: `--values=<comma-separated-values>`
- For HASH: `--partitions=<count>`
- Migration flag: `--migrate` (include data migration)

**Output:**
- CREATE TABLE ... PARTITION BY statement
- CREATE PARTITION statements
- Optional: INSERT for data migration
- Optional: ALTER TABLE ... RENAME for switchover

**Implementation:**
```bash
cmd_partition_ddl() {
  local table="$1"
  local type="${2:-range}"
  local column="${3:-}"
  # Generate appropriate DDL based on type
}
```

**Interactive Mode:**
When run without options, enter interactive mode:
1. Show detected candidate columns
2. Prompt for partition type (with recommendation)
3. Prompt for partition column
4. Prompt for partition boundaries
5. Generate DDL

#### 3. partition info

**Purpose:** Display information about existing partitioned tables.

**Input:**
- Table name (optional - if omitted, list all partitioned tables)

**Output:**
- List of partitioned tables with summary stats
- Or detailed view of specific table's partitions

**Implementation:**
```bash
cmd_partition_info() {
  local table="${1:-}"
  if [ -z "$table" ]; then
    # List all partitioned tables
  else
    # Show detailed info for specific table
  fi
}
```

## Data Flow

### partition advice Flow
```
User Input: table_name
    ↓
Validate table exists → Error if not
    ↓
Gather stats: pg_table_size, pg_stat_user_tables
    ↓
Analyze columns: data types, min/max values
    ↓
Check query patterns: pg_stat_statements
    ↓
Generate recommendations
    ↓
Display formatted report
```

### partition ddl Flow
```
User Input: table_name + options (or interactive)
    ↓
Validate table exists
    ↓
Determine partition type and column
    ↓
Calculate partition boundaries
    ↓
Generate CREATE TABLE statement
    ↓
Generate CREATE PARTITION statements
    ↓
Optionally generate migration script
    ↓
Output DDL (to stdout or file)
```

### partition info Flow
```
User Input: [table_name]
    ↓
Query pg_inherits or pg_partitioned_table
    ↓
If no table_name: summarize all partitioned tables
    ↓
If table_name: query partition details
    ↓
Display formatted output
```

## SQL Templates

### Table Statistics Query
```sql
SELECT 
    c.relname as table_name,
    pg_size_pretty(pg_total_relation_size(c.oid)) as total_size,
    pg_total_relation_size(c.oid) as size_bytes,
    s.n_live_tup as live_tuples,
    s.n_dead_tup as dead_tuples,
    s.last_vacuum,
    s.last_autovacuum
FROM pg_class c
JOIN pg_stat_user_tables s ON c.relname = s.relname
WHERE c.relname = '$table' AND c.relkind = 'r'
```

### Column Analysis Query
```sql
SELECT 
    a.attname as column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type,
    CASE 
        WHEN a.atttypid IN (1082, 1114, 1184) THEN 'date/time'
        WHEN a.atttypid IN (20, 21, 23, 700, 701) THEN 'numeric'
        WHEN a.atttypid = 1043 THEN 'string'
        ELSE 'other'
    END as category
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
WHERE c.relname = '$table' 
    AND a.attnum > 0 
    AND NOT a.attisdropped
ORDER BY a.attnum
```

### Query Pattern Analysis
```sql
SELECT 
    query,
    calls,
    total_exec_time,
    rows
FROM pg_stat_statements
WHERE query LIKE '%$table%'
ORDER BY total_exec_time DESC
LIMIT 10
```

### Partitioned Tables List
```sql
SELECT 
    c.relname as table_name,
    pg_get_partkeydef(c.oid) as partition_key,
    c.relhassubclass as has_partitions
FROM pg_class c
JOIN pg_partitioned_table pt ON c.oid = pt.partrelid
ORDER BY c.relname
```

### Partition Details Query
```sql
SELECT 
    c.relname as partition_name,
    pg_get_expr(c.relpartbound, c.oid) as partition_bounds,
    pg_size_pretty(pg_total_relation_size(c.oid)) as size,
    s.n_live_tup as rows
FROM pg_class c
JOIN pg_inherits i ON c.oid = i.inhrelid
JOIN pg_class parent ON i.inhparent = parent.oid
LEFT JOIN pg_stat_user_tables s ON c.relname = s.relname
WHERE parent.relname = '$table'
ORDER BY c.relname
```

## Error Handling

### Common Error Scenarios

1. **Table does not exist**
   - Error message: "Table '$table' not found"
   - Exit code: 1

2. **Table is already partitioned**
   - For advice: Continue with analysis
   - For ddl: Warning "Table is already partitioned"
   - For info: Show partition details

3. **pg_stat_statements not available**
   - Advice command continues without query pattern analysis
   - Warning: "Query pattern analysis requires pg_stat_statements extension"

4. **No candidate columns for partitioning**
   - Advice: "No obvious partition candidates found. Manual review recommended."

5. **Invalid partition type**
   - DDL: "Invalid partition type '$type'. Use: range, list, or hash"

## User Interface

### Output Formatting

All commands support:
- Colorized output (blue headers, yellow warnings, red errors)
- Table-style output using `q()` helper
- Optional JSON output with `--format json`

### Interactive Prompts

When running `partition ddl` without sufficient parameters:
```
Table: orders (120GB, 50M rows)

Detected candidate columns:
  1. created_at (timestamp) - 78% of queries use this column
  2. user_id (bigint) - 45% of queries

Select partition type:
  1. RANGE (by time/value range) - Recommended
  2. LIST (by specific values)
  3. HASH (for even distribution)
  
Choice [1-3, default 1]: 

Select partition column:
  Choice [1-2, default 1]: 

Partition granularity for RANGE:
  1. Daily
  2. Weekly  
  3. Monthly - Recommended based on data size
  4. Yearly
  
Choice [1-4, default 3]: 

Generating DDL for 24 monthly partitions...
```

## Version Compatibility

### PostgreSQL Support
- **Minimum:** PostgreSQL 10 (declarative partitioning introduced)
- **Recommended:** PostgreSQL 12+ (partition pruning improvements)
- **Tested on:** 10, 11, 12, 13, 14, 15, 16, 17

### Version-Specific Features
- PG 11+: Default partition support
- PG 12+: Partition-level statistics
- PG 13+: Row-level BEFORE triggers on partitioned tables

## Security Considerations

1. **Read-only operations:** All commands use read-only queries
2. **Privilege check:** `partition ddl` should warn if user lacks CREATE TABLE privilege
3. **Sensitive data:** Query pattern analysis may expose sensitive query details - warn user

## Testing Strategy

### Test Cases

1. **Advice command tests:**
   - Small table (<1GB) - should recommend against partitioning
   - Large table with time column - should recommend RANGE
   - Table with categorical column - should recommend LIST option
   - Non-existent table - error handling

2. **DDL command tests:**
   - RANGE with monthly intervals
   - LIST with specific values
   - HASH with partition count
   - Interactive mode
   - Invalid parameters

3. **Info command tests:**
   - List all partitioned tables
   - Show specific table details
   - Empty database (no partitioned tables)

## Future Enhancements (Out of Scope)

- Partition maintenance commands (add/drop partitions)
- Automatic partition creation for time-based tables
- Partition pruning effectiveness analysis
- Cross-database partition comparison
- GUI visualization of partition distribution

## Dependencies

### Required
- PostgreSQL 10+
- psql client

### Optional
- pg_stat_statements extension (for query pattern analysis)

## Success Criteria

1. `pg partition advice <table>` provides actionable recommendations
2. `pg partition ddl <table>` generates valid, executable SQL
3. `pg partition info` displays accurate partition information
4. All commands follow existing pg tool patterns
5. Works with PostgreSQL 10 through 17

---

## Implementation Plan

Next step: Create detailed implementation plan using `superpowers:writing-plans` skill.
