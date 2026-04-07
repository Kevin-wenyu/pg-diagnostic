# Partition Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `partition` command group with `advice`, `ddl`, and `info` subcommands for PostgreSQL table partitioning management.

**Architecture:** Extend the pg tool by adding SQL templates, command functions, and dispatch entries following the existing pattern. All code goes into the `pg` file with readonly SQL templates at the top, command functions in the middle, and dispatch entries at the end.

**Tech Stack:** Bash, PostgreSQL system catalogs, existing pg tool framework

---

## File Structure

**Single file modification:** `pg` - The main pg tool script

The pg tool is organized as:
1. SQL templates (readonly variables) - lines 340-400
2. Command functions - lines 1160-6500
3. Dispatch logic - lines 6500+

All changes will be additive, following existing patterns.

---

## Task 1: Add SQL Query Templates for Partition Analysis

**Files:**
- Modify: `pg` (after line 353, near other SQL templates)

**Context:** The pg tool uses readonly SQL template variables. These are referenced by command functions.

- [ ] **Step 1: Add SQL_PARTITION_TABLE_STATS template**

Add after `SQL_REPLICATION_SLOT_LAG` (around line 362):

```bash
# Partition analysis queries
# shellcheck disable=SC2034
readonly SQL_PARTITION_TABLE_STATS="SELECT 
    c.relname as table_name,
    pg_size_pretty(pg_total_relation_size(c.oid)) as total_size,
    pg_total_relation_size(c.oid) as size_bytes,
    s.n_live_tup as live_tuples,
    s.n_dead_tup as dead_tuples
FROM pg_class c
JOIN pg_stat_user_tables s ON c.relname = s.relname
WHERE c.relname = '%s' AND c.relkind = 'r'"

readonly SQL_PARTITION_COLUMNS="SELECT 
    a.attname as column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type,
    CASE 
        WHEN a.atttypid IN (1082, 1114, 1184, 1182) THEN 'date_time'
        WHEN a.atttypid IN (20, 21, 23, 700, 701, 1700) THEN 'numeric'
        WHEN a.atttypid IN (1042, 1043, 25) THEN 'string'
        ELSE 'other'
    END as category,
    CASE WHEN a.attname IN (
        SELECT a2.attname 
        FROM pg_index i 
        JOIN pg_attribute a2 ON i.indrelid = a2.attrelid 
        WHERE i.indrelid = c.oid AND a2.attnum = ANY(i.indkey) AND i.indisprimary
    ) THEN true ELSE false END as is_pk
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
WHERE c.relname = '%s' 
    AND a.attnum > 0 
    AND NOT a.attisdropped
ORDER BY a.attnum"

readonly SQL_PARTITION_EXISTS="SELECT 
    c.relkind,
    CASE WHEN pt.partrelid IS NOT NULL THEN true ELSE false END as is_partitioned
FROM pg_class c
LEFT JOIN pg_partitioned_table pt ON c.oid = pt.partrelid
WHERE c.relname = '%s'"

readonly SQL_PARTITION_LIST="SELECT 
    c.relname as table_name,
    pg_get_partkeydef(c.oid) as partition_key,
    c.relhassubclass as has_partitions
FROM pg_class c
JOIN pg_partitioned_table pt ON c.oid = pt.partrelid
ORDER BY c.relname"

readonly SQL_PARTITION_DETAIL="SELECT 
    c.relname as partition_name,
    pg_get_expr(c.relpartbound, c.oid) as partition_bounds,
    pg_size_pretty(pg_total_relation_size(c.oid)) as size,
    COALESCE(s.n_live_tup, 0) as rows
FROM pg_class c
JOIN pg_inherits i ON c.oid = i.inhrelid
JOIN pg_class parent ON i.inhparent = parent.oid
LEFT JOIN pg_stat_user_tables s ON c.relname = s.relname
WHERE parent.relname = '%s'
ORDER BY c.relname"

readonly SQL_PARTITION_COLUMN_STATS="SELECT 
    attname as column_name,
    n_distinct,
    null_frac,
    correlation
FROM pg_stats
WHERE tablename = '%s' AND schemaname = 'public'"
```

- [ ] **Step 2: Verify templates added**

Run: `grep -n "SQL_PARTITION" pg | head -10`
Expected output: Shows all 6 template variables defined

- [ ] **Step 3: Commit**

```bash
git add pg
git commit -m "feat: add SQL templates for partition command"
```

---

## Task 2: Implement cmd_partition_advice Function

**Files:**
- Modify: `pg` (after `cmd_slot_lag` function, around line 2305)

**Context:** This function analyzes a table and provides partitioning recommendations.

