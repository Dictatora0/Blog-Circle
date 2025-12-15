#!/bin/bash

###############################################################
# OpenEuler 环境部署脚本
# 用于在 OpenEuler 虚拟机上快速部署 Blog Circle 项目
###############################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }

# 配置变量
PROJECT_DIR="${1:-.}"
ENV_FILE="${PROJECT_DIR}/.env.opengauss"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose-opengauss-cluster-portable.yml"

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   OpenEuler 部署脚本                   ║${NC}"
    echo -e "${BLUE}║   Blog Circle + OpenGauss              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    # 1. 检查 OpenEuler 系统
    log_info "检查系统环境..."
    check_openeuler

    # 2. 安装依赖
    log_info "安装系统依赖..."
    install_dependencies

    # 3. 启动 Docker
    log_info "启动 Docker 服务..."
    start_docker

    # 4. 准备配置文件
    log_info "准备配置文件..."
    prepare_config

    # 5. 拉取镜像
    log_info "拉取 Docker 镜像..."
    pull_images

    # 6. 启动服务
    log_info "启动服务..."
    start_services

    # 7. 验证部署
    log_info "验证部署..."
    verify_deployment

    echo ""
    log_success "部署完成！"
    print_summary
}

# 检查 OpenEuler 系统
check_openeuler() {
    if [ ! -f /etc/os-release ]; then
        log_error "无法识别操作系统"
        exit 1
    fi

    OS_NAME=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2)
    OS_VERSION=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2)

    if [[ "$OS_NAME" != *"OpenEuler"* ]]; then
        log_warn "检测到非 OpenEuler 系统: $OS_NAME $OS_VERSION"
        log_warn "此脚本针对 OpenEuler 优化，其他系统可能存在兼容性问题"
        read -p "是否继续? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "检测到 OpenEuler: $OS_NAME $OS_VERSION"
    fi
}

# 安装系统依赖
install_dependencies() {
    log_info "更新包管理器..."
    sudo dnf update -y > /dev/null 2>&1 || true

    # 检查并安装 Docker
    if ! command -v docker &> /dev/null; then
        log_info "安装 Docker..."
        sudo dnf install -y docker > /dev/null 2>&1
        log_success "Docker 已安装"
    else
        log_success "Docker 已安装"
    fi

    # 检查并安装 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_info "安装 Docker Compose..."
        sudo dnf install -y docker-compose > /dev/null 2>&1
        log_success "Docker Compose 已安装"
    else
        log_success "Docker Compose 已安装"
    fi

    # 检查并安装其他工具
    for tool in curl wget git; do
        if ! command -v $tool &> /dev/null; then
            log_info "安装 $tool..."
            sudo dnf install -y $tool > /dev/null 2>&1
        fi
    done

    log_success "系统依赖安装完成"
}

# 启动 Docker 服务
start_docker() {
    # 启动 Docker 守护进程
    if ! sudo systemctl is-active --quiet docker; then
        log_info "启动 Docker 服务..."
        sudo systemctl start docker
    fi

    # 启用开机自启
    sudo systemctl enable docker > /dev/null 2>&1

    # 添加当前用户到 docker 组
    if ! groups $USER | grep -q docker; then
        log_info "添加用户到 docker 组..."
        sudo usermod -aG docker $USER
        log_warn "请运行: newgrp docker 或重新登录以应用权限"
    fi

    log_success "Docker 服务已启动"
}

# 准备配置文件
prepare_config() {
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "${PROJECT_DIR}/.env.opengauss.example" ]; then
            log_info "复制配置模板..."
            cp "${PROJECT_DIR}/.env.opengauss.example" "$ENV_FILE"
            log_success "配置文件已创建: $ENV_FILE"
        else
            log_error "找不到配置模板"
            exit 1
        fi
    else
        log_success "配置文件已存在: $ENV_FILE"
    fi

    # 检查配置文件中的镜像设置
    if grep -q "OPENGAUSS_IMAGE=enmotech" "$ENV_FILE"; then
        log_warn "检测到使用 enmotech 镜像，建议在 OpenEuler 上使用官方镜像"
        log_info "修改建议: OPENGAUSS_IMAGE=openeuler/opengauss:5.0.0"
    fi
}

# 拉取镜像
pull_images() {
    log_info "拉取 OpenGauss 镜像..."
    
    # 从配置文件读取镜像名称
    OPENGAUSS_IMAGE=$(grep "^OPENGAUSS_IMAGE=" "$ENV_FILE" | cut -d'=' -f2 || echo "openeuler/opengauss:5.0.0")
    
    # 如果是默认值，使用 OpenEuler 官方镜像
    if [ -z "$OPENGAUSS_IMAGE" ] || [ "$OPENGAUSS_IMAGE" = "enmotech/opengauss-lite:5.0.0" ]; then
        OPENGAUSS_IMAGE="openeuler/opengauss:5.0.0"
        log_warn "使用 OpenEuler 官方镜像: $OPENGAUSS_IMAGE"
    fi

    # 拉取镜像
    docker pull "$OPENGAUSS_IMAGE" || {
        log_error "无法拉取镜像: $OPENGAUSS_IMAGE"
        log_info "尝试使用备选镜像..."
        OPENGAUSS_IMAGE="enmotech/opengauss-lite:5.0.0"
        docker pull "$OPENGAUSS_IMAGE"
    }

    log_success "镜像拉取完成"
}

# 启动服务
start_services() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "找不到 docker-compose 文件: $COMPOSE_FILE"
        exit 1
    fi

    cd "$PROJECT_DIR"

    # 停止已有的服务
    log_info "清理旧容器..."
    docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true

    # 启动新服务
    log_info "启动服务..."
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

    log_success "服务已启动"
}

# 验证部署
verify_deployment() {
    log_info "等待服务初始化..."
    sleep 30

    log_info "检查容器状态..."
    docker-compose -f "$COMPOSE_FILE" ps

    log_info "检查数据库连接..."
    if docker exec opengauss-primary su - omm -c '/usr/local/opengauss/bin/gsql -d postgres -c "SELECT 1"' &> /dev/null; then
        log_success "数据库连接正常"
    else
        log_warn "数据库仍在初始化，请稍候..."
    fi
}

# 打印总结
print_summary() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}部署信息${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    echo "项目目录: $PROJECT_DIR"
    echo "配置文件: $ENV_FILE"
    echo "Compose 文件: $COMPOSE_FILE"
    echo ""
    echo -e "${BLUE}访问地址${NC}"
    echo "  • 前端: http://localhost:8080"
    echo "  • 后端: http://localhost:8082"
    echo "  • 健康检查: http://localhost:8082/actuator/health"
    echo ""
    echo -e "${BLUE}数据库连接${NC}"
    echo "  • 主库: localhost:5432"
    echo "  • 备库1: localhost:5434"
    echo "  • 备库2: localhost:5436"
    echo ""
    echo -e "${BLUE}常用命令${NC}"
    echo "  • 查看日志: docker-compose -f $COMPOSE_FILE logs -f"
    echo "  • 停止服务: docker-compose -f $COMPOSE_FILE down"
    echo "  • 重启服务: docker-compose -f $COMPOSE_FILE restart"
    echo ""
    echo -e "${BLUE}后续步骤${NC}"
    echo "  1. 编辑配置文件: vi $ENV_FILE"
    echo "  2. 查看日志: docker-compose -f $COMPOSE_FILE logs -f"
    echo "  3. 访问应用: http://localhost:8080"
    echo ""
}

# 错误处理
trap 'log_error "部署失败"; exit 1' ERR

# 运行主程序
main "$@"
