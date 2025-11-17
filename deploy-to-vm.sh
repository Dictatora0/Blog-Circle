#!/bin/bash

set -euo pipefail

###############################################################
# Blog Circle 虚拟机部署脚本（离线镜像传输方案）
# 解决虚拟机无法访问Docker Hub的问题
###############################################################

VM_IP="10.211.55.11"
VM_USER="root"
VM_PASSWORD="747599qw@"
VM_PROJECT_DIR="CloudCom"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

echo "========================================="
echo "   Blog Circle 虚拟机部署（离线模式）"
echo "========================================="
echo ""

# 检查 sshpass
if ! command -v /opt/homebrew/bin/sshpass &> /dev/null; then
    err "未找到 sshpass，请先安装: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

# 检查 Docker
if ! command -v docker &> /dev/null; then
    if [ -f "/Applications/Docker.app/Contents/Resources/bin/docker" ]; then
        export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
    else
        err "未找到 Docker，请先安装 Docker Desktop"
        exit 1
    fi
fi

vm_cmd() {
    /opt/homebrew/bin/sshpass -p "$VM_PASSWORD" ssh \
        -o StrictHostKeyChecking=no \
        -o PubkeyAuthentication=no \
        -o PasswordAuthentication=yes \
        ${VM_USER}@${VM_IP} "$1"
}

log "步骤 1/7: 拉取基础镜像到本地..."
docker pull postgres:15-alpine || { err "拉取 postgres 镜像失败"; exit 1; }
docker pull eclipse-temurin:17-jre || { err "拉取 temurin 镜像失败"; exit 1; }
docker pull node:18-alpine || { err "拉取 node 镜像失败"; exit 1; }
docker pull nginx:alpine || { err "拉取 nginx 镜像失败"; exit 1; }
docker pull maven:3.8.7-eclipse-temurin-17 || { err "拉取 maven 镜像失败"; exit 1; }
ok "基础镜像拉取完成"
echo ""

log "步骤 2/7: 导出基础镜像..."
mkdir -p /tmp/docker-images
docker save -o /tmp/docker-images/postgres.tar postgres:15-alpine
docker save -o /tmp/docker-images/temurin.tar eclipse-temurin:17-jre
docker save -o /tmp/docker-images/node.tar node:18-alpine
docker save -o /tmp/docker-images/nginx.tar nginx:alpine
docker save -o /tmp/docker-images/maven.tar maven:3.8.7-eclipse-temurin-17
ok "镜像导出完成"
echo ""

log "步骤 3/7: 传输镜像到虚拟机..."
/opt/homebrew/bin/sshpass -p "$VM_PASSWORD" scp \
    -o StrictHostKeyChecking=no \
    -o PubkeyAuthentication=no \
    /tmp/docker-images/*.tar ${VM_USER}@${VM_IP}:/tmp/
ok "镜像传输完成"
echo ""

log "步骤 4/7: 在虚拟机上加载镜像..."
vm_cmd "docker load -i /tmp/postgres.tar"
vm_cmd "docker load -i /tmp/temurin.tar"
vm_cmd "docker load -i /tmp/node.tar"
vm_cmd "docker load -i /tmp/nginx.tar"
vm_cmd "docker load -i /tmp/maven.tar"
vm_cmd "rm -f /tmp/*.tar"
ok "镜像加载完成"
echo ""

log "步骤 5/7: 同步代码到虚拟机..."
vm_cmd "cd ${VM_PROJECT_DIR} && git fetch origin dev && git reset --hard origin/dev"
ok "代码同步完成"
echo ""

log "步骤 6/7: 停止旧容器..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose down --remove-orphans 2>/dev/null || true"
ok "旧容器已停止"
echo ""

log "步骤 7/7: 构建并启动服务..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose up -d --build"
ok "服务启动完成"
echo ""

log "等待服务就绪..."
sleep 10
echo ""

log "检查服务状态..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose ps"
echo ""

ok "========================================="
ok "   部署完成！"
ok "========================================="
ok "访问地址: http://${VM_IP}:8080"
ok "后端API: http://${VM_IP}:8081"
echo ""

# 清理本地临时文件
rm -rf /tmp/docker-images
