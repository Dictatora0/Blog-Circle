#!/bin/bash

###############################################################
# Blog Circle 虚拟机停止脚本
# 通过 SSH 在虚拟机上停止服务
###############################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# 加载环境变量（兼容包含空格的值）
load_env_file() {
    local env_file="$1"
    [ -f "$env_file" ] || return

    local tmp_env
    tmp_env=$(mktemp 2>/dev/null || mktemp -t env)

    awk 'BEGIN {FS=OFS="="}
        /^JAVA_TOOL_OPTIONS=/ {
            sub(/^JAVA_TOOL_OPTIONS=/,"")
            printf("JAVA_TOOL_OPTIONS=\"%s\"\n", $0)
            next
        }
        {print}
    ' "$env_file" > "$tmp_env"

    set -a
    # shellcheck disable=SC1090
    source "$tmp_env"
    set +a
    rm -f "$tmp_env"
}

load_env_file ".env"

# 虚拟机配置（支持环境变量覆盖）
VM_IP="${VM_IP:-${REMOTE_VM_IP:-10.211.55.11}}"
VM_USER="${VM_USER:-root}"
VM_PASSWORD="${VM_PASSWORD:-${REMOTE_VM_PASSWORD:-password}}"
VM_PROJECT_DIR="${VM_PROJECT_DIR:-/root/CloudCom}"
# 使用兼容旧版 Docker Compose 的配置文件
COMPOSE_FILE="${COMPOSE_FILE:-infra/docker-compose/opengauss-cluster-legacy.yml}"

echo ""
echo -e "${YELLOW}VM System Shutdown${NC}"
echo ""

# 检查 sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}sshpass 未安装${NC}"
    exit 1
fi

# SSH 命令封装
vm_cmd() {
    sshpass -p "$VM_PASSWORD" ssh \
        -o StrictHostKeyChecking=no \
        -o PubkeyAuthentication=no \
        -o PasswordAuthentication=yes \
        ${VM_USER}@${VM_IP} "$1"
}

# 检查连接
echo -e "${YELLOW}[1/3]${NC} 检查虚拟机连接..."
if ! vm_cmd "echo 'Connected'" &>/dev/null; then
    echo -e "${RED}无法连接到虚拟机 ${VM_IP}${NC}"
    exit 1
fi
echo -e "${GREEN}虚拟机连接正常${NC}"

# 检查服务状态
echo ""
echo -e "${YELLOW}[2/3]${NC} 检查服务状态..."
if ! vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} ps | grep -q 'Up'"; then
    echo -e "${GREEN}没有运行中的服务${NC}"
    exit 0
fi

# 停止服务
echo ""
echo -e "${YELLOW}[3/3]${NC} 停止服务..."
echo "  • 停止前端服务..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} stop frontend"

echo "  • 停止后端服务..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} stop backend"

echo "  • 停止数据库集群..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} stop opengauss-standby2"
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} stop opengauss-standby1"
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} stop opengauss-primary"

# 移除容器
echo "  • 清理容器..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} down"

echo ""
echo -e "${BOLD}${GREEN}虚拟机服务已停止${NC}"
echo ""
echo -e "${BOLD}提示：${NC}"
echo "  • 数据已保留在虚拟机的 Docker volumes 中"
echo "  • 重新启动：${CYAN}./start-vm.sh${NC}"
echo "  • 在虚拟机上查看日志：${CYAN}ssh ${VM_USER}@${VM_IP}${NC}"
echo ""
