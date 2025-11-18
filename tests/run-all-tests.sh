#!/bin/bash

################################################################################
# Blog Circle 完整测试执行脚本
# 按顺序执行所有测试套件并生成综合报告
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
export GAUSSDB_HOST=${GAUSSDB_HOST:-10.211.55.11}
export GAUSSDB_PORT=${GAUSSDB_PORT:-5432}
export GAUSSDB_USERNAME=${GAUSSDB_USERNAME:-bloguser}
export GAUSSDB_PASSWORD=${GAUSSDB_PASSWORD:-blogpass}
export BACKEND_URL=${BACKEND_URL:-http://localhost:8081}
export FRONTEND_URL=${FRONTEND_URL:-http://localhost:8080}

# 测试结果
COMPREHENSIVE_TEST_PASSED=true

################################################################################
# 工具函数
################################################################################

log_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

################################################################################
# 主函数
################################################################################

main() {
    log_header "Blog Circle 完整测试套件"
    
    log_info "测试配置:"
    log_info "  GaussDB: $GAUSSDB_HOST:$GAUSSDB_PORT"
    log_info "  后端: $BACKEND_URL"
    log_info "  前端: $FRONTEND_URL"
    echo ""
    
    # 确保测试脚本可执行
    cd "$(dirname "$0")"
    chmod +x automated-test-suite.sh
    chmod +x api-test-suite.sh
    chmod +x database-test-suite.sh
    
    # 1. 系统自动化测试
    log_header "1. 系统自动化测试"
    if ./automated-test-suite.sh; then
        log_success "系统自动化测试通过"
    else
        log_error "系统自动化测试失败"
        COMPREHENSIVE_TEST_PASSED=false
    fi
    
    echo ""
    read -p "按 Enter 继续 API 测试..." -r
    
    # 2. API 测试
    log_header "2. API 完整测试"
    if ./api-test-suite.sh; then
        log_success "API 测试通过"
    else
        log_error "API 测试失败"
        COMPREHENSIVE_TEST_PASSED=false
    fi
    
    echo ""
    read -p "按 Enter 继续数据库测试..." -r
    
    # 3. 数据库测试
    log_header "3. 数据库测试"
    if ./database-test-suite.sh; then
        log_success "数据库测试通过"
    else
        log_error "数据库测试失败"
        COMPREHENSIVE_TEST_PASSED=false
    fi
    
    # 生成综合报告
    log_header "综合测试报告"
    
    echo "测试时间: $(date)"
    echo ""
    echo "测试套件执行情况:"
    echo "  1. 系统自动化测试: $([ -f test-logs/test-*.log ] && echo '已完成' || echo '未执行')"
    echo "  2. API 完整测试: $([ -f test-logs/api-test-*.log ] && echo '已完成' || echo '未执行')"
    echo "  3. 数据库测试: $([ -f test-logs/db-test-*.log ] && echo '已完成' || echo '未执行')"
    echo ""
    
    if [ "$COMPREHENSIVE_TEST_PASSED" = true ]; then
        log_success "所有测试套件通过！"
        echo ""
        echo "系统状态: 健康"
        echo "建议: 可以部署到生产环境"
        exit 0
    else
        log_error "部分测试套件失败"
        echo ""
        echo "系统状态: 需要修复"
        echo "建议: 查看详细日志并修复问题"
        exit 1
    fi
}

# 运行主函数
main "$@"
