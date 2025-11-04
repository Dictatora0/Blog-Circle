#!/bin/bash

set -e

# ============================================
#   配置区域（请根据实际情况修改）
# ============================================
SERVER_IP="10.211.55.11"
SERVER_USER="root"
SERVER_PASSWORD="747599qw"
PROJECT_DIR="CloudCom"

# ============================================
#   颜色定义
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
#   辅助函数
# ============================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================
#   检查依赖
# ============================================
check_dependencies() {
    log_info "检查依赖工具..."
    
    # 检查 sshpass（用于密码认证）
    if ! command -v sshpass &> /dev/null; then
        log_error "未找到 sshpass，请先安装："
        echo "  macOS: brew install hudochenkov/sshpass/sshpass"
        echo "  Linux: yum install sshpass 或 apt-get install sshpass"
        exit 1
    fi
    
    # 检查 ssh
    if ! command -v ssh &> /dev/null; then
        log_error "未找到 ssh，请先安装 OpenSSH"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# ============================================
#   测试 SSH 连接
# ============================================
test_ssh_connection() {
    log_info "测试 SSH 连接..."
    
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "${SERVER_USER}@${SERVER_IP}" "echo 'SSH连接成功'" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "SSH 连接测试成功"
    else
        log_error "SSH 连接失败，请检查："
        echo "  1. 服务器IP是否正确: $SERVER_IP"
        echo "  2. 用户名是否正确: $SERVER_USER"
        echo "  3. 密码是否正确"
        echo "  4. 服务器是否可访问"
        exit 1
    fi
}

# ============================================
#   执行远程命令
# ============================================
execute_remote() {
    local cmd="$1"
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no \
        "${SERVER_USER}@${SERVER_IP}" "$cmd"
}

# ============================================
#   主函数
# ============================================
main() {
    echo ""
    echo "========================================="
    echo "   Blog Circle 远程更新部署脚本"
    echo "========================================="
    echo ""
    log_info "服务器: ${SERVER_USER}@${SERVER_IP}"
    log_info "项目目录: ${PROJECT_DIR}"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 测试连接
    test_ssh_connection
    
    # 执行部署步骤
    log_info "开始远程部署流程..."
    echo ""
    
    # 1. 检查项目目录是否存在
    log_info "1. 检查项目目录..."
    if execute_remote "[ -d \"${PROJECT_DIR}\" ]"; then
        log_success "项目目录存在"
    else
        log_error "项目目录不存在: ${PROJECT_DIR}"
        log_warning "请先在服务器上克隆仓库或创建目录"
        exit 1
    fi
    
    # 2. 拉取最新代码
    log_info "2. 拉取最新代码..."
    execute_remote "cd ${PROJECT_DIR} && git fetch origin dev && git pull origin dev"
    if [ $? -eq 0 ]; then
        log_success "代码更新成功"
    else
        log_error "代码更新失败"
        exit 1
    fi
    
    # 3. 显示最新提交
    log_info "3. 显示最新提交信息..."
    execute_remote "cd ${PROJECT_DIR} && git log --oneline -3"
    echo ""
    
    # 4. 验证 docker-compose.yml
    log_info "4. 验证 docker-compose.yml..."
    if execute_remote "[ -f \"${PROJECT_DIR}/docker-compose.yml\" ]"; then
        log_success "docker-compose.yml 存在"
    else
        log_error "docker-compose.yml 不存在"
        exit 1
    fi
    
    # 5. 停止现有容器
    log_info "5. 停止现有容器..."
    execute_remote "cd ${PROJECT_DIR} && docker-compose down 2>/dev/null || true"
    log_success "容器已停止"
    
    # 6. 构建并启动服务
    log_info "6. 构建并启动服务（这可能需要几分钟）..."
    execute_remote "cd ${PROJECT_DIR} && docker-compose up -d --build"
    if [ $? -eq 0 ]; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败"
        exit 1
    fi
    
    # 7. 等待服务启动
    log_info "7. 等待服务启动（15秒）..."
    sleep 15
    
    # 8. 检查服务状态
    log_info "8. 检查服务状态..."
    execute_remote "cd ${PROJECT_DIR} && docker-compose ps"
    echo ""
    
    # 9. 显示服务日志
    log_info "9. 显示服务日志（最后20行）..."
    echo ""
    echo "=== 数据库日志 ==="
    execute_remote "cd ${PROJECT_DIR} && docker-compose logs --tail=20 db 2>/dev/null || echo '数据库日志暂不可用'"
    echo ""
    echo "=== 后端日志 ==="
    execute_remote "cd ${PROJECT_DIR} && docker-compose logs --tail=20 backend 2>/dev/null || echo '后端日志暂不可用'"
    echo ""
    echo "=== 前端日志 ==="
    execute_remote "cd ${PROJECT_DIR} && docker-compose logs --tail=20 frontend 2>/dev/null || echo '前端日志暂不可用'"
    echo ""
    
    # 完成
    echo "========================================="
    log_success "远程部署完成！"
    echo "========================================="
    echo ""
    echo "访问地址："
    echo "  前端: http://${SERVER_IP}:8080"
    echo "  后端: http://${SERVER_IP}:8081"
    echo ""
    echo "常用命令（在服务器上执行）："
    echo "  cd ${PROJECT_DIR}"
    echo "  docker-compose logs -f          # 查看所有日志"
    echo "  docker-compose logs -f backend # 查看后端日志"
    echo "  docker-compose restart          # 重启服务"
    echo "  docker-compose down             # 停止服务"
    echo ""
}

# 运行主函数
main
