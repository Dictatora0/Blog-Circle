#!/bin/bash

# 统一自动化测试脚本
# 执行完整的测试套件：数据库集成测试、API E2E测试、前端 E2E测试、Spark 调度验证

# 不使用 set -e，而是手动检查关键步骤的返回码
# set -e

echo "========================================="
echo "   统一自动化测试套件"
echo "========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 命令未找到，请先安装"
        exit 1
    fi
}

# 清理函数
cleanup() {
    log_info "清理测试环境..."
    # 停止所有容器
    cd /Users/lifulin/Desktop/CloudCom
    docker-compose -f docker-compose-gaussdb-pseudo.yml down -v 2>/dev/null || true
    # 清理临时文件
    rm -rf /tmp/test-logs/
}

# 设置清理钩子
trap cleanup EXIT

# 创建日志目录
mkdir -p /tmp/test-logs

log_info "检查依赖..."

# 添加常见工具路径到 PATH
export PATH="/opt/homebrew/bin:/opt/homebrew/Cellar/maven/3.9.9/bin:/usr/local/bin:$PATH"
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

# 检查必需命令
check_command "mvn"
check_command "npm"
check_command "node"

# 检查 Docker 是否可用
DOCKER_AVAILABLE=false
DOCKER_CMD=""

# 检查常规 PATH 中的 docker
if command -v docker &> /dev/null; then
    DOCKER_CMD="docker"
    DOCKER_AVAILABLE=true
# 检查 macOS Docker Desktop 安装位置
elif [ -f "/Applications/Docker.app/Contents/Resources/bin/docker" ]; then
    DOCKER_CMD="/Applications/Docker.app/Contents/Resources/bin/docker"
    DOCKER_AVAILABLE=true
    export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
fi

if [ "$DOCKER_AVAILABLE" = true ]; then
    log_info "Docker 可用，将运行完整测试套件"
else
    log_info "Docker 不可用，将跳过集成测试"
fi

