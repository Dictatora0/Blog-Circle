#!/bin/bash

################################################################################
# Blog Circle 容器化部署测试脚本
# 测试本地 Docker 容器化部署
################################################################################

set -e

BACKEND_URL="http://localhost:8081"
FRONTEND_URL="http://localhost:8080"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

log_test() {
    echo -e "${BLUE}[测试]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[✓ 通过]${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}[✗ 失败]${NC} $1"
    ((FAILED++))
}

log_info() {
    echo -e "${YELLOW}[信息]${NC} $1"
}

echo "========================================="
echo "Blog Circle 容器化部署测试"
echo "========================================="
echo ""

# 1. 检查 Docker
log_test "1. 检查 Docker 环境"
if command -v docker &> /dev/null; then
    log_pass "Docker 已安装"
    docker --version
else
    log_fail "Docker 未安装"
    exit 1
fi
echo ""

# 2. 检查 Docker Compose
log_test "2. 检查 Docker Compose"
if docker compose version &> /dev/null; then
    log_pass "Docker Compose 已安装"
    docker compose version
else
    log_fail "Docker Compose 未安装"
    exit 1
fi
echo ""

# 3. 检查 docker-compose.yml
log_test "3. 检查 docker-compose.yml"
if [ -f "docker-compose.yml" ]; then
    log_pass "docker-compose.yml 存在"
else
    log_fail "docker-compose.yml 不存在"
    exit 1
fi
echo ""

# 4. 检查 Dockerfile
log_test "4. 检查 Dockerfile"
if [ -f "backend/Dockerfile" ] && [ -f "frontend/Dockerfile" ]; then
    log_pass "后端和前端 Dockerfile 存在"
else
    log_fail "Dockerfile 缺失"
    exit 1
fi
echo ""

# 5. 构建镜像
log_test "5. 构建 Docker 镜像"
log_info "这可能需要几分钟..."
if docker compose build --no-cache 2>&1 | tail -20; then
    log_pass "镜像构建成功"
else
    log_fail "镜像构建失败"
    exit 1
fi
echo ""

# 6. 启动容器
log_test "6. 启动容器"
log_info "启动数据库、后端、前端..."
if docker compose up -d 2>&1 | tail -10; then
    log_pass "容器启动成功"
else
    log_fail "容器启动失败"
    exit 1
fi
echo ""

# 7. 等待服务启动
log_test "7. 等待服务启动"
log_info "等待 30 秒..."
sleep 30
log_pass "等待完成"
echo ""

# 8. 检查容器状态
log_test "8. 检查容器状态"
if docker compose ps | grep -q "Up"; then
    log_pass "容器运行中"
    docker compose ps
else
    log_fail "容器未运行"
    docker compose logs
    exit 1
fi
echo ""

# 9. 测试后端连接
log_test "9. 测试后端 API 连接"
if curl -s "$BACKEND_URL/api/posts/list" | grep -q "code"; then
    log_pass "后端 API 响应正常"
else
    log_fail "后端 API 无响应"
    log_info "后端日志:"
    docker compose logs backend | tail -30
fi
echo ""

# 10. 测试前端连接
log_test "10. 测试前端连接"
if curl -s "$FRONTEND_URL" | grep -q "html\|<!DOCTYPE"; then
    log_pass "前端页面加载成功"
else
    log_fail "前端页面加载失败"
    log_info "前端日志:"
    docker compose logs frontend | tail -30
fi
echo ""

# 11. 测试数据库连接
log_test "11. 测试数据库连接"
if docker compose exec -T db psql -U bloguser -d blog_db -c "SELECT 1" &>/dev/null; then
    log_pass "数据库连接成功"
else
    log_fail "数据库连接失败"
fi
echo ""

# 12. 测试用户注册
log_test "12. 测试用户注册"
TIMESTAMP=$(date +%s)
REGISTER=$(curl -s -X POST "$BACKEND_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"testuser_$TIMESTAMP\",
    \"password\": \"Test@123456\",
    \"email\": \"test_$TIMESTAMP@example.com\",
    \"nickname\": \"Test User\"
  }")

if echo "$REGISTER" | grep -q '"code":200'; then
    log_pass "用户注册成功"
else
    log_fail "用户注册失败"
    log_info "响应: $REGISTER"
fi
echo ""

# 13. 清理
log_test "13. 清理容器"
log_info "停止并移除容器..."
docker compose down 2>&1 | tail -5
log_pass "清理完成"
echo ""

# 总结
echo "========================================="
echo "测试总结"
echo "========================================="
echo -e "${GREEN}通过: $PASSED${NC}"
echo -e "${RED}失败: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ 所有测试通过！容器化部署正常。${NC}"
    exit 0
else
    echo -e "${RED}❌ 部分测试失败，请检查日志。${NC}"
    exit 1
fi
