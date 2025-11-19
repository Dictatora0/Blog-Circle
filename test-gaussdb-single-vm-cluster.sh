#!/bin/bash

# 验证单 VM 上的 GaussDB 一主二备集群

set -e

DOCKER_CMD="/usr/local/bin/docker"
VM_IP="10.211.55.11"

# 三个实例的端口
PRIMARY_PORT=5432
STANDBY1_PORT=5433
STANDBY2_PORT=5434

DB_USER="bloguser"
DB_PASSWORD="747599qw@"
DB_NAME="blog_db"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }

header() {
    echo ""
    echo "========================================="
    echo "   $1"
    echo "========================================="
    echo ""
}

# 执行 SQL
run_sql() {
    local port="$1"
    local sql="$2"
    local db="${3:-postgres}"
    
    $DOCKER_CMD run --rm -e PGPASSWORD="${DB_PASSWORD}" postgres:15-alpine \
        psql -h "${VM_IP}" -p "${port}" -U "${DB_USER}" -d "${db}" \
        -t -A -c "${sql}" 2>&1
}

TEST_PASSED=0
TEST_FAILED=0

header "GaussDB 单机一主二备集群验证"

echo "集群配置:"
echo "  VM: ${VM_IP}"
echo "  主库端口: ${PRIMARY_PORT}"
echo "  备库1端口: ${STANDBY1_PORT}"
echo "  备库2端口: ${STANDBY2_PORT}"
echo ""

# 测试 1: 连接测试
header "测试 1: 数据库连接"

log "测试主库连接 (端口 ${PRIMARY_PORT})..."
RESULT=$(run_sql "${PRIMARY_PORT}" "SELECT 1;" 2>&1)
if echo "$RESULT" | grep -q "^1$"; then
    ok "主库连接成功"
    ((TEST_PASSED++))
else
    err "主库连接失败: $RESULT"
    ((TEST_FAILED++))
fi

log "测试备库1连接 (端口 ${STANDBY1_PORT})..."
RESULT=$(run_sql "${STANDBY1_PORT}" "SELECT 1;" 2>&1)
if echo "$RESULT" | grep -q "^1$"; then
    ok "备库1连接成功"
    ((TEST_PASSED++))
else
    err "备库1连接失败: $RESULT"
    ((TEST_FAILED++))
fi

log "测试备库2连接 (端口 ${STANDBY2_PORT})..."
RESULT=$(run_sql "${STANDBY2_PORT}" "SELECT 1;" 2>&1)
if echo "$RESULT" | grep -q "^1$"; then
    ok "备库2连接成功"
    ((TEST_PASSED++))
else
    err "备库2连接失败: $RESULT"
    ((TEST_FAILED++))
fi

# 测试 2: 主备角色
header "测试 2: 主备角色验证"

log "检查主库角色..."
ROLE=$(run_sql "${PRIMARY_PORT}" "SELECT pg_is_in_recovery();" 2>&1)
if [ "$ROLE" = "f" ]; then
    ok "主库角色正确 (Primary)"
    ((TEST_PASSED++))
else
    err "主库角色错误: $ROLE"
    ((TEST_FAILED++))
fi

log "检查备库1角色..."
ROLE=$(run_sql "${STANDBY1_PORT}" "SELECT pg_is_in_recovery();" 2>&1)
if [ "$ROLE" = "t" ]; then
    ok "备库1角色正确 (Standby)"
    ((TEST_PASSED++))
else
    err "备库1角色错误: $ROLE"
    ((TEST_FAILED++))
fi

log "检查备库2角色..."
ROLE=$(run_sql "${STANDBY2_PORT}" "SELECT pg_is_in_recovery();" 2>&1)
if [ "$ROLE" = "t" ]; then
    ok "备库2角色正确 (Standby)"
    ((TEST_PASSED++))
else
    err "备库2角色错误: $ROLE"
    ((TEST_FAILED++))
fi

# 测试 3: 复制状态
header "测试 3: 流复制状态"

log "查询主库复制状态..."
REPL_STATUS=$(run_sql "${PRIMARY_PORT}" "SELECT application_name, state, sync_state FROM pg_stat_replication ORDER BY application_name;" 2>&1)

if echo "$REPL_STATUS" | grep -q "standby"; then
    ok "检测到复制连接"
    echo "$REPL_STATUS" | while IFS='|' read app state sync; do
        echo "  - $app: 状态=$state, 同步=$sync"
    done
    ((TEST_PASSED++))
else
    err "未检测到复制连接"
    echo "$REPL_STATUS"
    ((TEST_FAILED++))
fi

# 测试 4: 数据同步
header "测试 4: 数据同步验证"

TEST_TABLE="cluster_test_$(date +%s)"
TEST_VALUE="test_$(date +%s)"

