#!/bin/bash

# 简化的 PostgreSQL 测试脚本
# 直接使用密码连接，不需要 SSH

set -e

DOCKER_CMD="/usr/local/bin/docker"
PG_HOST="10.211.55.11"
PG_PORT="5432"
PG_USER="bloguser"
PG_PASSWORD="747599qw@"
PG_DB="blog_db"

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
    local sql="$1"
    $DOCKER_CMD run --rm -e PGPASSWORD="${PG_PASSWORD}" postgres:15-alpine \
        psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" \
        -t -A -c "${sql}" 2>&1
}

TEST_PASSED=0
TEST_FAILED=0

# 测试数据库连接
test_connection() {
    header "测试数据库连接"
    
    log "连接到 ${PG_HOST}:${PG_PORT}..."
    RESULT=$(run_sql "SELECT 'OK' as status, version();")
    
    if echo "$RESULT" | grep -q "OK"; then
        ok "数据库连接成功"
        echo "$RESULT" | grep "version"
        ((TEST_PASSED++))
    else
        err "数据库连接失败: $RESULT"
        ((TEST_FAILED++))
        return 1
    fi
}

# 测试数据库表
test_tables() {
    header "测试数据库表"
    
    log "检查表是否存在..."
    TABLES=$(run_sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';")
    
    if [ "$TABLES" -gt 0 ]; then
        ok "数据库包含 $TABLES 个表"
        ((TEST_PASSED++))
    else
        warn "数据库没有表"
        ((TEST_FAILED++))
    fi
    
    log "列出所有表..."
    run_sql "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;" | while read table; do
        echo "  - $table"
    done
}

# 测试数据统计
test_data() {
    header "测试数据统计"
    
    log "统计各表数据量..."
    
    for table in users posts comments likes access_logs statistics; do
        COUNT=$(run_sql "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
        echo "  $table: $COUNT 条记录"
    done
    
    ((TEST_PASSED++))
}

# 测试 CRUD 操作
test_crud() {
    header "测试 CRUD 操作"
    
    TEST_TABLE="test_$(date +%s)"
    
    log "创建测试表..."
    CREATE=$(run_sql "CREATE TABLE $TEST_TABLE (id SERIAL PRIMARY KEY, data VARCHAR(100), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);" 2>&1)
    
    if echo "$CREATE" | grep -q "ERROR"; then
        err "创建表失败: $CREATE"
        ((TEST_FAILED++))
        return 1
    fi
    ok "创建表成功"
    
    log "插入测试数据..."
    INSERT=$(run_sql "INSERT INTO $TEST_TABLE (data) VALUES ('test_data_1'), ('test_data_2'), ('test_data_3');" 2>&1)
    
    if echo "$INSERT" | grep -q "ERROR"; then
        err "插入数据失败: $INSERT"
        ((TEST_FAILED++))
        return 1
    fi
    ok "插入数据成功"
    
    log "查询数据..."
    SELECT=$(run_sql "SELECT COUNT(*) FROM $TEST_TABLE;")
    
    if [ "$SELECT" = "3" ]; then
        ok "查询数据正确 (3 条记录)"
    else
        err "查询数据错误: 期望 3，实际 $SELECT"
        ((TEST_FAILED++))
        return 1
    fi
    
    log "更新数据..."
    UPDATE=$(run_sql "UPDATE $TEST_TABLE SET data='updated' WHERE id=1;" 2>&1)
    
    if echo "$UPDATE" | grep -q "ERROR"; then
        err "更新数据失败: $UPDATE"
        ((TEST_FAILED++))
        return 1
    fi
    ok "更新数据成功"
    
    log "删除数据..."
    DELETE=$(run_sql "DELETE FROM $TEST_TABLE WHERE id=1;" 2>&1)
    
    if echo "$DELETE" | grep -q "ERROR"; then
        err "删除数据失败: $DELETE"
        ((TEST_FAILED++))
        return 1
    fi
    ok "删除数据成功"
    
    log "清理测试表..."
    run_sql "DROP TABLE $TEST_TABLE;" >/dev/null 2>&1
    
    ((TEST_PASSED++))
}

# 测试性能
test_performance() {
    header "测试查询性能"
    
    log "执行简单查询..."
    START=$(date +%s%N)
    run_sql "SELECT COUNT(*) FROM posts;" >/dev/null
    END=$(date +%s%N)
    
    DURATION=$(( (END - START) / 1000000 ))
    ok "查询耗时: ${DURATION}ms"
    
    ((TEST_PASSED++))
}

# 测试连接数
test_connections() {
    header "测试数据库连接"
    
    log "检查当前连接数..."
    CONN_COUNT=$(run_sql "SELECT COUNT(*) FROM pg_stat_activity;")
    
    ok "当前连接数: $CONN_COUNT"
    
    log "检查最大连接数..."
    MAX_CONN=$(run_sql "SHOW max_connections;")
    
    ok "最大连接数: $MAX_CONN"
    
    ((TEST_PASSED++))
}

# 显示结果
show_results() {
    header "测试结果"
    
    TOTAL=$((TEST_PASSED + TEST_FAILED))
    PASS_RATE=$(( TEST_PASSED * 100 / TOTAL ))
    
    echo "总测试数: $TOTAL"
    echo -e "${GREEN}通过: $TEST_PASSED${NC}"
    echo -e "${RED}失败: $TEST_FAILED${NC}"
    echo "通过率: ${PASS_RATE}%"
    
    if [ $TEST_FAILED -eq 0 ]; then
        echo ""
        ok "所有测试通过！PostgreSQL 运行正常。"
    else
        echo ""
        warn "部分测试失败，请检查日志。"
    fi
}

# 主测试流程
main() {
    header "PostgreSQL 数据库测试"
    
    log "目标数据库: ${PG_HOST}:${PG_PORT}/${PG_DB}"
    log "用户: ${PG_USER}"
    echo ""
    
    test_connection || exit 1
    test_tables
    test_data
    test_crud
    test_performance
    test_connections
    
    show_results
}

# 执行测试
main
