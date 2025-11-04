

#!/bin/bash

# 运行所有测试的脚本
# 使用方法: ./run-tests.sh [backend|frontend|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

print_error() {
    echo -e "${RED}❌ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  ${1}${NC}"
}

# 打印分隔线
print_separator() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
    echo ""
}

# 运行后端测试
run_backend_tests() {
    print_separator "后端测试"
    
    if [ ! -d "backend" ]; then
        print_error "backend 目录不存在"
        return 1
    fi
    
    cd backend
    
    print_info "运行后端单元测试..."
    if mvn test -B; then
        print_success "后端测试通过"
        cd ..
        return 0
    else
        print_error "后端测试失败"
        cd ..
        return 1
    fi
}

# 运行前端单元测试
run_frontend_unit_tests() {
    print_separator "前端单元测试"
    
    if [ ! -d "frontend" ]; then
        print_error "frontend 目录不存在"
        return 1
    fi
    
    cd frontend
    
    print_info "检查依赖..."
    if [ ! -d "node_modules" ]; then
        print_warning "node_modules 不存在，正在安装依赖..."
        npm install
    fi
    
    print_info "运行前端单元测试..."
    if npm run test -- --run; then
        print_success "前端单元测试通过"
        cd ..
        return 0
    else
        print_error "前端单元测试失败"
        cd ..
        return 1
    fi
}

# 运行前端E2E测试
run_frontend_e2e_tests() {
    print_separator "前端E2E测试"
    
    if [ ! -d "frontend" ]; then
        print_error "frontend 目录不存在"
        return 1
    fi
    
    cd frontend
    
    print_info "检查依赖..."
    if [ ! -d "node_modules" ]; then
        print_warning "node_modules 不存在，正在安装依赖..."
        npm install
    fi
    
    print_info "检查Playwright浏览器..."
    if ! npx playwright --version &> /dev/null; then
        print_warning "Playwright未安装，正在安装..."
        npx playwright install --with-deps chromium
    fi
    
    # 如果是直接调用此函数（非从run_all_tests调用），才提示确认
    if [ -z "$SKIP_E2E_CONFIRM" ]; then
        print_warning "E2E测试需要运行中的服务器"
        print_info "确保后端和前端服务已启动"
        print_info "运行: ./start.sh"
        echo ""
        read -p "继续运行E2E测试？(y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "跳过E2E测试"
            cd ..
            return 0
        fi
    fi
    
    print_info "运行前端E2E测试..."
    if npm run test:e2e; then
        print_success "前端E2E测试通过"
        cd ..
        return 0
    else
        print_error "前端E2E测试失败"
        cd ..
        return 1
    fi
}

# 运行时间线隔离测试
run_timeline_isolation_tests() {
    print_separator "时间线隔离功能测试"
    
    if [ ! -f "test-timeline-isolation.sh" ]; then
        print_error "test-timeline-isolation.sh 不存在"
        return 1
    fi
    
    print_info "检查 jq 是否安装..."
    if ! command -v jq &> /dev/null; then
        print_error "jq 未安装，请先安装: brew install jq (macOS) 或 apt install jq (Linux)"
        return 1
    fi
    
    # 如果是直接调用此函数（非从run_all_tests调用），才提示确认
    if [ -z "$SKIP_TIMELINE_CONFIRM" ]; then
        print_warning "此测试需要本地和远程服务器都在运行"
        print_info "本地服务: http://localhost:8080"
        print_info "远程服务: http://10.211.55.11:8080"
        echo ""
        read -p "继续运行时间线隔离测试？(y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "跳过时间线隔离测试"
            return 0
        fi
    fi
    
    print_info "运行时间线隔离测试..."
    if ./test-timeline-isolation.sh all; then
        print_success "时间线隔离测试通过"
        return 0
    else
        print_error "时间线隔离测试失败"
        return 1
    fi
}

# 运行所有测试
run_all_tests() {
    print_separator "运行所有测试"
    
    BACKEND_RESULT=0
    FRONTEND_UNIT_RESULT=0
    FRONTEND_E2E_RESULT=0
    TIMELINE_RESULT=0
    
    # 优先运行前端E2E测试（最重要的集成测试）
    print_warning "E2E测试需要运行中的服务器（后端 + 前端）"
    print_info "确保已运行: ./start.sh"
    echo ""
    read -p "是否运行E2E测试？(y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 设置标志，跳过函数内部的二次确认
        export SKIP_E2E_CONFIRM=1
        if ! run_frontend_e2e_tests; then
            FRONTEND_E2E_RESULT=1
        fi
        unset SKIP_E2E_CONFIRM
    fi
    
    # 运行前端单元测试
    if ! run_frontend_unit_tests; then
        FRONTEND_UNIT_RESULT=1
    fi
    
    # 运行后端测试
    if ! run_backend_tests; then
        BACKEND_RESULT=1
    fi
    
    # 运行时间线隔离测试（可选）
    print_warning "时间线隔离测试需要本地和远程服务器都在运行"
    print_info "本地服务: http://localhost:8080"
    print_info "远程服务: http://10.211.55.11:8080"
    echo ""
    read -p "是否运行时间线隔离测试？(y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 设置标志，跳过函数内部的二次确认
        export SKIP_TIMELINE_CONFIRM=1
        if ! run_timeline_isolation_tests; then
            TIMELINE_RESULT=1
        fi
        unset SKIP_TIMELINE_CONFIRM
    fi
    
    # 汇总结果
    print_separator "测试结果汇总"
    
    if [ $FRONTEND_E2E_RESULT -eq 0 ]; then
        print_success "前端E2E测试: 通过"
    else
        print_error "前端E2E测试: 失败"
    fi
    
    if [ $FRONTEND_UNIT_RESULT -eq 0 ]; then
        print_success "前端单元测试: 通过"
    else
        print_error "前端单元测试: 失败"
    fi
    
    if [ $BACKEND_RESULT -eq 0 ]; then
        print_success "后端测试: 通过"
    else
        print_error "后端测试: 失败"
    fi
    
    if [ $TIMELINE_RESULT -eq 0 ]; then
        print_success "时间线隔离测试: 通过"
    else
        print_error "时间线隔离测试: 失败"
    fi
    
    # 返回总体结果
    if [ $BACKEND_RESULT -eq 0 ] && [ $FRONTEND_UNIT_RESULT -eq 0 ]; then
        print_success "所有核心测试通过！"
        return 0
    else
        print_error "部分测试失败"
        return 1
    fi
}

# 主逻辑
case "${1:-all}" in
    backend)
        run_backend_tests
        exit $?
        ;;
    frontend)
        run_frontend_unit_tests
        exit $?
        ;;
    e2e)
        run_frontend_e2e_tests
        exit $?
        
        ;;
    timeline)
        run_timeline_isolation_tests
        exit $?
        ;;
    all)
        run_all_tests
        exit $?
        ;;
    *)
        echo "使用方法: $0 [backend|frontend|e2e|timeline|all]"
        echo ""
        echo "选项:"
        echo "  backend   - 仅运行后端测试"
        echo "  frontend  - 仅运行前端单元测试"
        echo "  e2e       - 仅运行前端E2E测试"
        echo "  timeline  - 仅运行时间线隔离测试"
        echo "  all       - 运行所有测试（默认）"
        exit 1
        ;;
esac

