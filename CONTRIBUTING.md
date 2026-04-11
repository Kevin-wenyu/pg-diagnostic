# Contributing to pg-diagnostic

感谢你对 pg-diagnostic 的兴趣！欢迎贡献代码。

## 开发环境设置

```bash
# 克隆项目
git clone https://github.com/Kevin-wenyu/pg-diagnostic.git
cd pg-diagnostic

# 使脚本可执行
chmod +x pg

# 设置 PostgreSQL 连接 (使用环境变量)
export PGHOST=localhost
export PGPORT=5432
export PGUSER=postgres
export PGDATABASE=postgres
# 可选: export PGPASSWORD=your_password
```

## 测试本地环境

```bash
# 基本测试
./pg --help
./pg version
./pg ps

# 带调试输出
DEBUG_QUERIES=1 ./pg ps

# 使用参数连接
./pg -h localhost -p 5432 -u postgres -d postgres ps
```

## 添加新命令

### 1. 创建命令函数

在 `pg` 文件中添加 `cmd_<command_name>()` 函数：

```bash
# 命令: my_command [options]
cmd_my_command() {
    local param1="${1:-}"
    local param2="${2:-20}"

    # 参数验证 (如需要)
    [ -n "$param1" ] && param1=$(q_sanitize "$param1")

    # 版本检查 (如需要)
    if [ "$PG_MAJOR_VERSION" -ge 17 ]; then
        # PG 17+ 特定逻辑
    fi

    # 执行查询
    q "SELECT ..."
}
```

### 2. 注册命令

在 `dispatch_command()` 函数的 case 语句中添加：

```bash
my_command)
    cmd_my_command "$@"
    ;;
```

### 3. 添加帮助文本

在 `show_cmd_help()` 函数中添加命令说明。

### 4. 测试命令

```bash
./pg my_command
DEBUG_QUERIES=1 ./pg my_command param1
```

## 版本兼容性

编写代码时必须考虑 PostgreSQL 9.6-18 兼容性：

```bash
# 版本检测 (已在脚本中实现)
# $PG_MAJOR_VERSION 变量可用

# PG 13+ 使用 total_exec_time，旧版本使用 total_time
if [ "$PG_MAJOR_VERSION" -ge 13 ]; then
    col="total_exec_time"
else
    col="total_time"
fi
```

关键版本差异：
| 版本 | 特性 |
|------|------|
| 9.6-12 | 基础视图 |
| 10+ | 复制槽、wait_event |
| 13+ | pg_stat_statements 列名变更 |
| 17+ | pg_wait_events、pg_stat_checkpoints |

## 安全规范

- **必须**使用 `q_sanitize()` 处理用户输入
- **必须**对特权操作调用 `require_superuser()` 或 `require_privilege()`
- **禁止**记录密码
- **禁止**直接执行用户提供的 SQL

## 测试指南

### 本地测试

```bash
# 语法检查
bash -n pg

# ShellCheck
shellcheck pg

# Bats 测试
bats tests/commands/
bats tests/integration/
```

### 测试覆盖要求

- 新命令必须有基本的功能测试
- 测试应覆盖：成功路径、错误处理、参数验证

## 提交规范

### 提交信息格式

```
<type>: <简短描述>

<详细说明 (可选)>

Closes #<issue-number> (如果有)
```

类型：
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `refactor`: 重构
- `test`: 测试相关
- `ci`: CI/CD 相关

### 示例

```
feat: add cache_hit command

Add new command to display cache hit ratios for shared buffers.
Uses pg_stat_database view for calculating hit ratios.

Closes #42
```

## 发布流程

使用 `release.sh` 脚本：

```bash
# 准备发布
./release.sh 4.3.0

# 推送并创建 release
git push && git push origin v4.3.0
```

## 代码规范

- 使用 4 空格缩进
- 函数名使用 `cmd_<name>()` 模式
- 变量使用大写字母加下划线
- 局部变量使用 `local` 声明
- 字符串比较使用 `[[ ]]`，避免 `[ ]`

## 获取帮助

- 提交 Issue: https://github.com/Kevin-wenyu/pg-diagnostic/issues
- 查看命令文档: `./pg --help`
- 查看特定命令: `./pg <command> --help`