- [ ] **Step 1: Add cmd_partition_advice function**

Add after `cmd_slot_lag`:

```bash
cmd_partition_advice()
{
  local table="$1"
  
  if [ -z "$table" ]; then
    echo "Usage: pg partition advice <table>"
    echo ""
    echo "Analyze a table and recommend partitioning strategies."
    return 1
  fi

  # Sanitize table name
  table=$(q_sanitize "$table")

  # Check if table exists
  local table_info
  table_info=$(q "$(printf "$SQL_PARTITION_TABLE_STATS" "$table")" 2>/dev/null)
  
  if [ -z "$table_info" ]; then
    msg_error "Table '$table' not found"
    return 1
  fi

  # Check if already partitioned
  local partition_check
  partition_check=$(q "$(printf "$SQL_PARTITION_EXISTS" "$table")" 2>/dev/null)
  
  if echo "$partition_check" | grep -q "t"; then
    colorize yellow "Note: Table '$table' is already partitioned"
    echo ""
  fi

  # Display header
  colorize blue "=== PARTITION ANALYSIS: $table ==="
  echo ""

  # Show table stats
  echo "$table_info"
  echo ""

  # Get size in bytes for analysis
  local size_bytes
  size_bytes=$(q_scalar "SELECT pg_total_relation_size('$table'::regclass)" 2>/dev/null)
  
  # Get row count
  local row_count
  row_count=$(q_scalar "SELECT reltuples::bigint FROM pg_class WHERE relname = '$table'" 2>/dev/null)

  # Analyze columns
  local columns
  columns=$(q "$(printf "$SQL_PARTITION_COLUMNS" "$table")" 2>/dev/null)
  
  if [ -n "$columns" ]; then
    colorize blue "--- Column Analysis ---"
    echo "$columns"
    echo ""
  fi

  # Generate recommendations
  colorize blue "--- Partitioning Recommendations ---"
  echo ""

  # Check if table is large enough to benefit from partitioning
  if [ -n "$size_bytes" ] && [ "$size_bytes" -gt 10737418240 ]; then  # 10GB
    colorize green "✓ Table size ($size_bytes bytes) exceeds 10GB threshold"
    echo "  Partitioning is recommended for tables > 10GB"
    echo ""
  elif [ -n "$row_count" ] && [ "$row_count" -gt 10000000 ]; then  # 10M rows
    colorize green "✓ Table has $row_count rows (exceeds 10M threshold)"
    echo "  Partitioning is recommended for large tables"
    echo ""
  else
    colorize yellow "⚠ Table may not benefit significantly from partitioning"
    echo "  Consider partitioning when table exceeds 10GB or 10M rows"
    echo ""
  fi

  # Identify candidate columns
  local time_column
  time_column=$(echo "$columns" | grep "date_time" | head -1 | awk '{print $1}')
  
  local pk_column
  pk_column=$(echo "$columns" | awk '$5 == "t" {print $1}' | head -1)

  if [ -n "$time_column" ]; then
    colorize green "✓ Candidate column found: $time_column (date/time type)"
    echo "  Recommended partition type: RANGE"
    echo "  Recommended column: $time_column"
    
    # Get time range
    local time_range
    time_range=$(q "SELECT MIN($time_column), MAX($time_column) FROM $table" 2>/dev/null)
    if [ -n "$time_range" ]; then
      echo "  Data range: $time_range"
    fi
    echo ""
  fi

  if [ -n "$pk_column" ]; then
    echo "  Primary key: $pk_column"
    echo ""
  fi

  # General recommendations
  echo "General Guidelines:"
  echo "  • RANGE: Best for time-series data (logs, events, orders)"
  echo "  • LIST: Best for categorical data (regions, statuses, types)"
  echo "  • HASH: Best for even distribution when no natural range"
  echo ""
  echo "Next steps:"
  echo "  pg partition ddl $table --type=range --column=<column>"
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n pg && echo "Syntax OK"`
Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add pg
git commit -m "feat: implement partition advice command"
```

---

## Task 3: Implement cmd_partition_ddl Function

**Files:**
- Modify: `pg` (after `cmd_partition_advice`)

**Context:** This function generates partition DDL statements.

- [ ] **Step 1: Add helper function for generating RANGE partitions**

```bash
_partition_generate_range()
{
  local table="$1"
  local column="$2"
  local interval="$3"  # daily, weekly, monthly, yearly
  local start_date="$4"
  local partitions="$5"
  local with_data="$6"

  echo "-- Partition DDL for table: $table"
  echo "-- Generated: $(date)"
  echo ""
  
  # Create partitioned table
  echo "-- 1. Create partitioned table"
  echo "CREATE TABLE ${table}_partitioned ("
  echo "    LIKE $table INCLUDING ALL"
  echo ") PARTITION BY RANGE ($column);"
  echo ""

  # Generate partition definitions
  echo "-- 2. Create partitions"
  local i=0
  local current_date="$start_date"
  
  while [ $i -lt $partitions ]; do
    local next_date
    local partition_name
    
    case "$interval" in
      daily)
        next_date=$(date -d "$current_date + 1 day" '+%Y-%m-%d' 2>/dev/null || date -v+1d -j -f '%Y-%m-%d' "$current_date" '+%Y-%m-%d' 2>/dev/null)
        partition_name="${table}_$(date -d "$current_date" '+%Y%m%d' 2>/dev/null || date -j -f '%Y-%m-%d' "$current_date" '+%Y%m%d' 2>/dev/null)"
        ;;
      monthly)
        next_date=$(date -d "$current_date + 1 month" '+%Y-%m-01' 2>/dev/null || date -v+1m -j -f '%Y-%m-%d' "$current_date" '+%Y-%m-01' 2>/dev/null)
        partition_name="${table}_$(date -d "$current_date" '+%Y%m' 2>/dev/null || date -j -f '%Y-%m-%d' "$current_date" '+%Y%m' 2>/dev/null)"
        ;;
      yearly)
        next_date=$(date -d "$current_date + 1 year" '+%Y-01-01' 2>/dev/null || date -v+1y -j -f '%Y-%m-%d' "$current_date" '+%Y-01-01' 2>/dev/null)
        partition_name="${table}_$(date -d "$current_date" '+%Y' 2>/dev/null || date -j -f '%Y-%m-%d' "$current_date" '+%Y' 2>/dev/null)"
        ;;
    esac

    echo "CREATE TABLE ${partition_name} PARTITION OF ${table}_partitioned"
    echo "    FOR VALUES FROM ('$current_date') TO ('next_date');"
    echo ""
    
    current_date="$next_date"
    i=$((i + 1))
  done

  # Optional: Data migration
  if [ "$with_data" = "true" ]; then
    echo "-- 3. Migrate data (run during maintenance window)"
    echo "INSERT INTO ${table}_partitioned SELECT * FROM $table;"
    echo ""
    echo "-- 4. Switch table names (requires exclusive lock)"
    echo "BEGIN;"
    echo "    ALTER TABLE $table RENAME TO ${table}_old;"
    echo "    ALTER TABLE ${table}_partitioned RENAME TO $table;"
    echo "COMMIT;"
    echo ""
    echo "-- 5. Verify and drop old table"
    echo "-- DROP TABLE ${table}_old;"
  fi
}
```

- [ ] **Step 2: Add cmd_partition_ddl function**

```bash
cmd_partition_ddl()
{
  local table=""
  local type="range"
  local column=""
  local interval="monthly"
  local start_date=""
  local partitions="12"
  local values=""
  local partition_count="16"
  local with_data="false"
  local output_file=""

  # Parse first argument (table name)
  if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
    table="$1"
    shift
  fi

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type) type="$2"; shift 2 ;;
      --column) column="$2"; shift 2 ;;
      --interval) interval="$2"; shift 2 ;;
      --start) start_date="$2"; shift 2 ;;
      --partitions) partitions="$2"; shift 2 ;;
      --values) values="$2"; shift 2 ;;
      --partition-count) partition_count="$2"; shift 2 ;;
      --migrate) with_data="true"; shift ;;
      --output) output_file="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$table" ]; then
    echo "Usage: pg partition ddl <table> [options]"
    echo ""
    echo "Options:"
    echo "  --type {range|list|hash}   Partition type (default: range)"
    echo "  --column <name>            Partition column (auto-detected if not specified)"
    echo "  --interval <granularity>   For RANGE: daily|weekly|monthly|yearly"
    echo "  --start <date>             Start date for RANGE (default: today)"
    echo "  --partitions <n>           Number of partitions for RANGE (default: 12)"
    echo "  --values <list>            For LIST: comma-separated values"
    echo "  --partition-count <n>      For HASH: number of partitions (default: 16)"
    echo "  --migrate                  Include data migration statements"
    echo "  --output <file>            Save DDL to file (default: stdout)"
    return 1
  fi

  # Sanitize
  table=$(q_sanitize "$table")
  column=$(q_sanitize "$column")

  # Verify table exists
  local table_exists
  table_exists=$(q_scalar "SELECT 1 FROM pg_class WHERE relname = '$table' LIMIT 1" 2>/dev/null)
  if [ -z "$table_exists" ]; then
    msg_error "Table '$table' not found"
    return 1
  fi

  # Auto-detect column if not specified
  if [ -z "$column" ]; then
    column=$(q "$(printf "$SQL_PARTITION_COLUMNS" "$table")" 2>/dev/null | grep "date_time" | head -1 | awk '{print $1}')
    if [ -n "$column" ]; then
      msg_info "Auto-detected partition column: $column"
    fi
  fi

  if [ -z "$column" ]; then
    msg_error "No partition column specified and no suitable column auto-detected"
    echo "Please specify with --column"
    return 1
  fi

  # Set default start date
  if [ -z "$start_date" ]; then
    start_date=$(date '+%Y-%m-01')  # First day of current month
  fi

  # Generate DDL based on type
  local ddl_output
  
  case "$type" in
    range)
      ddl_output=$(_partition_generate_range "$table" "$column" "$interval" "$start_date" "$partitions" "$with_data")
      ;;
    list)
      msg_error "LIST partition generation not yet implemented"
      return 1
      ;;
    hash)
      msg_error "HASH partition generation not yet implemented"
      return 1
      ;;
    *)
      msg_error "Unknown partition type: $type"
      return 1
      ;;
  esac

  # Output
  if [ -n "$output_file" ]; then
    echo "$ddl_output" > "$output_file"
    colorize green "DDL saved to: $output_file"
  else
    echo "$ddl_output"
  fi
}
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n pg && echo "Syntax OK"`
Expected: `Syntax OK`

- [ ] **Step 4: Commit**

```bash
git add pg
git commit -m "feat: implement partition ddl command with RANGE support"
```

---

## Task 4: Implement cmd_partition_info Function

**Files:**
- Modify: `pg` (after `cmd_partition_ddl`)

**Context:** This function displays information about existing partitioned tables.

- [ ] **Step 1: Add cmd_partition_info function**

```bash
cmd_partition_info()
{
  local table="${1:-}"

  if [ -z "$table" ]; then
    # List all partitioned tables
    colorize blue "=== PARTITIONED TABLES ==="
    echo ""

    local result
    result=$(q "$SQL_PARTITION_LIST" 2>/dev/null)

    if [ -z "$result" ]; then
      msg_info "No partitioned tables found"
      return 0
    fi

    echo "$result"
  else
    # Show details for specific table
    table=$(q_sanitize "$table")
    
    colorize blue "=== PARTITION DETAILS: $table ==="
    echo ""

    # Show partition strategy
    local strategy
    strategy=$(q "SELECT pg_get_partkeydef('$table'::regclass)" 2>/dev/null)
    
    if [ -n "$strategy" ]; then
      echo "Partition Key: $strategy"
      echo ""
    fi

    # Show partition details
    local details
    details=$(q "$(printf "$SQL_PARTITION_DETAIL" "$table")" 2>/dev/null)

    if [ -z "$details" ]; then
      msg_info "No partitions found for table '$table'"
      return 0
    fi

    echo "$details"
    echo ""

    # Show summary stats
    colorize blue "--- Summary ---"
    
    local partition_count
    partition_count=$(q_scalar "SELECT count(*) FROM pg_inherits i JOIN pg_class c ON i.inhparent = c.oid WHERE c.relname = '$table'" 2>/dev/null)
    
    local total_size
    total_size=$(q_scalar "SELECT pg_size_pretty(sum(pg_total_relation_size(c.oid))) FROM pg_class c JOIN pg_inherits i ON c.oid = i.inhrelid JOIN pg_class parent ON i.inhparent = parent.oid WHERE parent.relname = '$table'" 2>/dev/null)

    echo "Partitions: $partition_count"
    echo "Total Size: $total_size"
  fi
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n pg && echo "Syntax OK"`
Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add pg
git commit -m "feat: implement partition info command"
```

---

## Task 5: Add Main cmd_partition Dispatcher

**Files:**
- Modify: `pg` (after `cmd_partition_info`)

**Context:** This function dispatches to the appropriate partition subcommand.

- [ ] **Step 1: Add cmd_partition dispatcher function**

```bash
cmd_partition()
{
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
    advice)
      cmd_partition_advice "$@"
      ;;
    ddl)
      cmd_partition_ddl "$@"
      ;;
    info)
      cmd_partition_info "$@"
      ;;
    *)
      echo "Usage: pg partition <subcommand> [options]"
      echo ""
      echo "Subcommands:"
      echo "  advice <table>      Analyze table and recommend partitioning"
      echo "  ddl <table>         Generate partition DDL"
      echo "  info [table]        Show partition information"
      echo ""
      echo "Examples:"
      echo "  pg partition advice orders"
      echo "  pg partition ddl orders --type=range --column=created_at"
      echo "  pg partition info orders"
      ;;
  esac
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n pg && echo "Syntax OK"`
Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add pg
git commit -m "feat: add partition command dispatcher"
```

---

## Task 6: Add Command to Dispatch Table

**Files:**
- Modify: `pg` (in dispatch_command case statement, around line 6170)

**Context:** Add entry to route `partition` command to cmd_partition.

- [ ] **Step 1: Add dispatch entry**

Find the section with other commands and add:

```bash
    partition)             cmd_partition "$@" ;;
