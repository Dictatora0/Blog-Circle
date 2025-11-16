#!/bin/bash

set -euo pipefail

###############################################################
# Blog Circle 部署停止脚本
# 用法：
#   本地开发环境：./docker-compose-stop.sh dev      # 停止 PostgreSQL + Spring Boot + Vite
#   虚拟机部署：./docker-compose-stop.sh vm         # 停止虚拟机容器环境
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
  echo "   Blog Circle 容器化部署 - 停止 (${MODE})"
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

########################################
# 本地开发环境停止（PostgreSQL + Spring Boot + Vite）
########################################
run_dev() {
  header

  if [ ! -f "${ROOT_DIR}/stop.sh" ]; then
    err "未找到本地停止脚本: stop.sh"
    exit 1
  fi

  require_cmd "pkill"

  log "1. 停止本地开发环境..."
  log "   执行 ./stop.sh"
  echo ""

  # 执行现有的 stop.sh 脚本
  bash "${ROOT_DIR}/stop.sh"

  ok "本地开发环境停止完成"
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

  log "3. 停止所有容器..."
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose down --remove-orphans"
  ok "虚拟机容器已停止"
  echo ""

  log "4. 检查容器状态..."
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose ps"
  echo ""

  echo "========================================="
  ok "虚拟机服务已停止"
  echo "========================================="
  echo ""
  echo "数据卷已保留，重新启动时可恢复数据"
  echo ""
  echo "如需完全清理数据卷，在虚拟机上执行："
  echo "  cd ${VM_PROJECT_DIR}"
  echo "  docker-compose down -v"
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
