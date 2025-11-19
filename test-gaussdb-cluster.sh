#!/bin/bash

# GaussDB 一主二备集群测试脚本
# 测试主备复制、数据同步、故障切换等功能

set -e

DOCKER_CMD="/usr/local/bin/docker"

# 集群配置
PRIMARY_IP="10.211.55.11"
STANDBY1_IP="10.211.55.14"
STANDBY2_IP="10.211.55.13"
DB_PORT="5432"
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

# 执行 SQL 的函数
run_sql() {
    local host="$1"
    local sql="$2"
    $DOCKER_CMD run --rm -e PGPASSWORD="${DB_PASSWORD}" postgres:15-alpine \
        psql -h "${host}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
        -t -A -c "${sql}" 2>&1
}

TEST_PASSED=0
TEST_FAILED=0

# 测试节点连接
test_node_connection() {
    local node_name="$1"
    local node_ip="$2"
    
    log "测试 ${node_name} (${node_ip}) 连接..."
    RESULT=$(run_sql "${node_ip}" "SELECT 1;" 2>&1)
    
    if echo "$RESULT" | grep -q "^1$"; then
        ok "${node_name} 连接成功"
        ((TEST_PASSED++))
        return 0
    else
        err "${node_name} 连接失败: $RESULT"
        ((TEST_FAILED++))
        return 1
    fi
}

# 测试主备角色
test_replication_role() {
    header "测试主备角色"
    
    log "检查主库角色..."
    PRIMARY_ROLE=$(run_sql "${PRIMARY_IP}" "SELECT pg_is_in_recovery();" 2>&1)
    if [ "$PRIMARY_ROLE" = "f" ]; then
        ok "主库角色正确 (Primary)"
        ((TEST_PASSED++))
    else
        err "主库角色错误: $PRIMARY_ROLE"
        ((TEST_FAILED++))
    fi
    
    log "检查备库1角色..."
    STANDBY1_ROLE=$(run_sql "${STANDBY1_IP}" "SELECT pg_is_in_recovery();" 2>&1)
    if [ "$STANDBY1_ROLE" = "t" ]; then
        ok "备库1角色正确 (Standby)"
        ((TEST_PASSED++))
    else
        err "备库1角色错误: $STANDBY1_ROLE"
        ((TEST_FAILED++))
    fi
    
    log "检查备库2角色..."
    STANDBY2_ROLE=$(run_sql "${STANDBY2_IP}" "SELECT pg_is_in_recovery();" 2>&1)
    if [ "$STANDBY2_ROLE" = "t" ]; then
        ok "备库2角色正确 (Standby)"
        ((TEST_PASSED++))
    else
        err "备库2角色错误: $STANDBY2_ROLE"
        ((TEST_FAILED++))
    fi
}

# 测试主备复制状态
test_replication_status() {
    header "测试主备复制状态"
    
    log "查询主库复制状态..."
    REPL_STATUS=$(run_sql "${PRIMARY_IP}" "SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;" 2>&1)
    
    if echo "$REPL_STATUS" | grep -q "streaming"; then
        ok "主备复制正常运行"
        echo "$REPL_STATUS" | while IFS='|' read app addr state sync; do
            echo "  - 应用: $app, 地址: $addr, 状态: $state, 同步: $sync"
        done
        ((TEST_PASSED++))
    else
        warn "未检测到复制连接"
        echo "$REPL_STATUS"
        ((TEST_FAILED++))
    fi
}