```

This should be placed alphabetically or logically with other multi-word commands. A good location is after `overview` and before `plan_analysis`.

- [ ] **Step 2: Verify dispatch**

Run: `grep -n "partition)" pg`
Expected: Shows the dispatch line

- [ ] **Step 3: Commit**

```bash
git add pg
git commit -m "feat: add partition to command dispatch"
```

---

## Task 7: Add Usage Documentation

**Files:**
- Modify: `pg` (in usage() function)

**Context:** Add partition commands to help text.

- [ ] **Step 1: Add partition to usage help**

Find the REPLICATION section (around line 860) and add after it:

```
  === PARTITION (Table Partitioning) ===
    partition advice <table>  Analyze and recommend partitioning
    partition ddl <table>     Generate partition DDL
    partition info [table]    Show partition information
```

- [ ] **Step 2: Verify usage**

Run: `./pg --help | grep -A 3 "PARTITION"`
Expected: Shows partition commands

- [ ] **Step 3: Commit**

```bash
git add pg
git commit -m "docs: add partition commands to usage help"
```

---

## Task 8: Update README Documentation

**Files:**
- Modify: `README.md`

**Context:** Add partition commands to README.

- [ ] **Step 1: Add partition section to README**

Find the Replication section in README (around line 163) and add after it:

```markdown
### Partition (Table Partitioning)

