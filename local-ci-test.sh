#!/bin/bash
# 本地 CI/CD 测试脚本 - 复制 GitHub Actions 测试流程
# 用法: ./local-ci-test.sh [backend|frontend|all]

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 清理函数
cleanup() {
    log_info "清理测试环境..."
    
    # 停止后端
    if [ -f backend.pid ]; then
        kill $(cat backend.pid) 2>/dev/null || true
        rm backend.pid
    fi
    
    # 停止前端
    if [ -f frontend.pid ]; then
        kill $(cat frontend.pid) 2>/dev/null || true
        rm frontend.pid
    fi
    
    log_success "清理完成"
}

# 设置退出时清理
trap cleanup EXIT INT TERM

# 检查 PostgreSQL 是否运行
check_postgres() {
    log_info "检查 PostgreSQL 服务..."
    
    if ! pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
        log_error "PostgreSQL 未运行！请先启动 PostgreSQL："
        echo "  brew services start postgresql@15"
        echo "  或"
        echo "  pg_ctl -D /usr/local/var/postgresql@15 start"
        exit 1
    fi
    
    log_success "PostgreSQL 正在运行"
}

# 初始化数据库
init_database() {
    log_info "初始化数据库..."
    
    # 清空现有数据（而不是删除重建数据库）
    log_info "清空现有数据..."
    PGPASSWORD=456789 psql -h localhost -U lying -d blog_db -c "
        DROP SCHEMA public CASCADE;
        CREATE SCHEMA public;
        GRANT ALL ON SCHEMA public TO lying;
        GRANT ALL ON SCHEMA public TO public;
    " 2>&1 || {
        log_warning "清空数据失败，尝试直接运行初始化脚本..."
    }
    
    # 运行初始化脚本
    if [ -f backend/src/main/resources/db/init.sql ]; then
        PGPASSWORD=456789 psql -h localhost -U lying -d blog_db -f backend/src/main/resources/db/init.sql
        log_success "初始化脚本执行完成"
    fi
    
    # 运行迁移脚本
    if [ -f backend/src/main/resources/db/migration_add_cover_image.sql ]; then
        PGPASSWORD=456789 psql -h localhost -U lying -d blog_db -f backend/src/main/resources/db/migration_add_cover_image.sql 2>/dev/null || true
        log_success "cover_image 迁移完成"
    fi
    
    if [ -f backend/src/main/resources/db/friendship.sql ]; then
        PGPASSWORD=456789 psql -h localhost -U lying -d blog_db -f backend/src/main/resources/db/friendship.sql 2>/dev/null || true
        log_success "friendship 迁移完成"
    fi
    
    log_success "数据库初始化完成"
}

# 后端测试
run_backend_tests() {
    echo ""
    echo "========================================="
    echo "         后端测试 (Backend Tests)"
    echo "========================================="
    echo ""
    
    check_postgres
    
    log_info "运行 Maven 测试..."
    cd backend
    
    # 设置环境变量
    export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/blog_db
    export SPRING_DATASOURCE_USERNAME=lying
    export SPRING_DATASOURCE_PASSWORD=456789
    
    # 运行测试
    if mvn clean test -B; then
        log_success "后端测试全部通过"
        cd ..
        return 0
    else
        log_error "后端测试失败"
        cd ..
        return 1
    fi
}

# 启动后端服务器
start_backend() {
    log_info "编译并启动后端服务器..."
    
    cd backend
    mvn clean package -DskipTests -q
    
    # 启动后端
    export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/blog_db
    export SPRING_DATASOURCE_USERNAME=lying
    export SPRING_DATASOURCE_PASSWORD=456789
    
    java -jar target/blog-system-1.0.0.jar > ../backend.log 2>&1 &
    echo $! > ../backend.pid
    cd ..
    
    log_info "等待后端服务启动（最多60秒）..."
    for i in {1..60}; do
        if curl -f http://localhost:8080/ > /dev/null 2>&1; then
            log_success "后端服务已启动"
            sleep 3
            
            # 测试登录 API
            if curl -f -X POST http://localhost:8080/api/auth/login \
                -H "Content-Type: application/json" \
                -d '{"username":"admin","password":"admin123"}' > /dev/null 2>&1; then
                log_success "后端 API 已就绪"
                return 0
            fi
        fi
        
        if [ $i -eq 60 ]; then
            log_error "后端启动超时！查看日志："
            tail -n 50 backend.log
            return 1
        fi
        
        sleep 2
    done
}

# 启动前端服务器
start_frontend() {
    log_info "启动前端开发服务器..."
    
    cd frontend
    
    # 确保依赖已安装
    if [ ! -d "node_modules" ]; then
        log_info "安装前端依赖..."
        npm install
    fi
    
    # 启动前端
    npm run dev > ../frontend.log 2>&1 &
    echo $! > ../frontend.pid
    cd ..
    
    log_info "等待前端服务启动（最多30秒）..."
    for i in {1..30}; do
        if curl -f http://localhost:5173 > /dev/null 2>&1; then
            log_success "前端服务已启动"
            sleep 2
            return 0
        fi
        
        if [ $i -eq 30 ]; then
            log_error "前端启动超时！查看日志："
            tail -n 50 frontend.log
            return 1
        fi
        
        sleep 1
    done
}

