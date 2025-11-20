#!/bin/bash

set -euo pipefail

###############################################################
# Blog Circle 部署启动脚本
# 用法：
#   本地开发环境：./docker-compose-start.sh dev      # PostgreSQL + Spring Boot + Vite（直接运行）
#   虚拟机部署：./docker-compose-start.sh vm         # 容器化部署到虚拟机 10.211.55.11，使用虚拟机上的 GaussDB 集群
###############################################################

MODE=${1:-dev}
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"
VM_COMPOSE_FILE="${ROOT_DIR}/docker-compose-vm-gaussdb.yml"

# 本地 Docker 命令路径
DOCKER_CMD="/usr/local/bin/docker"
COMPOSE_CMD="/usr/local/bin/docker-compose"

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
if ! command -v "$DOCKER_CMD" &> /dev/null; then
    echo "错误: 未找到 Docker，请先安装 Docker"
    exit 1
fi

if ! command -v "$COMPOSE_CMD" &> /dev/null; then
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
"$DOCKER_CMD" --version
"$COMPOSE_CMD" --version
echo ""

###############################################################
# 检查依赖
###############################################################
check_dependencies() {
  # 检查 Docker 命令（使用已设置的变量）
  if ! command -v "$DOCKER_CMD" &> /dev/null; then
    err "未找到命令: $DOCKER_CMD"
    exit 1
  fi
  
  if ! command -v "$COMPOSE_CMD" &> /dev/null; then
    err "未找到命令: $COMPOSE_CMD"
    exit 1
  fi
  
  # 检查 sshpass，支持多个可能的路径
  if command -v sshpass &> /dev/null; then
    SSHPASS_CMD="sshpass"
  elif [ -f "/opt/homebrew/bin/sshpass" ]; then
    SSHPASS_CMD="/opt/homebrew/bin/sshpass"
  elif [ -f "/usr/local/bin/sshpass" ]; then
    SSHPASS_CMD="/usr/local/bin/sshpass"
  else
    err "未找到 sshpass 命令"
    exit 1
  fi
}

check_dependencies

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
  # 使用密码认证
  export SSHPASS="$VM_PASSWORD"
  $SSHPASS_CMD -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o PasswordAuthentication=yes \
      -o PreferredAuthentications=password \
      -o PubkeyAuthentication=no \
      "${VM_USER}@${VM_IP}" "$@"
}

