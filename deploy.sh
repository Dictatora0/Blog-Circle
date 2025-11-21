#!/bin/bash

###############################################################
# Blog Circle 统一部署脚本
# 支持本地部署、VM部署、集群部署
###############################################################

set -euo pipefail

# 配置
VM_IP="10.211.55.11"
VM_USER="root"
VM_PASSWORD="747599qw@"
VM_PROJECT_DIR="CloudCom"

# 颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 显示用法
usage() {
    echo "用法: $0 [local|vm|cluster]"
    echo ""
    echo "部署模式:"
    echo "  local   - 本地 Docker Compose 部署"
    echo "  vm      - 虚拟机部署（离线镜像传输）"
    echo "  cluster - GaussDB 集群部署"
    echo ""
    echo "示例:"
    echo "  $0 local    # 本地部署"
    echo "  $0 vm       # 部署到虚拟机"
    exit 1
}

# 本地部署
deploy_local() {
    log "开始本地部署..."
    
    if ! command -v docker &> /dev/null; then
        err "未找到 Docker，请先安装"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        err "未找到 Docker Compose，请先安装"
    fi
    
    log "检查 Docker 版本"
    docker --version
    docker-compose --version
    
    log "停止现有容器"
    docker-compose down -v 2>/dev/null || true
    
    log "构建并启动服务"
    docker-compose up -d --build
    
    log "等待服务启动"
    sleep 10
    
    log "检查服务状态"
    docker-compose ps
    
    ok "本地部署完成！"
    echo ""
    echo "访问地址:"
    echo "  前端: http://localhost:8080"
    echo "  后端: http://localhost:8081"
}

# VM部署
deploy_vm() {
    log "开始虚拟机部署（离线模式）..."
    
    # 检查 sshpass
    if ! command -v /opt/homebrew/bin/sshpass &> /dev/null; then
        err "未找到 sshpass，请先安装: brew install hudochenkov/sshpass/sshpass"
    fi
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        if [ -f "/Applications/Docker.app/Contents/Resources/bin/docker" ]; then
            export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
        else
            err "未找到 Docker，请先安装 Docker Desktop"
        fi
    fi
    
    vm_cmd() {
        /opt/homebrew/bin/sshpass -p "$VM_PASSWORD" ssh \
            -o StrictHostKeyChecking=no \
            -o PubkeyAuthentication=no \
            -o PasswordAuthentication=yes \
            ${VM_USER}@${VM_IP} "$1"
    }
    
    log "步骤 1/7: 拉取基础镜像"
    docker pull postgres:15-alpine || err "拉取 postgres 镜像失败"
    docker pull eclipse-temurin:17-jre || err "拉取 temurin 镜像失败"
    docker pull node:18-alpine || err "拉取 node 镜像失败"
    docker pull nginx:alpine || err "拉取 nginx 镜像失败"
    docker pull maven:3.8.7-eclipse-temurin-17 || err "拉取 maven 镜像失败"
    ok "基础镜像拉取完成"
    
    log "步骤 2/7: 导出镜像"
    mkdir -p /tmp/docker-images
    docker save -o /tmp/docker-images/postgres.tar postgres:15-alpine
    docker save -o /tmp/docker-images/temurin.tar eclipse-temurin:17-jre
    docker save -o /tmp/docker-images/node.tar node:18-alpine
    docker save -o /tmp/docker-images/nginx.tar nginx:alpine
    docker save -o /tmp/docker-images/maven.tar maven:3.8.7-eclipse-temurin-17
    ok "镜像导出完成"
    
    log "步骤 3/7: 传输镜像到虚拟机"
    /opt/homebrew/bin/sshpass -p "$VM_PASSWORD" scp \
        -o StrictHostKeyChecking=no \
        -o PubkeyAuthentication=no \
        /tmp/docker-images/*.tar ${VM_USER}@${VM_IP}:/tmp/
    ok "镜像传输完成"
    
    log "步骤 4/7: 加载镜像"
    vm_cmd "docker load -i /tmp/postgres.tar"
    vm_cmd "docker load -i /tmp/temurin.tar"
    vm_cmd "docker load -i /tmp/node.tar"
    vm_cmd "docker load -i /tmp/nginx.tar"
    vm_cmd "docker load -i /tmp/maven.tar"
    vm_cmd "rm -f /tmp/*.tar"
    ok "镜像加载完成"
    
    log "步骤 5/7: 同步代码"
    vm_cmd "cd ${VM_PROJECT_DIR} && git fetch origin dev && git reset --hard origin/dev"
    ok "代码同步完成"
    
    log "步骤 6/7: 停止旧容器"
    vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml down --remove-orphans 2>/dev/null || true"
    ok "旧容器已停止"
    
    log "步骤 7/7: 启动服务"
    vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml up -d"
    ok "服务启动完成"
    
    log "等待服务就绪"
    sleep 15
    
    log "检查服务状态"
    vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml ps"
    
    # 清理本地临时文件
    rm -rf /tmp/docker-images
    
    ok "虚拟机部署完成！"
    echo ""
    echo "访问地址: http://${VM_IP}:8080"
    echo "后端API: http://${VM_IP}:8081"
}

# 集群部署
deploy_cluster() {
    log "开始 GaussDB 集群部署..."
    
    if [ ! -f "init-gaussdb-cluster.sh" ]; then
        err "未找到 init-gaussdb-cluster.sh"
    fi
    
    log "初始化 GaussDB 集群"
    bash init-gaussdb-cluster.sh
    
    log "启动应用服务"
    docker-compose -f docker-compose-vm-gaussdb.yml up -d
    
    ok "集群部署完成！"
}

# 主逻辑
MODE="${1:-}"

case "$MODE" in
    local)
        deploy_local
        ;;
    vm)
        deploy_vm
        ;;
    cluster)
        deploy_cluster
        ;;
    *)
        usage
        ;;
esac














