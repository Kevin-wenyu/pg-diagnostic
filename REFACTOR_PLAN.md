# pg-diagnostic Refactor Plan

**Last Updated**: 2026-04-08
**Current Version**: 4.2.0

---

## Current Progress Summary

### Completed

#### 1. Production Safety Improvements
| Item | Status | Commit |
|------|--------|--------|
| Add confirmation prompts to `kill` command with `--force` bypass | ✅ | 4587e57 |
| Add confirmation prompts to `cancel` command with `--force` bypass | ✅ | 4587e57 |
| Add `--dry-run` to `partition ddl` command | ✅ | 4587e57 |
| Fix `q_sanitize` over-filtering bug | ✅ | 4587e57 |
| Add privilege check utilities | ✅ | 4587e57 |

#### 2. CI/CD Infrastructure
| Item | Status | Files |
|------|--------|-------|
| GitHub Actions CI workflow | ✅ | `.github/workflows/ci.yml` |
| ShellCheck integration | ✅ | `.github/workflows/ci.yml` |
| Bash syntax validation | ✅ | `.github/workflows/ci.yml` |
| PostgreSQL integration tests | ✅ | `.github/workflows/ci.yml` |
| Docker build verification | ✅ | `.github/workflows/ci.yml` |
| Docker image publishing | ✅ | `.github/workflows/docker.yml` |
| GitHub Container Registry integration | ✅ | `.github/workflows/docker.yml` |
| Automatic Release on version tags | ✅ | `.github/workflows/ci.yml` |

#### 3. Docker Support
| Item | Status | Files |
|------|--------|-------|
| Multi-stage Dockerfile | ✅ | `Dockerfile` |
| Non-root user execution | ✅ | `Dockerfile` |
| .dockerignore optimization | ✅ | `.dockerignore` |
| Docker usage documentation | ✅ | `README.md` |

#### 4. Documentation
| Item | Status | Files |
|------|--------|-------|
| CI status badge | ✅ | `README.md` |
| Docker installation instructions | ✅ | `README.md` |
| Version synchronization | ✅ | `README.md` (4.2.0) |
| .gitignore updated for .claude/ | ✅ | `.gitignore` |

---

## Known Issues & Technical Debt

### 1. Version Management
- **Issue**: Manual version synchronization between `pg` script and README
- **Risk**: Version numbers can become inconsistent
- **Mitigation**: Need automated CI check

### 2. Testing Coverage
- **Issue**: Only integration tests exist, no unit tests
- **Issue**: Only tests against PostgreSQL 16
- **Risk**: May miss version-specific bugs
- **Mitigation**: Add Bats unit tests and multi-version PG testing

### 3. Code Organization
- **Issue**: Single 241KB bash file is difficult to maintain
- **Risk**: Increasing complexity, harder to test
- **Mitigation**: Consider modularization (functions in separate files)

### 4. Documentation
- **Issue**: No CHANGELOG.md (version history embedded in script)
- **Issue**: No CONTRIBUTING.md
- **Issue**: No SECURITY.md
- **Mitigation**: Create standard documentation files

---

## Planned Refactors

### Phase 1: Testing & Quality (Priority: High)

#### 1.1 Add Version Consistency CI Check
```yaml
# Add to .github/workflows/ci.yml
- name: Check version consistency
  run: |
    PG_VERSION=$(grep "readonly TOOL_VERSION=" pg | cut -d'"' -f2)
    README_VERSION=$(grep "Current Version:" README.md | grep -oP '\d+\.\d+\.\d+')
    if [ "$PG_VERSION" != "$README_VERSION" ]; then
      echo "Version mismatch: pg=$PG_VERSION, README=$README_VERSION"
      exit 1
    fi
```

#### 1.2 Multi-Version PostgreSQL Testing
- Test against PG 14, 15, 16, 17
- Add version compatibility matrix to CI

#### 1.3 Add Unit Test Framework
- Implement Bats testing framework
- Test individual functions in isolation
- Add coverage reporting

### Phase 2: Documentation (Priority: Medium)

#### 2.1 Create CHANGELOG.md
- Migrate version history from script comments
- Follow Keep a Changelog format
- Link to changelog in README

#### 2.2 Add CONTRIBUTING.md
- Development setup instructions
- Commit message conventions
- PR guidelines
- Code review process

#### 2.3 Add SECURITY.md
- Supported versions
- Vulnerability reporting process
- Security update policy

### Phase 3: Code Organization (Priority: Medium)

#### 3.1 Modularize Code
```
lib/
  core.sh          # Core utilities (q, q_scalar, etc.)
  version.sh       # Version detection and compatibility
  commands/
    diagnostics.sh # ps, running, blocking, locks
    queries.sh     # slow, top_time, top_calls, etc.
    maintenance.sh # vacuum_status, dead_tuples, etc.
    replication.sh # repl, repl_lag, slot, etc.
```

#### 3.2 Create Source Entry Point
```bash
#!/bin/bash
# pg - main entry point
source "$(dirname "$0")/lib/core.sh"
source "$(dirname "$0")/lib/version.sh"
source "$(dirname "$0")/lib/commands/diagnostics.sh"
# ... etc
```

### Phase 4: Automation (Priority: Low)

#### 4.1 Release Automation Script
```bash
#!/bin/bash
# scripts/release.sh
# - Bump version in pg and README
# - Update CHANGELOG.md
# - Create git tag
# - Push to trigger release
```

#### 4.2 Pre-commit Hooks
- ShellCheck on commit
- Version consistency check
- Test execution

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| CI Build Time | ~3 min | <2 min |
| Test Coverage | 0% | 50%+ |
| PostgreSQL Versions Tested | 1 | 4 (14-17) |
| Documentation Files | 1 (README) | 5+ |
| Code Organization | Single file | Modular |

---

## Notes

- **Current State**: Production-ready with CI/CD
- **Next Priority**: Testing infrastructure
- **Risk Level**: Low (stable, working code)
- **Est. Time to Complete Phase 1**: 1-2 days

---

## References

- CI Status: https://github.com/Kevin-wenyu/pg-diagnostic/actions
- Docker Images: https://github.com/Kevin-wenyu/pg-diagnostic/pkgs/container/pg-diagnostic