| Command | Description |
|---------|-------------|
| `partition advice <table>` | Analyze table and recommend partitioning strategy |
| `partition ddl <table>` | Generate partition DDL statements |
| `partition info [table]` | Show partition information |

Examples:
```bash
# Analyze orders table for partitioning
pg partition advice orders

# Generate RANGE partition DDL for orders table
pg partition ddl orders --type=range --column=created_at --interval=monthly

# Show all partitioned tables
pg partition info

# Show details for specific table
pg partition info orders
```
```

- [ ] **Step 2: Verify README**

Run: `grep -A 5 "partition" README.md | head -15`
Expected: Shows partition documentation

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add partition commands to README"
```

---

## Task 9: Test All Partition Commands

**Files:**
- Test only, no file changes

**Context:** Verify all partition commands work correctly.

- [ ] **Step 1: Test syntax validation**

Run: `bash -n pg && echo "Syntax OK"`
Expected: `Syntax OK`

- [ ] **Step 2: Test help display**

Run: `./pg --help | grep -A 3 "PARTITION"`
Expected: Shows partition commands

- [ ] **Step 3: Test partition advice (table not exists)**

Run: `./pg partition advice nonexistent 2>&1 | head -3`
Expected: Shows "Table 'nonexistent' not found" error

- [ ] **Step 4: Test partition ddl (table not exists)**

