#!/bin/bash

set -euo pipefail

###############################################################
# Blog Circle 部署启动脚本
# 用法：
#   本地开发环境：./docker-compose-start.sh dev      # PostgreSQL + Spring Boot + Vite（直接运行）
#   虚拟机部署：./docker-compose-start.sh vm         # 容器化部署到虚拟机 10.211.55.11
###############################################################

MODE=${1:-dev}
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"

# 虚拟机配置
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
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

header() {
  echo "========================================="
  echo "   Blog Circle 容器化部署 - 启动 (${MODE})"
  echo "========================================="
  echo ""
}

require_cmd() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "未找到命令: $cmd"
    exit 1
  fi
}

echo "========================================="
echo "   Blog Circle 容器化部署脚本"
echo "========================================="
echo ""

# 检查 Docker 和 Docker Compose
if ! command -v docker &> /dev/null; then
    echo "错误: 未找到 Docker，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "错误: 未找到 Docker Compose，请先安装 Docker Compose"
    exit 1
fi

echo "1. 配置 Docker 镜像源（加速拉取镜像）..."
DAEMON_CONFIG="/etc/docker/daemon.json"
if [ ! -f "$DAEMON_CONFIG" ] || ! grep -q "registry-mirrors" "$DAEMON_CONFIG"; then
    sudo mkdir -p /etc/docker
    sudo tee "$DAEMON_CONFIG" > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com"
  ],
  "insecure-registries": [],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    echo "Docker 镜像源已配置，重启 Docker 服务..."
    sudo systemctl restart docker || sudo service docker restart || true
    sleep 10
else
    echo "Docker 镜像源已配置。"
fi

echo "2. 设置 Docker 环境变量（延长超时时间）..."
export DOCKER_CLIENT_TIMEOUT=300
export COMPOSE_HTTP_TIMEOUT=300

echo "3. 检查 Docker 版本..."
docker --version
docker-compose --version
echo ""

########################################
# 本地开发环境（PostgreSQL + Spring Boot + Vite）
########################################
run_dev() {
  header

  if [ ! -f "${ROOT_DIR}/start.sh" ]; then
    err "未找到本地启动脚本: start.sh"
    exit 1
  fi

  for c in psql createdb mvn npm; do
    require_cmd "$c"
  done

  log "1. 启动本地开发环境..."
  log "   执行 ./start.sh"
  echo ""

  # 执行现有的 start.sh 脚本
  bash "${ROOT_DIR}/start.sh"

  ok "本地开发环境启动完成"
}

vm_cmd() {
  sshpass -p "$VM_PASSWORD" \
    ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=yes \
        -o PreferredAuthentications=password -o PubkeyAuthentication=no \
        "${VM_USER}@${VM_IP}" "$1"
}

run_vm() {
  header

  for c in ssh sshpass; do
    require_cmd "$c"
  done

  log "1. 测试 SSH 连接到虚拟机..."
  if vm_cmd "echo ok" >/dev/null 2>&1; then
    ok "SSH 连接正常"
  else
    err "无法连接虚拟机 ${VM_USER}@${VM_IP}"
    exit 1
  fi
  echo ""

  log "2. 检查虚拟机项目目录..."
  vm_cmd "cd ${VM_PROJECT_DIR}" >/dev/null 2>&1 || {
    err "虚拟机目录 ${VM_PROJECT_DIR} 不存在"
    exit 1
  }
  ok "虚拟机项目目录存在"
  echo ""

  log "3. 检查和清理虚拟机端口冲突..."
  # 检查端口占用
  vm_cmd "netstat -anp 2>/dev/null | grep ':5432 ' | head -5" || vm_cmd "ss -tlnp 2>/dev/null | grep ':5432 ' | head -5" || true
  vm_cmd "netstat -anp 2>/dev/null | grep ':8080 ' | head -5" || vm_cmd "ss -tlnp 2>/dev/null | grep ':8080 ' | head -5" || true
  vm_cmd "netstat -anp 2>/dev/null | grep ':8081 ' | head -5" || vm_cmd "ss -tlnp 2>/dev/null | grep ':8081 ' | head -5" || true

  # 停止可能冲突的服务
  vm_cmd "sudo systemctl stop postgresql 2>/dev/null || true"
  vm_cmd "sudo systemctl disable postgresql 2>/dev/null || true"
  vm_cmd "sudo systemctl stop nginx 2>/dev/null || true"
  vm_cmd "sudo systemctl disable nginx 2>/dev/null || true"

  # 杀死可能占用端口的进程
  vm_cmd "sudo lsof -ti:5432 | xargs -r sudo kill -9 2>/dev/null || true"
  vm_cmd "sudo lsof -ti:8080 | xargs -r sudo kill -9 2>/dev/null || true"
  vm_cmd "sudo lsof -ti:8081 | xargs -r sudo kill -9 2>/dev/null || true"

  # 等待端口释放
  vm_cmd "sleep 3"

  ok "端口冲突清理完成"
  echo ""

  log "4. 同步最新代码到虚拟机..."
  vm_cmd "cd ${VM_PROJECT_DIR} && git fetch origin dev && git reset --hard origin/dev"
  ok "虚拟机代码同步完成"
  echo ""

  log "5. 停止旧容器..."
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose down --remove-orphans >/dev/null 2>&1 || true"
  ok "旧容器已停止"
  echo ""

  log "6. 构建并启动服务..."
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose up -d --build"
  ok "虚拟机服务已启动"
  echo ""

  log "7. 等待服务启动..."
  sleep 20
  echo ""

  log "8. 服务状态"
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose ps"
  echo ""

  log "9. 拉取关键日志"
  echo "--- 数据库 ---"
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose logs --tail=20 db" || warn "数据库日志不可用"
  echo ""
  echo "--- 后端 ---"
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose logs --tail=20 backend" || warn "后端日志不可用"
  echo ""
  echo "--- 前端 ---"
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose logs --tail=20 frontend" || warn "前端日志不可用"
  echo ""

  echo "========================================="
  ok "虚拟机部署完成"
  echo "========================================="
  echo ""
  echo "访问地址："
  echo "  前端: http://${VM_IP}:8080"
  echo "  后端: http://${VM_IP}:8081"
  echo ""
  echo "测试账号："
  echo "  用户名: admin"
  echo "  密码: admin123"
  echo ""
  echo "常用命令（在虚拟机上执行）："
  echo "  cd ${VM_PROJECT_DIR}"
  echo "  docker-compose logs -f          # 查看所有日志"
  echo "  docker-compose restart          # 重启服务"
  echo "  docker-compose down             # 停止服务"
  echo ""
}

case "$MODE" in
  dev)
    run_dev
    ;;
  vm)
    run_vm
    ;;
  *)
    err "未知模式: $MODE (支持 dev 或 vm)"
    exit 1
    ;;
esac
