#!/bin/bash

################################################################################
# Blog Circle GaussDB 数据库测试套件
# 测试数据库连接、CRUD、并发、索引、性能等
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
GAUSSDB_HOST=${GAUSSDB_HOST:-10.211.55.11}
GAUSSDB_PORT=${GAUSSDB_PORT:-5432}
GAUSSDB_USERNAME=${GAUSSDB_USERNAME:-bloguser}
GAUSSDB_PASSWORD=${GAUSSDB_PASSWORD:-blogpass}
GAUSSDB_DATABASE=${GAUSSDB_DATABASE:-blog_db}

TEST_LOG="./test-logs/db-test-$(date +%Y%m%d-%H%M%S).log"
mkdir -p ./test-logs

# 测试统计
TOTAL_DB_TESTS=0
PASSED_DB_TESTS=0
FAILED_DB_TESTS=0

################################################################################
# 工具函数
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_LOG"
    ((PASSED_DB_TESTS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_LOG"
    ((FAILED_DB_TESTS++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$TEST_LOG"
}

run_db_test() {
    ((TOTAL_DB_TESTS++))
    log_info "Testing: $1"
}

# 执行 SQL 查询
execute_sql() {
    local sql="$1"
    local result
    
    result=$(PGPASSWORD="$GAUSSDB_PASSWORD" psql -h "$GAUSSDB_HOST" -p "$GAUSSDB_PORT" \
        -U "$GAUSSDB_USERNAME" -d "$GAUSSDB_DATABASE" \
        -t -A -c "$sql" 2>&1)
    
    echo "$result"
}

################################################################################
# 1. 数据库连接测试
################################################################################

test_db_connection() {
    log_info "=== 1. 数据库连接测试 ==="
    
    run_db_test "基本连接测试"
    local result=$(execute_sql "SELECT 1;")
    if [ "$result" = "1" ]; then
        log_success "数据库连接成功"
    else
        log_error "数据库连接失败: $result"
        return 1
    fi
    
    run_db_test "数据库版本检查"
    local version=$(execute_sql "SELECT version();")
    log_info "数据库版本: $version"
    if echo "$version" | grep -qi "opengauss\|gaussdb"; then
        log_success "GaussDB/openGauss 数据库确认"
    else
        log_warn "数据库类型未确认: $version"
    fi
    
    run_db_test "当前用户权限检查"
    local current_user=$(execute_sql "SELECT current_user;")
    log_info "当前用户: $current_user"
    log_success "用户权限检查完成"
}

################################################################################
# 2. 表结构测试
################################################################################

test_table_structure() {
    log_info "=== 2. 表结构测试 ==="
    
    run_db_test "检查所有表"
    local tables=$(execute_sql "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;")
    log_info "现有表: $tables"
    
    # 检查必需的表
    local required_tables=("users" "posts" "comments" "likes" "friendship" "statistics" "access_logs")
    
    for table in "${required_tables[@]}"; do
        run_db_test "检查表: $table"
        if echo "$tables" | grep -q "^$table$"; then
            log_success "表 $table 存在"
        else
            log_error "表 $table 不存在"
        fi
    done
    
    run_db_test "检查 users 表结构"
    local users_columns=$(execute_sql "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='users' ORDER BY ordinal_position;")
    log_info "users 表字段:\n$users_columns"
    
    if echo "$users_columns" | grep -q "username"; then
        log_success "users 表结构正常"
    else
        log_error "users 表结构异常"
    fi
}

################################################################################
# 3. 索引测试
################################################################################

test_indexes() {
    log_info "=== 3. 索引测试 ==="
    
    run_db_test "检查所有索引"
    local indexes=$(execute_sql "SELECT tablename, indexname FROM pg_indexes WHERE schemaname='public' ORDER BY tablename, indexname;")
    log_info "现有索引:\n$indexes"
    
    # 检查关键索引
    run_db_test "检查 users 表索引"
    if echo "$indexes" | grep -q "users.*username"; then
        log_success "users.username 索引存在"
    else
        log_warn "users.username 索引不存在（建议创建）"
    fi
    
    run_db_test "检查 posts 表索引"
    if echo "$indexes" | grep -q "posts.*author_id"; then
        log_success "posts.author_id 索引存在"
    else
        log_warn "posts.author_id 索引不存在（建议创建）"
    fi
}

################################################################################
# 4. CRUD 操作测试
################################################################################

test_crud_operations() {
    log_info "=== 4. CRUD 操作测试 ==="
    
    local test_username="dbtest_$(date +%s)"
    local test_email="dbtest_$(date +%s)@example.com"
    
    # CREATE
    run_db_test "插入测试数据"
    local insert_result=$(execute_sql "INSERT INTO users (username, password, email, nickname, created_at, updated_at) VALUES ('$test_username', 'test_password_hash', '$test_email', 'DB测试用户', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) RETURNING id;")
    
    if [ -n "$insert_result" ]; then
        log_success "数据插入成功，ID: $insert_result"
        local test_user_id="$insert_result"
    else
        log_error "数据插入失败"
        return 1
    fi
    
    # READ
    run_db_test "查询测试数据"
    local select_result=$(execute_sql "SELECT username FROM users WHERE id=$test_user_id;")
    if [ "$select_result" = "$test_username" ]; then
        log_success "数据查询成功"
    else
        log_error "数据查询失败"
    fi
    
    # UPDATE
    run_db_test "更新测试数据"
    local new_nickname="DB测试用户（已更新）"
    execute_sql "UPDATE users SET nickname='$new_nickname', updated_at=CURRENT_TIMESTAMP WHERE id=$test_user_id;"
    
    local updated_nickname=$(execute_sql "SELECT nickname FROM users WHERE id=$test_user_id;")
    if [ "$updated_nickname" = "$new_nickname" ]; then
        log_success "数据更新成功"
    else
        log_error "数据更新失败"
    fi
    
    # DELETE
    run_db_test "删除测试数据"
    execute_sql "DELETE FROM users WHERE id=$test_user_id;"
    
    local deleted_check=$(execute_sql "SELECT COUNT(*) FROM users WHERE id=$test_user_id;")
    if [ "$deleted_check" = "0" ]; then
        log_success "数据删除成功"
    else
        log_error "数据删除失败"
    fi
}

################################################################################
# 5. 事务测试
################################################################################

test_transactions() {
    log_info "=== 5. 事务测试 ==="
    
    run_db_test "事务回滚测试"
    
    local test_username="txtest_$(date +%s)"
    
    # 开始事务并回滚
    local tx_result=$(PGPASSWORD="$GAUSSDB_PASSWORD" psql -h "$GAUSSDB_HOST" -p "$GAUSSDB_PORT" \
        -U "$GAUSSDB_USERNAME" -d "$GAUSSDB_DATABASE" -t -A <<EOF
BEGIN;
INSERT INTO users (username, password, email, created_at, updated_at) 
VALUES ('$test_username', 'test', 'tx@test.com', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
ROLLBACK;
SELECT COUNT(*) FROM users WHERE username='$test_username';
EOF
)
    
    if echo "$tx_result" | grep -q "^0$"; then
        log_success "事务回滚成功"
    else
        log_error "事务回滚失败"
    fi
    
    run_db_test "事务提交测试"
    
    local test_username2="txtest2_$(date +%s)"
    
    # 开始事务并提交
    local tx_result2=$(PGPASSWORD="$GAUSSDB_PASSWORD" psql -h "$GAUSSDB_HOST" -p "$GAUSSDB_PORT" \
        -U "$GAUSSDB_USERNAME" -d "$GAUSSDB_DATABASE" -t -A <<EOF
BEGIN;
INSERT INTO users (username, password, email, created_at, updated_at) 
VALUES ('$test_username2', 'test', 'tx2@test.com', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) RETURNING id;
COMMIT;
EOF
)
    
    if [ -n "$tx_result2" ]; then
        log_success "事务提交成功"
        # 清理测试数据
        execute_sql "DELETE FROM users WHERE username='$test_username2';"
    else
        log_error "事务提交失败"
    fi
}

################################################################################
# 6. 约束测试
################################################################################

test_constraints() {
    log_info "=== 6. 约束测试 ==="
    
    run_db_test "唯一约束测试"
    local test_username="constraint_test_$(date +%s)"
    
    # 插入第一条数据
    local first_insert=$(execute_sql "INSERT INTO users (username, password, email, created_at, updated_at) VALUES ('$test_username', 'test', 'c1@test.com', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) RETURNING id;" 2>&1)
    
    if [ -n "$first_insert" ] && ! echo "$first_insert" | grep -qi "error"; then
        local user_id="$first_insert"
        
        # 尝试插入重复用户名
        local duplicate_insert=$(execute_sql "INSERT INTO users (username, password, email, created_at, updated_at) VALUES ('$test_username', 'test', 'c2@test.com', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);" 2>&1)
        
        if echo "$duplicate_insert" | grep -qi "duplicate\|unique\|violation"; then
            log_success "唯一约束生效"
        else
            log_error "唯一约束未生效"
        fi
        
        # 清理
        execute_sql "DELETE FROM users WHERE id=$user_id;"
    else
        log_warn "无法测试唯一约束（插入失败）"
    fi
    
    run_db_test "外键约束测试"
    # 尝试插入无效的 author_id
    local fk_test=$(execute_sql "INSERT INTO posts (title, content, author_id, created_at, updated_at) VALUES ('Test', 'Content', 999999, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);" 2>&1)
    
    if echo "$fk_test" | grep -qi "foreign key\|violates"; then
        log_success "外键约束生效"
    else
        log_warn "外键约束未生效或不存在"
    fi
}

################################################################################
# 7. 性能测试
################################################################################

test_performance() {
    log_info "=== 7. 性能测试 ==="
    
    run_db_test "查询性能测试"
    
    # 测试简单查询
    local start_time=$(date +%s%N)
    execute_sql "SELECT COUNT(*) FROM users;" > /dev/null
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    log_info "COUNT(*) 查询耗时: ${duration}ms"
    if [ $duration -lt 1000 ]; then
        log_success "查询性能正常 (< 1s)"
    else
        log_warn "查询性能较慢 (>= 1s)"
    fi
    
    # 测试复杂查询
    run_db_test "复杂查询性能测试"
    start_time=$(date +%s%N)
    execute_sql "SELECT u.username, COUNT(p.id) as post_count FROM users u LEFT JOIN posts p ON u.id = p.author_id GROUP BY u.id, u.username LIMIT 10;" > /dev/null
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    
    log_info "JOIN + GROUP BY 查询耗时: ${duration}ms"
    if [ $duration -lt 2000 ]; then
        log_success "复杂查询性能正常 (< 2s)"
    else
        log_warn "复杂查询性能较慢 (>= 2s)"
    fi
}

################################################################################
# 8. 数据统计
################################################################################

test_data_statistics() {
    log_info "=== 8. 数据统计 ==="
    
    run_db_test "统计各表数据量"
    
    local tables=("users" "posts" "comments" "likes" "friendship" "statistics" "access_logs")
    
    for table in "${tables[@]}"; do
        local count=$(execute_sql "SELECT COUNT(*) FROM $table;" 2>&1)
        if [[ "$count" =~ ^[0-9]+$ ]]; then
            log_info "$table 表记录数: $count"
            log_success "$table 表统计完成"
        else
            log_warn "$table 表统计失败或不存在"
        fi
    done
}

################################################################################
# 9. 慢查询检测
################################################################################

test_slow_queries() {
    log_info "=== 9. 慢查询检测 ==="
    
    run_db_test "检查慢查询日志配置"
    local log_min_duration=$(execute_sql "SHOW log_min_duration_statement;" 2>&1)
    log_info "慢查询阈值: $log_min_duration"
    
    if [ "$log_min_duration" != "-1" ]; then
        log_success "慢查询日志已启用"
    else
        log_warn "慢查询日志未启用"
    fi
}

################################################################################
# 生成测试报告
################################################################################

generate_db_report() {
    log_info "=== 数据库测试报告 ==="
    echo ""
    echo "========================================" | tee -a "$TEST_LOG"
    echo "  Blog Circle 数据库测试报告" | tee -a "$TEST_LOG"
    echo "========================================" | tee -a "$TEST_LOG"
    echo "测试时间: $(date)" | tee -a "$TEST_LOG"
    echo "数据库地址: $GAUSSDB_HOST:$GAUSSDB_PORT" | tee -a "$TEST_LOG"
    echo "数据库名称: $GAUSSDB_DATABASE" | tee -a "$TEST_LOG"
    echo "总测试数: $TOTAL_DB_TESTS" | tee -a "$TEST_LOG"
    echo -e "${GREEN}通过: $PASSED_DB_TESTS${NC}" | tee -a "$TEST_LOG"
    echo -e "${RED}失败: $FAILED_DB_TESTS${NC}" | tee -a "$TEST_LOG"
    
    if [ $TOTAL_DB_TESTS -gt 0 ]; then
        local pass_rate=$(awk "BEGIN {printf \"%.2f\", ($PASSED_DB_TESTS/$TOTAL_DB_TESTS)*100}")
        echo "通过率: ${pass_rate}%" | tee -a "$TEST_LOG"
    fi
    
    echo "========================================" | tee -a "$TEST_LOG"
    echo ""
    echo "详细日志: $TEST_LOG"
    
    if [ $FAILED_DB_TESTS -eq 0 ]; then
        log_success "所有数据库测试通过！"
        return 0
    else
        log_error "存在失败的数据库测试，请查看日志"
        return 1
    fi
}

################################################################################
# 主函数
################################################################################

main() {
    echo "========================================="
    echo "  Blog Circle 数据库测试套件"
    echo "========================================="
    echo ""
    
    log_info "数据库地址: $GAUSSDB_HOST:$GAUSSDB_PORT"
    log_info "数据库名称: $GAUSSDB_DATABASE"
    log_info "测试日志: $TEST_LOG"
    echo ""
    
    # 检查 psql 命令
    if ! command -v psql &> /dev/null; then
        log_error "psql 命令未找到，请安装 PostgreSQL 客户端"
        exit 1
    fi
    
    # 执行测试
    test_db_connection
    test_table_structure
    test_indexes
    test_crud_operations
    test_transactions
    test_constraints
    test_performance
    test_data_statistics
    test_slow_queries
    
    # 生成报告
    generate_db_report
}

# 运行主函数
main "$@"