Run: `./pg partition ddl nonexistent 2>&1 | head -3`
Expected: Shows "Table 'nonexistent' not found" error

- [ ] **Step 5: Test partition info (list all)**

Run: `./pg partition info 2>&1 | head -5`
Expected: Shows header "=== PARTITIONED TABLES ==="

- [ ] **Step 6: Test partition command usage**

Run: `./pg partition 2>&1 | head -10`
Expected: Shows usage information

- [ ] **Step 7: Commit**

```bash
git commit --allow-empty -m "test: verify partition commands"
```

---

## Summary

This implementation adds:

1. **6 SQL query templates** for partition analysis
2. **5 command functions**:
   - `cmd_partition_advice()` - Analyze tables
   - `cmd_partition_ddl()` - Generate DDL (RANGE support)
   - `cmd_partition_info()` - Show partition info
   - `cmd_partition()` - Main dispatcher
   - `_partition_generate_range()` - Helper for RANGE DDL
3. **Dispatch integration** - Routes `partition` command
4. **Documentation** - Usage help and README
5. **Tests** - Syntax and basic functionality

**Commands added:**
- `pg partition advice <table>`
- `pg partition ddl <table> [options]`
- `pg partition info [table]`

**Note:** LIST and HASH partition generation are stubbed with error messages. Full implementation can be added as a future enhancement.
