#!/bin/bash

set -euo pipefail

###############################################################
# Blog Circle 部署启动脚本
# 用法：
#   本地开发环境：./docker-compose-start.sh dev      # PostgreSQL + Spring Boot + Vite
#   本地部署：./docker-compose-start.sh             # 默认 local (Docker Compose)
#   远程部署：./docker-compose-start.sh remote      # 依赖 ssh/sshpass
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

########################################
# 本地部署
########################################
run_local() {
  header

  if [ ! -f "$COMPOSE_FILE" ]; then
    err "未找到 docker-compose.yml，请在项目根目录执行"
    exit 1
  fi

  for c in git docker docker-compose; do
    require_cmd "$c"
  done

  log "1. 更新代码 (dev 分支)..."
  git fetch origin dev
  git pull origin dev
  ok "代码已同步"
  echo ""

  log "2. 停止旧容器..."
  docker-compose down --remove-orphans >/dev/null 2>&1 || true
  ok "旧容器已停止"
  echo ""

  log "3. 构建并启动服务..."
  docker-compose up -d --build
  echo ""

  log "4. 等待服务启动..."
  sleep 12
  ok "服务已启动"
  echo ""

  log "5. 服务状态"
  docker-compose ps
  echo ""

  log "6. 查看关键日志 (最后20行)"
  echo "--- 数据库 ---"
  docker-compose logs --tail=20 db || warn "数据库日志不可用"
  echo ""
  echo "--- 后端 ---"
  docker-compose logs --tail=20 backend || warn "后端日志不可用"
  echo ""
  echo "--- 前端 ---"
  docker-compose logs --tail=20 frontend || warn "前端日志不可用"
  echo ""

  echo "========================================="
  ok "本地部署完成"
  echo "========================================="
  echo ""
  echo "访问地址："
  echo "  前端: http://localhost:8080"
  echo "  后端: http://localhost:8081"
  echo ""
  echo "测试账号："
  echo "  用户名: admin"
  echo "  密码: admin123"
  echo ""
  echo "常用命令："
  echo "  查看日志: docker-compose logs -f"
  echo "  停止服务: docker-compose down"
  echo "  重启服务: docker-compose restart"
  echo ""
}

########################################
# 远程部署
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

  log "3. 同步最新代码..."
  remote_cmd "cd ${SERVER_PROJECT_DIR} && git fetch origin dev && git reset --hard origin/dev"
  ok "远程代码同步完成"
  echo ""

  log "4. 停止旧容器..."
  remote_cmd "cd ${SERVER_PROJECT_DIR} && docker-compose down --remove-orphans >/dev/null 2>&1 || true"
  ok "旧容器已停止"
  echo ""

  log "5. 构建并启动服务..."
  remote_cmd "cd ${SERVER_PROJECT_DIR} && docker-compose up -d --build"
  ok "远程服务已启动"
  echo ""

  log "6. 等待服务启动..."
  sleep 12
  echo ""

  log "7. 服务状态"
  remote_cmd "cd ${SERVER_PROJECT_DIR} && docker-compose ps"
  echo ""

  log "8. 拉取关键日志"
  echo "--- 数据库 ---"
  remote_cmd "cd ${SERVER_PROJECT_DIR} && docker-compose logs --tail=20 db" || warn "数据库日志不可用"
  echo ""
  echo "--- 后端 ---"
  remote_cmd "cd ${SERVER_PROJECT_DIR} && docker-compose logs --tail=20 backend" || warn "后端日志不可用"
  echo ""
  echo "--- 前端 ---"
  remote_cmd "cd ${SERVER_PROJECT_DIR} && docker-compose logs --tail=20 frontend" || warn "前端日志不可用"
  echo ""

  echo "========================================="
  ok "远程部署完成"
  echo "========================================="
  echo ""
  echo "访问地址："
  echo "  前端: http://${SERVER_IP}:8080"
  echo "  后端: http://${SERVER_IP}:8081"
  echo ""
  echo "测试账号："
  echo "  用户名: admin"
  echo "  密码: admin123"
  echo ""
  echo "常用命令（在服务器上执行）："
  echo "  cd ${SERVER_PROJECT_DIR}"
  echo "  docker-compose logs -f          # 查看所有日志"
  echo "  docker-compose restart          # 重启服务"
  echo "  docker-compose down             # 停止服务"
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