# 测试数据同步
test_data_sync() {
    header "测试数据同步"
    
    TEST_TABLE="cluster_test_$(date +%s)"
    TEST_VALUE="test_$(date +%s)"
    
    log "在主库创建测试表..."
    CREATE_RESULT=$(run_sql "${PRIMARY_IP}" "CREATE TABLE ${TEST_TABLE} (id INT PRIMARY KEY, data VARCHAR(100));" 2>&1)
    
    if echo "$CREATE_RESULT" | grep -q "ERROR"; then
        err "创建表失败: $CREATE_RESULT"
        ((TEST_FAILED++))
        return 1
    fi
    ok "测试表创建成功"
    
    log "在主库插入数据..."
    INSERT_RESULT=$(run_sql "${PRIMARY_IP}" "INSERT INTO ${TEST_TABLE} VALUES (1, '${TEST_VALUE}');" 2>&1)
    
    if echo "$INSERT_RESULT" | grep -q "ERROR"; then
        err "插入数据失败: $INSERT_RESULT"
        ((TEST_FAILED++))
        return 1
    fi
    ok "数据插入成功"
    
    log "等待复制延迟..."
    sleep 2
    
    log "从备库1读取数据..."
    STANDBY1_DATA=$(run_sql "${STANDBY1_IP}" "SELECT data FROM ${TEST_TABLE} WHERE id=1;" 2>&1)
    
    if [ "$STANDBY1_DATA" = "$TEST_VALUE" ]; then
        ok "备库1数据同步成功"
        ((TEST_PASSED++))
    else
        err "备库1数据同步失败: 期望 '$TEST_VALUE', 实际 '$STANDBY1_DATA'"
        ((TEST_FAILED++))
    fi
    
    log "从备库2读取数据..."
    STANDBY2_DATA=$(run_sql "${STANDBY2_IP}" "SELECT data FROM ${TEST_TABLE} WHERE id=1;" 2>&1)
    
    if [ "$STANDBY2_DATA" = "$TEST_VALUE" ]; then
        ok "备库2数据同步成功"
        ((TEST_PASSED++))
    else
        err "备库2数据同步失败: 期望 '$TEST_VALUE', 实际 '$STANDBY2_DATA'"
        ((TEST_FAILED++))
    fi
    
    log "清理测试表..."
    run_sql "${PRIMARY_IP}" "DROP TABLE ${TEST_TABLE};" >/dev/null 2>&1
}

# 测试复制延迟
test_replication_lag() {
    header "测试复制延迟"
    
    log "查询复制延迟..."
    LAG_INFO=$(run_sql "${PRIMARY_IP}" "SELECT application_name, client_addr, pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) as lag FROM pg_stat_replication;" 2>&1)
    
    if [ -n "$LAG_INFO" ]; then
        ok "复制延迟信息:"
        echo "$LAG_INFO" | while IFS='|' read app addr lag; do
            echo "  - $app ($addr): 延迟 $lag"
        done
        ((TEST_PASSED++))
    else
        warn "无法获取复制延迟信息"
        ((TEST_FAILED++))
    fi
}

# 测试只读限制
test_readonly_constraint() {
    header "测试备库只读限制"
    
    log "尝试在备库1写入数据..."
    WRITE_RESULT=$(run_sql "${STANDBY1_IP}" "CREATE TABLE test_readonly (id INT);" 2>&1)
    
    if echo "$WRITE_RESULT" | grep -q "read-only\|recovery"; then
        ok "备库1正确拒绝写操作"
        ((TEST_PASSED++))
    else
        err "备库1允许写操作（异常）: $WRITE_RESULT"
        ((TEST_FAILED++))
    fi
    
    log "尝试在备库2写入数据..."
    WRITE_RESULT=$(run_sql "${STANDBY2_IP}" "CREATE TABLE test_readonly (id INT);" 2>&1)
    
    if echo "$WRITE_RESULT" | grep -q "read-only\|recovery"; then
        ok "备库2正确拒绝写操作"
        ((TEST_PASSED++))
    else
        err "备库2允许写操作（异常）: $WRITE_RESULT"
        ((TEST_FAILED++))
    fi
}

# 显示集群信息
show_cluster_info() {
    header "集群信息"
    
    echo "节点配置:"
    echo "  主库:  ${PRIMARY_IP}:${DB_PORT}"
    echo "  备库1: ${STANDBY1_IP}:${DB_PORT}"
    echo "  备库2: ${STANDBY2_IP}:${DB_PORT}"
    echo ""
    
    log "主库版本信息..."
    VERSION=$(run_sql "${PRIMARY_IP}" "SELECT version();" 2>&1 | head -1)
    echo "  $VERSION"
}

# 显示结果
show_results() {
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
        ok "所有测试通过！GaussDB 一主二备集群部署成功。"
        return 0
    else
        echo ""
        err "部分测试失败，请检查集群配置。"
        return 1
    fi
}

# 主测试流程
main() {
    header "GaussDB 一主二备集群测试"
    
    show_cluster_info
    
    # 1. 测试节点连接
    header "测试节点连接"
    test_node_connection "主库" "${PRIMARY_IP}" || exit 1
    test_node_connection "备库1" "${STANDBY1_IP}" || exit 1
    test_node_connection "备库2" "${STANDBY2_IP}" || exit 1
    
    # 2. 测试主备角色
    test_replication_role
    
    # 3. 测试复制状态
    test_replication_status
    
    # 4. 测试数据同步
    test_data_sync
    
    # 5. 测试复制延迟
    test_replication_lag
    
    # 6. 测试只读限制
    test_readonly_constraint
    
    # 7. 显示结果
    show_results
}

# 执行测试
main