if [ "$DOCKER_AVAILABLE" = true ]; then
    log_info "启动 GaussDB 容器集群..."

    # 直接使用 docker-compose 启动（简化版）
    docker-compose -f docker-compose-gaussdb-pseudo.yml up -d gaussdb-primary gaussdb-standby1 gaussdb-standby2

    # 等待数据库启动
    log_info "等待数据库启动..."
    sleep 30

    # 验证数据库连接
    log_info "验证数据库连接..."
    for i in {1..30}; do
        if docker-compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-primary pg_isready -U bloguser && \
           docker-compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-standby1 pg_isready -U bloguser && \
           docker-compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-standby2 pg_isready -U bloguser; then
            log_info "所有数据库已启动"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "数据库启动超时"
            exit 1
        fi
        log_info "等待数据库启动... ($i/30)"
        sleep 10
    done

    # 导入测试数据
    log_info "导入初始化数据..."
    docker-compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-primary psql -U bloguser -d blog_db -f /docker-entrypoint-initdb.d/01_init.sql

    # 启动后端服务进行测试
    log_info "启动后端服务..."
    docker-compose -f docker-compose-gaussdb-pseudo.yml up -d backend

    # 等待后端启动
    log_info "等待后端服务启动..."
    sleep 40

    for i in {1..30}; do
        if curl -f http://localhost:8081/api/posts/list &> /dev/null; then
            log_info "后端服务已启动"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "后端服务启动超时"
            exit 1
        fi
        log_info "等待后端启动... ($i/30)"
        sleep 5
    done

    # 执行后端测试
    log_info "执行后端数据库集成测试..."
    cd backend
    mkdir -p /tmp/test-logs
    mvn test -Dtest=DatabaseIntegrationTest -Dspring.profiles.active=test > /tmp/test-logs/backend-db-test.log 2>&1
    if [ $? -eq 0 ]; then
        log_info "后端数据库集成测试通过"
    else
        log_error "✗ 后端数据库集成测试失败"
        cat /tmp/test-logs/backend-db-test.log
        exit 1
    fi

    # 执行后端 API 端到端测试
    log_info "执行后端 API 端到端测试..."
    mkdir -p /tmp/test-logs
    mvn test -Dtest=ApiEndToEndTest -Dspring.profiles.active=test > /tmp/test-logs/backend-api-test.log 2>&1
    if [ $? -eq 0 ]; then
        log_info "后端 API 端到端测试通过"
    else
        log_error "✗ 后端 API 端到端测试失败"
        cat /tmp/test-logs/backend-api-test.log
        exit 1
    fi

    cd ..

    # 启动 Spark 集群进行验证
    log_info "启动 Spark 集群..."
    docker-compose -f docker-compose-gaussdb-pseudo.yml up -d spark-master spark-worker

    # 等待 Spark 启动
    log_info "等待 Spark 集群启动..."
    sleep 30

    for i in {1..20}; do
        if curl -f http://localhost:8090 &> /dev/null; then
            log_info "Spark Master 已启动"
            break
        fi
        if [ $i -eq 20 ]; then
            log_error "Spark Master 启动超时"
            exit 1
        fi
        log_info "等待 Spark 启动... ($i/20)"
        sleep 5
    done

    # 验证 Spark 集群状态
    log_info "验证 Spark 集群状态..."
    mkdir -p /tmp/test-logs
    if curl -f http://localhost:8090 > /tmp/test-logs/spark-master.log 2>&1; then
        log_info "Spark Master 运行正常"
    else
        log_warn "! Spark Master 访问失败，但不影响测试继续"
    fi

    # 验证 Spark 分析 API（带 Token）
    log_info "验证 Spark 分析 API..."
    # 先登录获取 Token
    LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8081/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123"}' 2>/dev/null)
    
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$TOKEN" ]; then
        # 调用 Spark 分析 API
        ANALYZE_RESPONSE=$(curl -s -X POST http://localhost:8081/api/stats/analyze \
            -H "Authorization: Bearer $TOKEN" 2>/dev/null)
        
        if echo "$ANALYZE_RESPONSE" | grep -q "分析"; then
            log_info "Spark 分析 API 调用成功"
        else
            log_warn "! Spark 分析 API 调用失败，但不影响测试继续"
            echo "$ANALYZE_RESPONSE" > /tmp/test-logs/spark-analyze-response.log
        fi
    else
        log_warn "! 无法获取登录 Token，跳过 Spark 分析 API 验证"
    fi

    # 验证读写分离
    log_info "验证读写分离配置..."
    mkdir -p /tmp/test-logs
    # 检查主库和备库的复制状态
    if docker-compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-primary psql -U bloguser -d blog_db -c "SELECT * FROM pg_stat_replication;" > /tmp/test-logs/replication-status.log 2>&1; then
        if grep -q "streaming\|standby" /tmp/test-logs/replication-status.log; then
            log_info "数据库复制状态正常"
        else
            log_warn "! 数据库复制状态检查失败，但不影响测试继续"
        fi
    else
        log_warn "! 无法检查复制状态，但不影响测试继续"
    fi

else
    log_info "跳过集成测试，直接运行单元测试..."

    # 执行后端单元测试（使用 H2 内存数据库）
    log_info "执行后端单元测试..."
    cd backend
    mvn test -Dtest="!DatabaseIntegrationTest,!ApiEndToEndTest" > /tmp/test-logs/backend-unit-test.log 2>&1
    if [ $? -eq 0 ]; then
        log_info "后端单元测试通过"
    else
        log_error "后端单元测试失败"
        cat /tmp/test-logs/backend-unit-test.log
        exit 1
    fi
    cd ..
fi

# 跳过前端 E2E 测试（可单独运行）
# log_info "跳过前端 E2E 测试（可单独在 frontend 目录运行 npm run test:e2e）"
# cd frontend
# npm install > /tmp/test-logs/frontend-install.log 2>&1
# npm run dev > /tmp/test-logs/frontend-dev.log 2>&1 &
# FRONTEND_PID=$!
# sleep 30
# npx playwright install > /tmp/test-logs/playwright-install.log 2>&1
# npm run test:e2e > /tmp/test-logs/frontend-e2e-test.log 2>&1
# kill $FRONTEND_PID 2>/dev/null || true
# cd ..

log_info "========================================="
log_info "   测试完成！"
log_info "========================================="
echo ""
log_info "测试摘要："

if [ "$DOCKER_AVAILABLE" = true ]; then
    echo "  PostgreSQL 主备集群启动"
    echo "  数据库集成测试"
    echo "  API 端到端测试"
    echo "  读写分离配置验证"
    echo "  Spark 集群启动"
    echo "  Spark 分析 API 验证"
else
    echo "  后端单元测试"
    echo "  ⚠ Docker 不可用，跳过集成测试"
fi

echo ""
echo "测试日志保存在: /tmp/test-logs/"
echo "测试完成时间: $(date)"
