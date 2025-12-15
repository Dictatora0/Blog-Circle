#!/bin/bash

###############################################################
# 项目可移植性验证脚本
# 用于检查部署环境是否满足要求
###############################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 计数器
PASS=0
FAIL=0
WARN=0

# 日志函数
log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# 检查命令是否存在
check_command() {
    if command -v "$1" &> /dev/null; then
        log_pass "$1 已安装"
        return 0
    else
        log_fail "$1 未安装"
        return 1
    fi
}

# 检查文件是否存在
check_file() {
    if [ -f "$1" ]; then
        log_pass "文件存在: $1"
        return 0
    else
        log_fail "文件不存在: $1"
        return 1
    fi
}

# 主程序
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Blog Circle 可移植性验证工具         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    # 1. 检查基础工具
    log_section "1. 检查基础工具"
    
    check_command "docker"
    check_command "docker-compose"
    check_command "git"
    
    # 2. 检查 Docker 版本
    log_section "2. 检查 Docker 版本"
    
    DOCKER_VERSION=$(docker --version 2>/dev/null || echo "unknown")
    log_info "Docker 版本: $DOCKER_VERSION"
    
    COMPOSE_VERSION=$(docker-compose --version 2>/dev/null || echo "unknown")
    log_info "Docker Compose 版本: $COMPOSE_VERSION"
    
    # 3. 检查 Docker 守护进程
    log_section "3. 检查 Docker 守护进程"
    
    if docker ps &> /dev/null; then
        log_pass "Docker 守护进程运行正常"
    else
        log_fail "Docker 守护进程未运行或无权限"
        log_info "尝试运行: sudo systemctl start docker"
    fi
    
    # 4. 检查配置文件
    log_section "4. 检查配置文件"
    
    check_file ".env.opengauss"
    check_file "docker-compose-opengauss-cluster-portable.yml"
    check_file "docker-compose-opengauss-cluster-legacy.yml"
    
    # 5. 检查项目结构
    log_section "5. 检查项目结构"
    
    check_file "backend/Dockerfile"
    check_file "frontend/Dockerfile"
    check_file "scripts/full_verify.sh"
    
    # 6. 检查网络配置
    log_section "6. 检查网络配置"
    
    if [ -f ".env.opengauss" ]; then
        SUBNET=$(grep "DOCKER_NETWORK_SUBNET" .env.opengauss | cut -d'=' -f2)
        log_info "配置的网络子网: ${SUBNET:-172.26.0.0/16}"
        
        # 检查是否有网络冲突
        if docker network ls | grep -q "opengauss-network"; then
            log_warn "opengauss-network 已存在（可能是旧部署）"
            log_info "建议清理: docker network rm opengauss-network"
        else
            log_pass "网络命名空间清洁"
        fi
    fi
    
    # 7. 检查磁盘空间
    log_section "7. 检查磁盘空间"
    
    AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -gt 10 ]; then
        log_pass "磁盘空间充足 (${AVAILABLE_SPACE}GB 可用)"
    else
        log_warn "磁盘空间不足 (仅 ${AVAILABLE_SPACE}GB 可用，建议 >10GB)"
    fi
    
    # 8. 检查内存
    log_section "8. 检查内存"
    
    if command -v free &> /dev/null; then
        AVAILABLE_MEM=$(free -g | grep Mem | awk '{print $7}')
        if [ "$AVAILABLE_MEM" -gt 2 ]; then
            log_pass "内存充足 (${AVAILABLE_MEM}GB 可用)"
        else
            log_warn "内存可能不足 (仅 ${AVAILABLE_MEM}GB 可用，建议 >2GB)"
        fi
    elif command -v vm_stat &> /dev/null; then
        # macOS
        log_info "macOS 系统，跳过内存检查"
    fi
    
    # 9. 检查操作系统
    log_section "9. 检查操作系统"
    
    if [ -f /etc/os-release ]; then
        OS_NAME=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2)
        OS_VERSION=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2)
        log_info "操作系统: $OS_NAME $OS_VERSION"
        
        if [[ "$OS_NAME" == *"OpenEuler"* ]]; then
            log_pass "检测到 OpenEuler 系统"
            log_info "建议使用镜像: openeuler/opengauss:5.0.0"
        elif [[ "$OS_NAME" == *"Ubuntu"* ]] || [[ "$OS_NAME" == *"CentOS"* ]]; then
            log_pass "检测到兼容系统"
        fi
    elif [ "$(uname)" == "Darwin" ]; then
        log_info "操作系统: macOS"
        log_pass "macOS 支持 Docker Desktop"
    fi
    
    # 10. 检查镜像可用性
    log_section "10. 检查镜像可用性"
    
    log_info "检查镜像拉取能力..."
    if docker pull --dry-run enmotech/opengauss-lite:5.0.0 &> /dev/null 2>&1; then
        log_pass "可以拉取 enmotech/opengauss-lite:5.0.0"
    else
        log_warn "无法验证镜像拉取（可能是网络问题）"
        log_info "部署时会自动尝试拉取镜像"
    fi
    
    # 11. 检查端口可用性
    log_section "11. 检查端口可用性"
    
    PORTS=(5432 5434 5436 8080 8082)
    for port in "${PORTS[@]}"; do
        if command -v netstat &> /dev/null; then
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                log_warn "端口 $port 已被占用"
            else
                log_pass "端口 $port 可用"
            fi
        elif command -v lsof &> /dev/null; then
            if lsof -i ":$port" &> /dev/null; then
                log_warn "端口 $port 已被占用"
            else
                log_pass "端口 $port 可用"
            fi
        else
            log_info "跳过端口 $port 检查（无可用工具）"
        fi
    done
    
    # 12. 检查 git 仓库
    log_section "12. 检查 Git 仓库"
    
    if [ -d ".git" ]; then
        log_pass "Git 仓库已初始化"
        BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        log_info "当前分支: $BRANCH"
    else
        log_warn "Git 仓库未初始化"
    fi
    
    # 总结
    log_section "验证总结"
    
    echo ""
    echo -e "${GREEN}通过: $PASS${NC}"
    echo -e "${YELLOW}警告: $WARN${NC}"
    echo -e "${RED}失败: $FAIL${NC}"
    echo ""
    
    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}✓ 环境检查通过！可以开始部署${NC}"
        echo ""
        echo "后续步骤："
        echo "  1. 编辑配置文件: vi .env.opengauss"
        echo "  2. 启动服务: docker-compose -f docker-compose-opengauss-cluster-portable.yml --env-file .env.opengauss up -d"
        echo "  3. 查看状态: docker-compose -f docker-compose-opengauss-cluster-portable.yml ps"
        return 0
    else
        echo -e "${RED}✗ 环境检查失败，请修复上述问题后重试${NC}"
        return 1
    fi
}

# 运行主程序
main "$@"