run_vm() {
  header

  for c in ssh; do
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

  log "3. 检查虚拟机 GaussDB 一主二备集群状态..."
  
  # 检查主库
  if vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_primary' 2>/dev/null | grep -q 'server is running'"; then
    ok "GaussDB 主库 (端口 5432) 正在运行"
  else
    warn "GaussDB 主库未运行，尝试启动..."
    if vm_cmd "su - omm -c 'gs_ctl start -D /usr/local/opengauss/data_primary' 2>&1"; then
      ok "主库启动成功"
      sleep 5
    else
      err "主库启动失败！请检查数据目录和配置"
      warn "可能需要先停止所有实例，然后按顺序重启"
      warn "手动操作：ssh root@10.211.55.11"
      warn "  su - omm"
      warn "  gs_ctl stop -D /usr/local/opengauss/data_primary"
      warn "  gs_ctl stop -D /usr/local/opengauss/data_standby1"
      warn "  gs_ctl stop -D /usr/local/opengauss/data_standby2"
      warn "  gs_ctl start -D /usr/local/opengauss/data_primary"
      warn "继续部署应用..."
    fi
  fi
  
  # 检查备库1
  if vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_standby1' 2>/dev/null | grep -q 'server is running'"; then
    ok "GaussDB 备库1 (端口 5433) 正在运行"
  else
    warn "GaussDB 备库1未运行，尝试启动..."
    vm_cmd "su - omm -c 'gs_ctl start -D /usr/local/opengauss/data_standby1' 2>&1" || warn "启动备库1失败"
  fi
  
  # 检查备库2
  if vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_standby2' 2>/dev/null | grep -q 'server is running'"; then
    ok "GaussDB 备库2 (端口 5434) 正在运行"
  else
    warn "GaussDB 备库2未运行，尝试启动..."
    vm_cmd "su - omm -c 'gs_ctl start -D /usr/local/opengauss/data_standby2' 2>&1" || warn "启动备库2失败"
  fi
  
  # 检查 Web 端口冲突
  log "检查 Web 服务端口..."
  vm_cmd "netstat -anp 2>/dev/null | grep ':8080 ' | head -5" || vm_cmd "ss -tlnp 2>/dev/null | grep ':8080 ' | head -5" || true
  vm_cmd "netstat -anp 2>/dev/null | grep ':8081 ' | head -5" || vm_cmd "ss -tlnp 2>/dev/null | grep ':8081 ' | head -5" || true

  # 停止可能冲突的 Web 服务
  vm_cmd "sudo systemctl stop nginx 2>/dev/null || true"
  vm_cmd "sudo systemctl disable nginx 2>/dev/null || true"

  # 杀死可能占用 Web 端口的进程（不包括 GaussDB 端口）
  vm_cmd "sudo lsof -ti:8080 | xargs -r sudo kill -9 2>/dev/null || true"
  vm_cmd "sudo lsof -ti:8081 | xargs -r sudo kill -9 2>/dev/null || true"

  # 等待端口释放
  vm_cmd "sleep 3"

  ok "GaussDB 集群检查完成"
  echo ""

  log "4. 同步最新代码到虚拟机..."
  vm_cmd "cd ${VM_PROJECT_DIR} && git fetch origin dev 2>&1 && \
    if git diff --quiet HEAD origin/dev; then \
      echo '本地代码已是最新'; \
    else \
      echo '检测到远程更新'; \
      if git status --porcelain | grep -q .; then \
        echo '本地有未提交的更改，保留本地代码'; \
        git merge --no-edit origin/dev 2>&1 || echo '合并失败，保留本地代码'; \
      else \
        echo '本地无未提交的更改，更新到最新'; \
        git reset --hard origin/dev; \
      fi; \
    fi"
  ok "虚拟机代码同步完成"
  
  # 确保必要的文件存在
  log "4.5. 检查并同步必要文件..."
  export SSHPASS="$VM_PASSWORD"
  
  # 同步 docker-compose-vm-gaussdb.yml
  if ! vm_cmd "test -f ${VM_PROJECT_DIR}/docker-compose-vm-gaussdb.yml"; then
    log "docker-compose-vm-gaussdb.yml 不存在，从本地复制..."
    $SSHPASS_CMD -e scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o PasswordAuthentication=yes -o PreferredAuthentications=password -o PubkeyAuthentication=no \
        "${ROOT_DIR}/docker-compose-vm-gaussdb.yml" "${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/" 2>/dev/null || true
  fi
  
  # 同步 fix-docker-network.sh
  if ! vm_cmd "test -f ${VM_PROJECT_DIR}/fix-docker-network.sh"; then
    log "fix-docker-network.sh 不存在，从本地复制..."
    $SSHPASS_CMD -e scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o PasswordAuthentication=yes -o PreferredAuthentications=password -o PubkeyAuthentication=no \
        "${ROOT_DIR}/fix-docker-network.sh" "${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/" 2>/dev/null || true
  fi
  
  ok "必要文件检查完成"
  echo ""

  log "5. 停止旧容器..."
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml down --remove-orphans >/dev/null 2>&1 || true"
  ok "旧容器已停止"
  echo ""

  log "6. 启动服务（使用虚拟机 GaussDB 集群）..."
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml up -d"
  ok "虚拟机服务已启动（后端连接到 GaussDB 集群）"
  echo ""

  log "7. 等待服务启动..."
  sleep 20
  echo ""

  log "8. 修复 Docker 网络问题..."
  vm_cmd "cd ${VM_PROJECT_DIR} && bash fix-docker-network.sh" || warn "网络修复失败，前端可能需要手动重启"
  echo ""
  
  log "8.5. 重启前端服务..."
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml up -d frontend"
  ok "前端服务已重启"
  echo ""

  log "9. 服务状态"
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml ps"
  echo ""

  log "10. 验证 GaussDB 集群状态"
  echo "--- 主库状态 (data_primary) ---"
  vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_primary'" || warn "无法查询主库状态"
  echo ""
  echo "--- 备库1状态 (data_standby1) ---"
  vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_standby1'" || warn "无法查询备库1状态"
  echo ""
  echo "--- 备库2状态 (data_standby2) ---"
  vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_standby2'" || warn "无法查询备库2状态"
  echo ""
  
  log "验证主库复制连接"
  vm_cmd "su - omm -c \"gsql -d blog_db -p 5432 -c 'SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;' 2>/dev/null\"" || warn "无法查询复制状态（可能主库未运行）"
  echo ""

  log "11. 拉取应用日志"
  echo "--- 后端 ---"
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml logs --tail=20 backend" || warn "后端日志不可用"
  echo ""
  echo "--- 前端 ---"
  vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml logs --tail=20 frontend" || warn "前端日志不可用"
  echo ""

  echo "========================================="
  ok "虚拟机部署完成"
  echo "========================================="
  echo ""
  echo "访问地址："
  echo "  前端: http://${VM_IP}:8080"
  echo "  后端: http://${VM_IP}:8081"
  echo ""
  echo "GaussDB 集群："
  echo "  主库: ${VM_IP}:5432 (读写)"
  echo "  备库1: ${VM_IP}:5433 (只读)"
  echo "  备库2: ${VM_IP}:5434 (只读)"
  echo "  数据库: blog_db"
  echo "  用户: bloguser / 747599qw@"
  echo ""
  echo "测试账号："
  echo "  用户名: admin"
  echo "  密码: admin123"
  echo ""
  echo "常用命令（在虚拟机上执行）："
  echo "  cd ${VM_PROJECT_DIR}"
  echo "  docker-compose -f docker-compose-vm-gaussdb.yml logs -f          # 查看应用日志"
  echo "  docker-compose -f docker-compose-vm-gaussdb.yml restart          # 重启应用服务"
  echo "  docker-compose -f docker-compose-vm-gaussdb.yml down             # 停止应用服务"
  echo ""
  echo "GaussDB 管理命令："
  echo "  su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_primary'   # 查看主库状态"
  echo "  su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_standby1'  # 查看备库1状态"
  echo "  su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_standby2'  # 查看备库2状态"
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
