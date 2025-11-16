#!/bin/bash

set -euo pipefail

###############################################################
# Blog Circle 部署停止脚本
# 用法：
#   本地开发环境：./docker-compose-stop.sh dev      # PostgreSQL + Spring Boot + Vite
#   本地部署：./docker-compose-stop.sh             # 默认 local (Docker Compose)
#   远程部署：./docker-compose-stop.sh remote      # 依赖 ssh/sshpass
###############################################################

MODE=${1:-local}
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"

# 远程配置，可通过环境变量覆盖
SERVER_IP=${SERVER_IP:-"10.211.55.11"}
SERVER_USER=${SERVER_USER:-"root"}
SERVER_PASSWORD=${SERVER_PASSWORD:-"747599qw@"}
SERVER_PROJECT_DIR=${SERVER_PROJECT_DIR:-"CloudCom"}

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

########################################
# 本地停止
########################################
run_local() {
  header

  if [ ! -f "$COMPOSE_FILE" ]; then
    err "未找到 docker-compose.yml，请在项目根目录执行"
    exit 1
  fi

  require_cmd "docker-compose"

  log "1. 停止所有容器..."
  docker-compose down --remove-orphans
  ok "容器已停止"
  echo ""

  log "2. 检查容器状态..."
  docker-compose ps
  echo ""

  echo "========================================="
  ok "本地服务已停止"
  echo "========================================="
  echo ""
  echo "数据卷已保留，重新启动时可恢复数据"
  echo ""
  echo "如需完全清理数据卷，执行："
  echo "  docker-compose down -v"
  echo ""
}

########################################
# 远程停止
########################################
remote_cmd() {
  sshpass -p "$SERVER_PASSWORD" \
    ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=yes \
        -o PreferredAuthentications=password -o PubkeyAuthentication=no \
        "${SERVER_USER}@${SERVER_IP}" "$1"
}

run_remote() {
  header

  for c in ssh sshpass; do
    require_cmd "$c"
  done

  log "1. 测试 SSH 连接..."
  if remote_cmd "echo ok" >/dev/null 2>&1; then
    ok "SSH 连接正常"
  else
    err "无法连接远程服务器 ${SERVER_USER}@${SERVER_IP}"
    exit 1
  fi
  echo ""

  log "2. 检查项目目录..."
  remote_cmd "cd ${SERVER_PROJECT_DIR}" >/dev/null 2>&1 || {
    err "远程目录 ${SERVER_PROJECT_DIR} 不存在"
    exit 1
  }
  ok "远程项目目录存在"
  echo ""

  log "3. 停止所有容器..."
  remote_cmd "cd ${SERVER_PROJECT_DIR} && docker-compose down --remove-orphans"
  ok "远程容器已停止"
  echo ""

  log "4. 检查容器状态..."
  remote_cmd "cd ${SERVER_PROJECT_DIR} && docker-compose ps"
  echo ""

  echo "========================================="
  ok "远程服务已停止"
  echo "========================================="
  echo ""
  echo "数据卷已保留，重新启动时可恢复数据"
  echo ""
  echo "如需完全清理数据卷，在服务器上执行："
  echo "  cd ${SERVER_PROJECT_DIR}"
  echo "  docker-compose down -v"
  echo ""
}

case "$MODE" in
  dev)
    run_dev
    ;;
  local)
    run_local
    ;;
  remote)
    run_remote
    ;;
  *)
    err "未知模式: $MODE (支持 dev、local 或 remote)"
    exit 1
    ;;
esac