log "在主库创建测试表..."
CREATE=$(run_sql "${PRIMARY_PORT}" "CREATE TABLE ${TEST_TABLE} (id INT, data TEXT);" "${DB_NAME}" 2>&1)

if echo "$CREATE" | grep -q "ERROR"; then
    err "创建表失败: $CREATE"
    ((TEST_FAILED++))
else
    ok "测试表创建成功"
    
    log "在主库插入数据..."
    INSERT=$(run_sql "${PRIMARY_PORT}" "INSERT INTO ${TEST_TABLE} VALUES (1, '${TEST_VALUE}');" "${DB_NAME}" 2>&1)
    
    if echo "$INSERT" | grep -q "ERROR"; then
        err "插入数据失败: $INSERT"
        ((TEST_FAILED++))
    else
        ok "数据插入成功"
        
        log "等待复制延迟 (2秒)..."
        sleep 2
        
        log "从备库1读取数据..."
        DATA1=$(run_sql "${STANDBY1_PORT}" "SELECT data FROM ${TEST_TABLE} WHERE id=1;" "${DB_NAME}" 2>&1)
        
        if [ "$DATA1" = "$TEST_VALUE" ]; then
            ok "备库1数据同步成功"
            ((TEST_PASSED++))
        else
            err "备库1数据同步失败: 期望 '$TEST_VALUE', 实际 '$DATA1'"
            ((TEST_FAILED++))
        fi
        
        log "从备库2读取数据..."
        DATA2=$(run_sql "${STANDBY2_PORT}" "SELECT data FROM ${TEST_TABLE} WHERE id=1;" "${DB_NAME}" 2>&1)
        
        if [ "$DATA2" = "$TEST_VALUE" ]; then
            ok "备库2数据同步成功"
            ((TEST_PASSED++))
        else
            err "备库2数据同步失败: 期望 '$TEST_VALUE', 实际 '$DATA2'"
            ((TEST_FAILED++))
        fi
        
        log "清理测试表..."
        run_sql "${PRIMARY_PORT}" "DROP TABLE ${TEST_TABLE};" "${DB_NAME}" >/dev/null 2>&1
    fi
fi

# 测试 5: 只读限制
header "测试 5: 备库只读限制"

log "尝试在备库1写入数据..."
WRITE=$(run_sql "${STANDBY1_PORT}" "CREATE TABLE test_readonly (id INT);" "${DB_NAME}" 2>&1)

if echo "$WRITE" | grep -q "read-only\|recovery"; then
    ok "备库1正确拒绝写操作"
    ((TEST_PASSED++))
else
    err "备库1允许写操作（异常）: $WRITE"
    ((TEST_FAILED++))
fi

log "尝试在备库2写入数据..."
WRITE=$(run_sql "${STANDBY2_PORT}" "CREATE TABLE test_readonly (id INT);" "${DB_NAME}" 2>&1)

if echo "$WRITE" | grep -q "read-only\|recovery"; then
    ok "备库2正确拒绝写操作"
    ((TEST_PASSED++))
else
    err "备库2允许写操作（异常）: $WRITE"
    ((TEST_FAILED++))
fi

# 测试 6: 复制延迟
header "测试 6: 复制延迟检查"

log "查询复制延迟..."
LAG=$(run_sql "${PRIMARY_PORT}" "SELECT application_name, pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) as lag FROM pg_stat_replication ORDER BY application_name;" 2>&1)

if [ -n "$LAG" ]; then
    ok "复制延迟信息:"
    echo "$LAG" | while IFS='|' read app lag; do
        echo "  - $app: 延迟 $lag"
    done
    ((TEST_PASSED++))
else
    warn "无法获取复制延迟信息"
    ((TEST_FAILED++))
fi

# 显示结果
header "测试结果"

TOTAL=$((TEST_PASSED + TEST_FAILED))
if [ $TOTAL -eq 0 ]; then
    PASS_RATE=0
else
    PASS_RATE=$(( TEST_PASSED * 100 / TOTAL ))
fi

echo "总测试数: $TOTAL"
echo -e "${GREEN}通过: $TEST_PASSED${NC}"
echo -e "${RED}失败: $TEST_FAILED${NC}"
echo "通过率: ${PASS_RATE}%"

if [ $TEST_FAILED -eq 0 ]; then
    echo ""
    ok "所有测试通过！GaussDB 单机一主二备集群部署成功。"
    echo ""
    echo "集群信息:"
    echo "  主库: ${VM_IP}:${PRIMARY_PORT}"
    echo "  备库1: ${VM_IP}:${STANDBY1_PORT}"
    echo "  备库2: ${VM_IP}:${STANDBY2_PORT}"
    echo "  数据库: ${DB_NAME}"
    echo "  用户: ${DB_USER}"
    exit 0
else
    echo ""
    err "部分测试失败，请检查集群配置。"
    exit 1
fi