# 前端测试
run_frontend_tests() {
    echo ""
    echo "========================================="
    echo "         前端测试 (Frontend Tests)"
    echo "========================================="
    echo ""
    
    check_postgres
    init_database
    
    # 启动后端
    start_backend || {
        log_error "后端启动失败，无法运行前端测试"
        return 1
    }
    
    # 启动前端
    start_frontend || {
        log_error "前端启动失败"
        return 1
    }
    
    cd frontend
    
    # 确保 Playwright 浏览器已安装
    if [ ! -d "$HOME/.cache/ms-playwright" ]; then
        log_info "安装 Playwright 浏览器..."
        npx playwright install --with-deps chromium
    fi
    
    # 设置环境变量
    export CI=true
    export BASE_URL=http://localhost:5173
    export API_BASE_URL=http://localhost:8080/api
    
    local test_failed=0
    
    # 1. 运行单元测试
    echo ""
    log_info "运行单元测试..."
    if npm run test; then
        log_success "单元测试通过"
    else
        log_error "单元测试失败"
        test_failed=1
    fi
    
    # 2. 运行新功能测试（头像和个人主页）
    echo ""
    log_info "运行新功能测试（头像上传和个人主页）..."
    if npx playwright test tests/e2e/avatar.spec.ts tests/e2e/profile.spec.ts --reporter=list; then
        log_success "新功能测试通过"
    else
        log_warning "新功能测试失败（继续运行其他测试）"
    fi
    
    # 3. 运行好友系统核心测试
    echo ""
    log_info "运行好友系统核心功能测试..."
    if npx playwright test tests/e2e/friends.spec.ts tests/e2e/timeline.spec.ts --reporter=list; then
        log_success "好友系统核心测试通过"
    else
        log_warning "好友系统核心测试失败（继续运行其他测试）"
    fi
    
    # 4. 运行好友系统集成测试
    echo ""
    log_info "运行好友系统完整工作流集成测试..."
    if npx playwright test tests/e2e/friends-integration.spec.ts --reporter=list --workers=1; then
        log_success "好友系统集成测试通过"
    else
        log_warning "好友系统集成测试失败（继续运行其他测试）"
    fi
    
    # 5. 运行所有 E2E 测试
    echo ""
    log_info "运行所有 E2E 测试..."
    if npx playwright test --reporter=list; then
        log_success "所有 E2E 测试通过"
    else
        log_error "部分 E2E 测试失败"
        test_failed=1
    fi
    
    cd ..
    
    # 显示测试报告位置
    echo ""
    log_info "测试报告位置："
    echo "  - HTML 报告: frontend/playwright-report/index.html"
    echo "  - 测试截图: frontend/test-results/"
    echo "  - 后端日志: backend.log"
    echo "  - 前端日志: frontend.log"
    
    if [ $test_failed -eq 0 ]; then
        log_success "前端测试完成"
        return 0
    else
        log_error "前端测试失败"
        return 1
    fi
}

# 主函数
main() {
    local test_type="${1:-all}"
    
    echo ""
    echo "========================================="
    echo "   本地 CI/CD 测试 - Blog Circle"
    echo "========================================="
    echo ""
    
    case $test_type in
        backend)
            run_backend_tests
            ;;
        frontend)
            run_frontend_tests
            ;;
        all)
            local backend_result=0
            local frontend_result=0
            
            run_backend_tests || backend_result=$?
            run_frontend_tests || frontend_result=$?
            
            echo ""
            echo "========================================="
            echo "            测试结果总结"
            echo "========================================="
            echo ""
            
            if [ $backend_result -eq 0 ]; then
                log_success "后端测试通过"
            else
                log_error "后端测试失败"
            fi
            
            if [ $frontend_result -eq 0 ]; then
                log_success "前端测试通过"
            else
                log_error "前端测试失败"
            fi
            
            echo ""
            
            if [ $backend_result -eq 0 ] && [ $frontend_result -eq 0 ]; then
                log_success "🎉 所有测试通过！"
                return 0
            else
                log_error "⚠️  部分测试失败，请查看详细日志"
                return 1
            fi
            ;;
        *)
            log_error "未知的测试类型: $test_type"
            echo "用法: $0 [backend|frontend|all]"
            echo ""
            echo "示例："
            echo "  $0 backend   # 只运行后端测试"
            echo "  $0 frontend  # 只运行前端测试（包括 E2E）"
            echo "  $0 all       # 运行所有测试（默认）"
            return 1
            ;;
    esac
}

# 运行主函数
main "$@"

