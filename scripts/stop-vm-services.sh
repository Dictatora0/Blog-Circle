#!/bin/bash

###############################################################
# 虚拟机服务停止脚本
# 停止虚拟机上的后端、前端、GaussDB 服务
###############################################################

set -e

VM_IP="10.211.55.11"
VM_USER="root"
VM_PASSWORD="747599qw@"
VM_PROJECT_DIR="CloudCom"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查 sshpass
if ! command -v sshpass &> /dev/null; then
    if [ -f "/opt/homebrew/bin/sshpass" ]; then
        SSHPASS="/opt/homebrew/bin/sshpass"
    else
        echo -e "${RED}[FAIL] 未找到 sshpass，请先安装: brew install hudochenkov/sshpass/sshpass${NC}"
        exit 1
    fi
else
    SSHPASS="sshpass"
fi

vm_cmd() {
    $SSHPASS -p "$VM_PASSWORD" ssh \
        -o StrictHostKeyChecking=no \
        -o PubkeyAuthentication=no \
        -o PasswordAuthentication=yes \
        ${VM_USER}@${VM_IP} "$1"
}

echo "========================================="
echo "   停止虚拟机服务"
echo "========================================="
echo ""
echo "虚拟机: $VM_IP"
echo ""

# 1. 停止 Docker 服务
echo "=== 1. 停止应用服务 (Docker Compose) ==="
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml down" 2>/dev/null || echo "Docker 服务已停止或不存在"
echo -e "${GREEN}[OK] Docker 服务已停止${NC}"
echo ""

# 2. 停止 GaussDB 集群（如果存在）
echo "=== 2. 停止 GaussDB 集群 ==="
if vm_cmd "[ -d /usr/local/opengauss/data_standby2 ] && echo 'exists'" | grep -q "exists"; then
    echo "检测到集群配置，停止所有实例..."
    
    # 停止备库2
    vm_cmd "su - omm -c 'gs_ctl stop -D /usr/local/opengauss/data_standby2' 2>/dev/null || echo 'stopped'"
    echo -e "${GREEN}[OK] 备库2 已停止${NC}"
    
    # 停止备库1
    vm_cmd "su - omm -c 'gs_ctl stop -D /usr/local/opengauss/data_standby1' 2>/dev/null || echo 'stopped'"
    echo -e "${GREEN}[OK] 备库1 已停止${NC}"
fi

# 3. 停止主库
echo "停止主库..."
vm_cmd "su - omm -c 'gs_ctl stop -D /usr/local/opengauss/data' 2>/dev/null || echo 'stopped'"
echo -e "${GREEN}[OK] 主库已停止${NC}"
echo ""

# 4. 验证所有服务已停止
echo "=== 3. 验证服务状态 ==="
echo -n "检查 Docker 容器: "
CONTAINER_COUNT=$(vm_cmd "docker ps -q | wc -l" 2>/dev/null | tr -d ' ')
if [ "$CONTAINER_COUNT" == "0" ]; then
    echo -e "${GREEN}[OK] 无运行中的容器${NC}"
else
    echo -e "${YELLOW}[WARN] 仍有 $CONTAINER_COUNT 个容器在运行${NC}"
fi

echo -n "检查 GaussDB 进程: "
GAUSSDB_COUNT=$(vm_cmd "ps aux | grep gaussdb | grep -v grep | wc -l" 2>/dev/null | tr -d ' ')
if [ "$GAUSSDB_COUNT" == "0" ]; then
    echo -e "${GREEN}[OK] GaussDB 已完全停止${NC}"
else
    echo -e "${YELLOW}[WARN] 仍有 $GAUSSDB_COUNT 个 GaussDB 进程在运行${NC}"
fi
echo ""

echo "========================================="
echo -e "${GREEN}   虚拟机服务停止完成${NC}"
echo "========================================="
echo ""
echo "重新启动服务:"
echo "  ./scripts/start-vm-services.sh"
echo ""
