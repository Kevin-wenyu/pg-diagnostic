# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.2.0] - 2026-03-27

### Added
- Storage diagnostic commands (db_size, ts_size, schema_size, toast_tables)
- Index diagnostic commands (index_size, index_usage, duplicate_indexes)
- Vacuum diagnostic commands (vacuum_status, vacuum_progress, dead_tuples)
- diagnose security scenario

### Changed
- Enhanced partition commands with --dry-run support

## [4.1.0] - 2026-02-15

### Added
- Partition analysis commands (partition advice, partition ddl, partition info)
- Partition DDL generation with range/list/hash strategies
- Weekly interval support for partitioning

## [4.0.0] - 2026-01-10

### Added
- Comprehensive diagnose command with scenarios (health, performance, connection, blocking, capacity, replication)
- Enhanced security commands (security_checks, privilege_audit, user_access_pattern)
- Enterprise monitoring features

### Changed
- Migrated to new command structure

## [3.0.0] - 2025-12-01

### Added
- Full PostgreSQL 17+ support
- WAL and checkpoint monitoring
- Enhanced replication monitoring

## [2.0.0] - 2025-10-01

### Added
- Complete rewrite for better performance
- PostgreSQL 9.6-16 compatibility

## [1.0.0] - 2025-06-01

### Added
- Initial release
- Basic diagnostic commands