# pg-diagnostic - CLAUDE.md

PostgreSQL 在线诊断工具。单文件 Bash 脚本（`pg`），连接运行中的 PG 实例执行诊断。

## 项目定位

- **工具名**: pg-diagnostic
- **类型**: 单文件 Bash CLI 工具
- **用途**: PostgreSQL 数据库监控、诊断、性能分析
- **目标用户**: DBA、运维工程师、SRE
- **PG 兼容性**: 9.6 - 18

---

## 设计约束

### 核心约束

| 约束 | 说明 |
|------|------|
| 单文件架构 | 所有 60+ 命令在一个 `pg` 脚本中 |
| Bash only | 无外部依赖，仅需 psql 客户端 |
| 版本兼容 | 必须在 PG 9.6-18 上通过运行时特性检测工作 |
| 无传统 TDD | Bash 项目，通过语法检查 + 集成测试验证 |
| 最小依赖 | Alpine Docker, bash 4.0+, psql 客户端 |

### 禁止事项

- 不拆分为多文件（单文件是核心设计约束）
- 新增 SQL 必须用 `q_sanitize()` 处理用户输入
- 涉及特权操作必须先调用 `require_superuser()` 或 `require_privilege()`
- 不引入外部依赖（纯 bash + psql）

---

## 架构设计

### 入口流程

```
pg [global options] <command> [command options]
```

### 关键组件

| 组件 | 位置 | 说明 |
|------|------|------|
| 全局选项 | ~lines 1100-1128 | `-h`, `-p`, `-u`, `-d`, `-P`, `--help` |
| 版本检测 | `get_version()` ~line 648 | 解析 PostgreSQL 版本字符串 |
| 特性检测 | `init_version_features()` ~line 703 | 运行时兼容性标志 |
| 查询函数 | `q()`, `q_scalar()`, `q_json()` | SQL 执行和输出格式化 |
| 命令分发 | `cmd_<name>()` | 各命令实现 |

### 核心函数

```bash
# 标准查询执行
q() {
    local sql="$1"
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -A -c "$sql"
}

# 单值查询 (用于算术运算)
q_scalar() {
    local sql="$1"
    q "$sql" | tr -d ' '
}

# JSON 输出
q_json() {
    local sql="$1"
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -A -F ' ' -c "$sql" 2>/dev/null
}
```

---

## 命令开发标准

### 新增命令流程

1. **定义函数**: `cmd_<command_name>()`
2. **添加参数定义**: `CMD_PARAMS_<command>` (~line 124)
3. **实现逻辑**: 使用 `q()` 或 `q_scalar()`
4. **版本检查**: 如需特殊处理用 `$PG_MAJOR_VERSION`
5. **添加帮助**: `show_cmd_help()` (~line 180)

### 命令函数模板

```bash
# 命令: my_command [options]
cmd_my_command() {
    local pattern="${1:-}"
    local limit="${2:-20}"
    
    # 参数验证
    [ -n "$pattern" ] && pattern=$(q_sanitize "$pattern")
    
    # 版本兼容
    if [ "$PG_MAJOR_VERSION" -ge 17 ]; then
        # PG 17+ 特定逻辑
    fi
    
    # 执行查询
    q "SELECT ..."
}
```

### SQL 查询规范

- 使用 `-t -A` 标志获取机器可读输出
- 用户输入使用 `q_sanitize()` 净化
- 处理连接错误

---

## 版本兼容性规范

### 版本范围与特性

| PG 版本 | 特性 |
|---------|------|
| 9.6-12 | 基础视图 |
| 10+ | 复制槽、pg_stat_activity 中的 wait_event |
| 13+ | pg_stat_statements 列名变更 (`total_exec_time`) |
| 14+ | `pg_terminate_backend(pid, timeout)` |
| 17+ | `pg_wait_events`、`pg_stat_checkpoints` |
| 18+ | WAL 指标 |

### 特性标志

```bash
# 必须使用的特性标志
PG_MAJOR_VERSION      # 从版本字符串提取
HAS_PG_WAIT_EVENTS     # wait event 支持
HAS_REPLICATION_SLOTS # 复制槽支持
HAS_PG_STAT_CHECKPOINTS # PG17+ stats
PG_TERMINATE_FUNC     # 终止函数签名
```

### 版本兼容模式

```bash
if [ "$PG_MAJOR_VERSION" -ge 17 ]; then
    # PG 17+ 使用 pg_stat_checkpointer
    HAS_PG_STAT_CHECKPOINTS=true
elif [ "$PG_MAJOR_VERSION" -ge 10 ]; then
    # 旧版使用 pg_stat_bgwriter
    HAS_PG_STAT_CHECKPOINTS=false
fi
```

---

## 测试策略

### CI 流水线

```
lint → test → docker-build → release
```

### 测试命令

```bash
# 语法检查
bash -n pg

# ShellCheck
shellcheck pg

# 功能测试
./pg --help
./pg version
./pg ps
./pg conn
./pg health
```

### 测试环境变量

```bash
export PGHOST=localhost
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD=postgres
export PGDATABASE=postgres
```

---

## 安全规范

| 规则 | 说明 |
|------|------|
| 密码处理 | 永不记录密码，使用 `-w` 标志 |
| 认证方式 | 支持 .pgpass 文件 |
| SQL 注入 | 所有用户输入用 `q_sanitize()` 净化 |
| LIKE 模式 | 仅用于模式匹配，无直接 SQL 执行 |
| 特权操作 | `require_superuser()` 或 `require_privilege()` |

---

## 常用命令速查

### 快速诊断

| 命令 | 说明 |
|------|------|
| `ps` | 进程列表（所有会话） |
| `running [N]` | 活动查询 |
| `blocking` | 阻塞分析 |
| `locks` | 锁概览 |
| `slow [N]` | 慢查询分析 |

### 性能分析

| 命令 | 说明 |
|------|------|
| `top_time [N]` | 按总时间排序查询 |
| `top_calls [N]` | 按调用次数排序 |
| `cache_hit` | 缓存命中率 |
| `wait_events` | 等待事件 |

### 健康检查

| 命令 | 说明 |
|------|------|
| `health` | 快速健康检查 |
| `overview` | 系统概览 |
| `uptime` | 服务器运行时间 |
| `diagnose <场景>` | 综合诊断 |

---

## 开发工作流

### 本地测试

```bash
# 基本测试
./pg --help
./pg version

# 带调试
DEBUG_QUERIES=1 ./pg slow 10

# 指定连接
./pg -h localhost -p 5432 -u postgres -d mydb ps
```

### Debug 模式

```bash
# 查看实际执行的 SQL
DEBUG_QUERIES=1 ./pg <command>
```

---

## 变更日志

| 版本 | 日期 | 变更 |
|------|------|------|
| 4.2.0 | 2026-03-27 | 当前版本 |
| 4.1.0 | - | 分区命令 |
| 4.0.0 | - | 综合诊断 |

详细变更见 README.md Changelog 部分。