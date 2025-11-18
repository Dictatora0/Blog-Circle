#!/bin/bash

################################################################################
# Blog Circle 自动化测试套件
# 功能：容器启动、健康检查、API测试、数据库测试、性能测试
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试结果统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 日志文件
LOG_DIR="./test-logs"
mkdir -p "$LOG_DIR"
TEST_LOG="$LOG_DIR/test-$(date +%Y%m%d-%H%M%S).log"

################################################################################
# 工具函数
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_LOG"
    ((PASSED_TESTS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_LOG"
    ((FAILED_TESTS++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$TEST_LOG"
}

run_test() {
    ((TOTAL_TESTS++))
    local test_name="$1"
    log_info "Running: $test_name"
}

################################################################################
# 环境配置
################################################################################

setup_environment() {
    log_info "=== 环境配置 ==="
    
    # GaussDB 配置
    export GAUSSDB_HOST=${GAUSSDB_HOST:-10.211.55.11}
    export GAUSSDB_PORT=${GAUSSDB_PORT:-5432}
    export GAUSSDB_USERNAME=${GAUSSDB_USERNAME:-bloguser}
    export GAUSSDB_PASSWORD=${GAUSSDB_PASSWORD:-blogpass}
    
    # 后端配置
    export BACKEND_URL=${BACKEND_URL:-http://localhost:8081}
    export FRONTEND_URL=${FRONTEND_URL:-http://localhost:8080}
    
    log_info "GAUSSDB_HOST: $GAUSSDB_HOST"
    log_info "GAUSSDB_PORT: $GAUSSDB_PORT"
    log_info "BACKEND_URL: $BACKEND_URL"
    log_info "FRONTEND_URL: $FRONTEND_URL"
}

################################################################################
# 1. 容器启动测试
################################################################################

test_docker_compose_start() {
    log_info "=== 1. 容器启动测试 ==="
    
    run_test "Docker Compose 配置验证"
    if docker compose -f docker-compose-gaussdb.yml config > /dev/null 2>&1; then
        log_success "Docker Compose 配置文件有效"
    else
        log_error "Docker Compose 配置文件无效"
        return 1
    fi
    
    run_test "启动容器集群"
    log_info "启动 docker-compose-gaussdb.yml..."
    if docker compose -f docker-compose-gaussdb.yml up -d 2>&1 | tee -a "$TEST_LOG"; then
        log_success "容器集群启动成功"
    else
        log_error "容器集群启动失败"
        return 1
    fi
    
    # 等待容器启动
    log_info "等待容器启动（30秒）..."
    sleep 30
}

################################################################################
# 2. 容器健康检查
################################################################################

test_container_health() {
    log_info "=== 2. 容器健康检查 ==="
    
    run_test "检查容器状态"
    docker compose -f docker-compose-gaussdb.yml ps | tee -a "$TEST_LOG"
    
    # 检查后端容器
    run_test "后端容器健康检查"
    if docker compose -f docker-compose-gaussdb.yml ps | grep -q "blogcircle-backend.*Up"; then
        log_success "后端容器运行正常"
    else
        log_error "后端容器未运行"
        docker compose -f docker-compose-gaussdb.yml logs backend | tail -50 | tee -a "$TEST_LOG"
    fi
    
    # 检查前端容器
    run_test "前端容器健康检查"
    if docker compose -f docker-compose-gaussdb.yml ps | grep -q "blogcircle-frontend.*Up"; then
        log_success "前端容器运行正常"
    else
        log_error "前端容器未运行"
        docker compose -f docker-compose-gaussdb.yml logs frontend | tail -50 | tee -a "$TEST_LOG"
    fi
    
    # 检查 Spark Master
    run_test "Spark Master 容器健康检查"
    if docker compose -f docker-compose-gaussdb.yml ps | grep -q "blogcircle-spark-master.*Up"; then
        log_success "Spark Master 容器运行正常"
    else
        log_warn "Spark Master 容器未运行（可能未启动或镜像拉取失败）"
    fi
    
    # 检查 Spark Worker
    run_test "Spark Worker 容器健康检查"
    if docker compose -f docker-compose-gaussdb.yml ps | grep -q "blogcircle-spark-worker.*Up"; then
        log_success "Spark Worker 容器运行正常"
    else
        log_warn "Spark Worker 容器未运行（可能未启动或镜像拉取失败）"
    fi
}

################################################################################
# 3. 后端 API 测试
################################################################################

# 全局变量存储 token
AUTH_TOKEN=""

test_backend_api() {
    log_info "=== 3. 后端 API 测试 ==="
    
    # 等待后端完全启动
    run_test "等待后端服务就绪"
    local max_retries=30
    local retry=0
    while [ $retry -lt $max_retries ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/actuator/health" | grep -q "200"; then
            log_success "后端服务已就绪"
            break
        fi
        ((retry++))
        sleep 2
    done
    
    if [ $retry -eq $max_retries ]; then
        log_error "后端服务启动超时"
        return 1
    fi
    
    # 测试用户注册
    run_test "用户注册 API"
    local register_response=$(curl -s -X POST "$BACKEND_URL/api/auth/register" \
        -H "Content-Type: application/json" \
        -d '{
            "username": "testuser_'$(date +%s)'",
            "password": "Test@123",
            "email": "test'$(date +%s)'@example.com",
            "nickname": "测试用户"
        }')
    
    if echo "$register_response" | grep -q '"code":200'; then
        log_success "用户注册成功"
    else
        log_error "用户注册失败: $register_response"
    fi
    
    # 测试用户登录
    run_test "用户登录 API"
    local login_response=$(curl -s -X POST "$BACKEND_URL/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{
            "username": "testuser",
            "password": "Test@123"
        }')
    
    if echo "$login_response" | grep -q '"code":200'; then
        log_success "用户登录成功"
        AUTH_TOKEN=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        log_info "获取到 Token: ${AUTH_TOKEN:0:20}..."
    else
        log_warn "用户登录失败（可能用户不存在，需先注册）: $login_response"
    fi
    
    # 测试文章列表
    run_test "文章列表 API"
    local posts_response=$(curl -s "$BACKEND_URL/api/posts/list?page=1&size=10")
    if echo "$posts_response" | grep -q '"code":200'; then
        log_success "文章列表获取成功"
    else
        log_error "文章列表获取失败: $posts_response"
    fi
    
    # 测试统计接口（无需认证）
    run_test "统计汇总 API"
    local stats_response=$(curl -s "$BACKEND_URL/api/stats")
    if echo "$stats_response" | grep -q '"code":200'; then
        log_success "统计汇总获取成功"
    else
        log_error "统计汇总获取失败: $stats_response"
    fi
    
    # 测试聚合统计
    run_test "聚合统计 API"
    local agg_response=$(curl -s "$BACKEND_URL/api/stats/aggregated")
    if echo "$agg_response" | grep -q '"code":200'; then
        log_success "聚合统计获取成功"
    else
        log_error "聚合统计获取失败: $agg_response"
    fi
}

################################################################################
# 4. GaussDB 数据库测试
################################################################################

test_gaussdb_connection() {
    log_info "=== 4. GaussDB 数据库测试 ==="
    
    run_test "GaussDB 连接测试"
    # 尝试通过后端容器连接 GaussDB
    local db_test=$(docker compose -f docker-compose-gaussdb.yml exec -T backend \
        sh -c "echo 'SELECT 1;' | timeout 5 psql -h $GAUSSDB_HOST -p $GAUSSDB_PORT -U $GAUSSDB_USERNAME -d blog_db" 2>&1 || true)
    
    if echo "$db_test" | grep -q "1"; then
        log_success "GaussDB 连接成功"
    else
        log_warn "GaussDB 连接测试失败（可能需要配置密码或网络）"
        log_info "测试输出: $db_test"
    fi
    
    run_test "检查数据库表结构"
    local tables_test=$(docker compose -f docker-compose-gaussdb.yml exec -T backend \
        sh -c "echo '\dt' | timeout 5 psql -h $GAUSSDB_HOST -p $GAUSSDB_PORT -U $GAUSSDB_USERNAME -d blog_db" 2>&1 || true)
    
    if echo "$tables_test" | grep -q "users\|posts\|comments"; then
        log_success "数据库表结构正常"
    else
        log_warn "数据库表结构检查失败"
    fi
}

################################################################################
# 5. Spark 作业测试
################################################################################

test_spark_job() {
    log_info "=== 5. Spark 作业测试 ==="
    
    # 检查 Spark Master 是否运行
    if ! docker compose -f docker-compose-gaussdb.yml ps | grep -q "blogcircle-spark-master.*Up"; then
        log_warn "Spark Master 未运行，跳过 Spark 测试"
        return 0
    fi
    
    run_test "Spark Master UI 可访问性"
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8888" | grep -q "200"; then
        log_success "Spark Master UI 可访问"
    else
        log_warn "Spark Master UI 不可访问"
    fi
    
    run_test "触发统计分析任务"
    if [ -n "$AUTH_TOKEN" ]; then
        local analyze_response=$(curl -s -X POST "$BACKEND_URL/api/stats/analyze" \
            -H "Authorization: Bearer $AUTH_TOKEN")
        
        if echo "$analyze_response" | grep -q '"code":200'; then
            log_success "统计分析任务触发成功"
        else
            log_warn "统计分析任务触发失败: $analyze_response"
        fi
    else
        log_warn "无 Token，跳过统计分析测试"
    fi
}

################################################################################
# 6. 前端可访问性测试
################################################################################

test_frontend_accessibility() {
    log_info "=== 6. 前端可访问性测试 ==="
    
    run_test "前端首页可访问性"
    local frontend_status=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL")
    if [ "$frontend_status" = "200" ]; then
        log_success "前端首页可访问 (HTTP $frontend_status)"
    else
        log_error "前端首页不可访问 (HTTP $frontend_status)"
    fi
    
    run_test "前端静态资源检查"
    if curl -s "$FRONTEND_URL" | grep -q "<!DOCTYPE html>"; then
        log_success "前端 HTML 正常返回"
    else
        log_error "前端 HTML 返回异常"
    fi
}

################################################################################
# 7. 性能与资源测试
################################################################################

test_performance() {
    log_info "=== 7. 性能与资源测试 ==="
    
    run_test "容器资源使用情况"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tee -a "$TEST_LOG"
    log_success "资源使用情况已记录"
    
    run_test "后端响应时间测试"
    local response_time=$(curl -s -o /dev/null -w "%{time_total}" "$BACKEND_URL/api/posts/list?page=1&size=10")
    log_info "文章列表 API 响应时间: ${response_time}s"
    
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        log_success "响应时间正常 (< 2s)"
    else
        log_warn "响应时间较慢 (>= 2s)"
    fi
}

################################################################################
# 8. 日志检查
################################################################################

test_logs() {
    log_info "=== 8. 容器日志检查 ==="
    
    run_test "后端日志错误检查"
    local backend_errors=$(docker compose -f docker-compose-gaussdb.yml logs backend 2>&1 | grep -i "error\|exception" | wc -l)
    if [ "$backend_errors" -eq 0 ]; then
        log_success "后端日志无错误"
    else
        log_warn "后端日志发现 $backend_errors 条错误/异常"
        docker compose -f docker-compose-gaussdb.yml logs backend | grep -i "error\|exception" | tail -10 | tee -a "$TEST_LOG"
    fi
    
    run_test "前端日志错误检查"
    local frontend_errors=$(docker compose -f docker-compose-gaussdb.yml logs frontend 2>&1 | grep -i "error" | wc -l)
    if [ "$frontend_errors" -eq 0 ]; then
        log_success "前端日志无错误"
    else
        log_warn "前端日志发现 $frontend_errors 条错误"
    fi
}

################################################################################
# 测试报告生成
################################################################################

generate_report() {
    log_info "=== 测试报告 ==="
    echo ""
    echo "========================================" | tee -a "$TEST_LOG"
    echo "  Blog Circle 自动化测试报告" | tee -a "$TEST_LOG"
    echo "========================================" | tee -a "$TEST_LOG"
    echo "测试时间: $(date)" | tee -a "$TEST_LOG"
    echo "总测试数: $TOTAL_TESTS" | tee -a "$TEST_LOG"
    echo -e "${GREEN}通过: $PASSED_TESTS${NC}" | tee -a "$TEST_LOG"
    echo -e "${RED}失败: $FAILED_TESTS${NC}" | tee -a "$TEST_LOG"
    echo "通过率: $(awk "BEGIN {printf \"%.2f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")%" | tee -a "$TEST_LOG"
    echo "========================================" | tee -a "$TEST_LOG"
    echo ""
    echo "详细日志: $TEST_LOG"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "所有测试通过！"
        return 0
    else
        log_error "存在失败的测试，请查看日志"
        return 1
    fi
}

################################################################################
# 清理函数
################################################################################

cleanup() {
    log_info "=== 清理测试环境 ==="
    read -p "是否停止并清理容器？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose -f docker-compose-gaussdb.yml down
        log_info "容器已停止"
    fi
}

################################################################################
# 主函数
################################################################################

main() {
    echo "========================================="
    echo "  Blog Circle 自动化测试套件"
    echo "========================================="
    echo ""
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装或不可用"
        exit 1
    fi
    
    # 设置环境
    setup_environment
    
    # 执行测试
    test_docker_compose_start
    test_container_health
    test_backend_api
    test_gaussdb_connection
    test_spark_job
    test_frontend_accessibility
    test_performance
    test_logs
    
    # 生成报告
    generate_report
    
    # 清理
    trap cleanup EXIT
}

# 运行主函数
main "$@"
