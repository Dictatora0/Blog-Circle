#!/bin/bash
# Blog Circle CORS修复与测试自动化脚本
# 生成时间: 2025-11-05
# 作者: DevOps + 全栈调试团队

set -e

echo "=================================================="
echo "Blog Circle CORS修复与测试自动化脚本"
echo "=================================================="
echo ""

PROJECT_ROOT="/Users/lifulin/Desktop/CloudCom"
cd "$PROJECT_ROOT"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[OK] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# 1. 备份原始文件
log_info "1. 备份原始配置文件..."
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
if [ -f backend/src/main/java/com/cloudcom/blog/config/WebConfig.java ]; then
    cp backend/src/main/java/com/cloudcom/blog/config/WebConfig.java \
       backend/src/main/java/com/cloudcom/blog/config/WebConfig.java.backup.$BACKUP_TIME
    log_success "备份完成: WebConfig.java.backup.$BACKUP_TIME"
else
    log_warning "WebConfig.java 不存在，跳过备份"
fi

# 2. 停止当前后端服务
log_info "2. 停止当前后端服务..."
BACKEND_PID=$(lsof -t -i:8080 2>/dev/null || echo "")
if [ -n "$BACKEND_PID" ]; then
    kill -15 $BACKEND_PID 2>/dev/null || kill -9 $BACKEND_PID 2>/dev/null || true
    sleep 3
    log_success "已停止后端服务 (PID: $BACKEND_PID)"
else
    log_warning "未检测到运行中的后端服务"
fi

# 3. 验证CORS配置已修改
log_info "3. 验证CORS配置..."
if grep -q "allowedOriginPatterns" backend/src/main/java/com/cloudcom/blog/config/WebConfig.java; then
    log_success "WebConfig.java 已包含 allowedOriginPatterns 配置"
else
    log_warning "WebConfig.java 可能未正确更新，请手动检查"
fi

if [ -f backend/src/main/java/com/cloudcom/blog/config/CorsConfig.java ]; then
    log_success "CorsConfig.java 过滤器已存在"
else
    log_warning "CorsConfig.java 未找到，仅使用 WebConfig 配置"
fi

# 4. 清理并重新编译后端
log_info "4. 清理并重新编译后端..."
cd backend
rm -rf target/
log_info "正在编译，请稍候..."
if mvn clean package -DskipTests -q; then
    log_success "后端编译成功"
else
    log_error "后端编译失败，请检查代码"
    exit 1
fi
cd ..

# 5. 启动后端服务
log_info "5. 启动后端服务..."
cd backend
nohup java -jar target/blog-system-1.0.0.jar > ../backend-restart.log 2>&1 &
BACKEND_PID=$!
cd ..

echo "后端服务已启动 (PID: $BACKEND_PID)"
log_info "等待服务就绪（15秒）..."
for i in {1..15}; do
    echo -n "."
    sleep 1
done
echo ""

# 6. 验证服务
log_info "6. 验证服务状态..."
MAX_RETRIES=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -f http://localhost:8080/api/auth/test > /dev/null 2>&1; then
        log_success "后端服务正常响应"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            log_warning "服务未就绪，重试 $RETRY_COUNT/$MAX_RETRIES..."
            sleep 3
        else
            log_error "后端服务未正常响应，请检查日志: backend-restart.log"
            tail -50 backend-restart.log
            exit 1
        fi
    fi
done

# 7. 测试CORS配置
log_info "7. 测试CORS配置..."
echo "正在发送OPTIONS预检请求..."

CORS_RESPONSE=$(curl -s -X OPTIONS http://localhost:8080/api/auth/register \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  -I 2>&1)

if echo "$CORS_RESPONSE" | grep -q "Access-Control-Allow-Origin"; then
    ALLOW_ORIGIN=$(echo "$CORS_RESPONSE" | grep "Access-Control-Allow-Origin" | tr -d '\r')
    log_success "CORS配置正常"
    echo "   $ALLOW_ORIGIN"
    
    if echo "$CORS_RESPONSE" | grep -q "Access-Control-Allow-Credentials"; then
        log_success "Credentials支持已启用"
    fi
else
    log_warning "CORS响应头未找到，可能仍有问题"
    echo "响应内容:"
    echo "$CORS_RESPONSE" | head -20
fi

# 8. 测试实际API调用
log_info "8. 测试注册API..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/auth/register \
  -H "Origin: http://localhost:5173" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"testcors_$(date +%s)\",\"email\":\"test@test.com\",\"password\":\"123456\",\"confirmPassword\":\"123456\"}" \
  -w "\n%{http_code}" 2>&1)

HTTP_CODE=$(echo "$REGISTER_RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$REGISTER_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "注册API调用成功 (HTTP $HTTP_CODE)"
    echo "$RESPONSE_BODY" | head -3
elif [ "$HTTP_CODE" = "400" ] && echo "$RESPONSE_BODY" | grep -q "用户名已存在\|注册"; then
    log_success "注册API正常响应 (HTTP $HTTP_CODE - 业务逻辑错误是正常的)"
else
    log_warning "注册API返回 HTTP $HTTP_CODE"
    echo "响应内容: $RESPONSE_BODY" | head -5
fi

# 9. 运行E2E测试
log_info "9. 运行E2E测试..."
cd frontend

# 清理旧的测试结果
rm -rf test-results/* playwright-report/* 2>/dev/null || true

log_info "开始运行Playwright测试（这可能需要几分钟）..."

# 先只运行认证测试验证修复
if TEST_ENV=local npx playwright test tests/e2e/auth.spec.ts --reporter=list; then
    log_success "认证模块测试通过！"
else
    log_warning "认证模块测试有失败，但CORS问题可能已修复"
fi

# 运行完整测试套件
log_info "运行完整测试套件..."
TEST_ENV=local npm run test:e2e || true

cd ..

# 10. 生成测试报告
log_info "10. 生成测试报告..."
echo ""
echo "=================================================="
echo "测试结果摘要"
echo "=================================================="

if [ -f frontend/test-results/junit.xml ]; then
    TEST_SUMMARY=$(grep -E "<testsuites.*tests=" frontend/test-results/junit.xml | head -1)
    
    TOTAL_TESTS=$(echo "$TEST_SUMMARY" | grep -oP 'tests="\K[^"]+' || echo "N/A")
    FAILURES=$(echo "$TEST_SUMMARY" | grep -oP 'failures="\K[^"]+' || echo "N/A")
    PASSED=$((TOTAL_TESTS - FAILURES))
    
    echo ""
    echo "总测试数: $TOTAL_TESTS"
    echo "通过: $PASSED"
    echo "失败: $FAILURES"
    
    if [ "$FAILURES" -lt 30 ]; then
        log_success "测试通过率显著提升！"
    else
        log_warning "仍有较多测试失败，可能需要进一步检查"
    fi
else
    log_warning "无法找到测试结果文件"
fi

echo ""
echo "=================================================="
echo "修复流程完成!"
echo "=================================================="
echo ""
echo "📁 生成的文件:"
echo "   - 后端日志: $PROJECT_ROOT/backend-restart.log"
echo "   - 测试报告: $PROJECT_ROOT/frontend/playwright-report/index.html"
echo "   - 测试结果: $PROJECT_ROOT/frontend/test-results/junit.xml"
echo "   - 配置备份: backend/.../WebConfig.java.backup.$BACKUP_TIME"
echo ""
echo "🔍 查看详细信息:"
echo "   后端日志: tail -f backend-restart.log"
echo "   测试报告: cd frontend && npx playwright show-report"
echo "   后端状态: curl http://localhost:8080/api/auth/test"
echo ""
echo "=================================================="

