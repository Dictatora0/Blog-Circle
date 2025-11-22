#!/bin/bash

###############################################################
# 同步文件到虚拟机
# 将必要的配置文件和脚本同步到虚拟机
###############################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

VM_IP="10.211.55.11"
VM_USER="root"
VM_PASSWORD="747599qw@"
VM_PROJECT_DIR="/root/CloudCom"

echo ""
echo -e "${CYAN}═══ 同步文件到虚拟机 ═══${NC}"
echo ""

# 检查 sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}✗ sshpass 未安装${NC}"
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

vm_scp() {
    sshpass -p "$VM_PASSWORD" scp \
        -o StrictHostKeyChecking=no \
        -o PubkeyAuthentication=no \
        "$1" ${VM_USER}@${VM_IP}:"$2"
}

# 检查连接
echo -e "${BLUE}[1/3]${NC} 检查虚拟机连接..."
if ! vm_cmd "echo 'Connected'" &>/dev/null; then
    echo -e "${RED}✗ 无法连接到虚拟机${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 虚拟机连接正常${NC}"

# 同步配置文件
echo ""
echo -e "${BLUE}[2/3]${NC} 同步配置文件..."

# Docker Compose 配置
if [ -f "docker-compose-opengauss-cluster.yml" ]; then
    vm_scp "docker-compose-opengauss-cluster.yml" "${VM_PROJECT_DIR}/"
    echo -e "${GREEN}✓ docker-compose-opengauss-cluster.yml${NC}"
fi

# 后端配置文件
if [ -f "backend/src/main/resources/application-opengauss-cluster.yml" ]; then
    vm_cmd "mkdir -p ${VM_PROJECT_DIR}/backend/src/main/resources"
    vm_scp "backend/src/main/resources/application-opengauss-cluster.yml" \
           "${VM_PROJECT_DIR}/backend/src/main/resources/"
    echo -e "${GREEN}✓ application-opengauss-cluster.yml${NC}"
fi

# 数据库初始化脚本
if [ -f "backend/src/main/resources/db/01_init.sql" ]; then
    vm_cmd "mkdir -p ${VM_PROJECT_DIR}/backend/src/main/resources/db"
    vm_scp "backend/src/main/resources/db/01_init.sql" \
           "${VM_PROJECT_DIR}/backend/src/main/resources/db/"
    echo -e "${GREEN}✓ 01_init.sql${NC}"
fi

# 同步脚本
echo ""
echo -e "${BLUE}[3/3]${NC} 同步脚本..."

# 测试脚本
for script in scripts/full_verify.sh scripts/test-opengauss-instances.sh scripts/check_db.sh scripts/check_backend.sh scripts/check_frontend.sh; do
    if [ -f "$script" ]; then
        vm_cmd "mkdir -p ${VM_PROJECT_DIR}/scripts"
        vm_scp "$script" "${VM_PROJECT_DIR}/scripts/"
        vm_cmd "chmod +x ${VM_PROJECT_DIR}/$script"
        echo -e "${GREEN}✓ $(basename $script)${NC}"
    fi
done

echo ""
echo -e "${GREEN}✓ 同步完成${NC}"
echo ""
