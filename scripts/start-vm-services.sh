#!/bin/bash

###############################################################
# 虚拟机服务启动脚本
# 启动虚拟机上的 GaussDB、后端、前端服务
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
        echo -e "${RED}✗ 未找到 sshpass，请先安装: brew install hudochenkov/sshpass/sshpass${NC}"
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
echo "   启动虚拟机服务"
echo "========================================="
echo ""
echo "虚拟机: $VM_IP"
echo ""

# 1. 检查 GaussDB 状态并启动
echo "=== 1. 启动 GaussDB 服务 ==="
GAUSSDB_STATUS=$(vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data' 2>/dev/null || echo 'stopped'")

if echo "$GAUSSDB_STATUS" | grep -q "running"; then
    echo -e "${GREEN}✓ GaussDB 已在运行${NC}"
else
    echo "启动 GaussDB..."
    vm_cmd "su - omm -c 'gs_ctl start -D /usr/local/opengauss/data'"
    sleep 5
    echo -e "${GREEN}✓ GaussDB 启动完成${NC}"
fi
echo ""

# 2. 如果是集群模式，启动备库
echo "=== 2. 检查集群配置 ==="
if vm_cmd "[ -d /usr/local/opengauss/data_standby1 ] && echo 'exists'" | grep -q "exists"; then
    echo "检测到集群配置，启动备库..."
    
    # 启动备库1
    STANDBY1_STATUS=$(vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_standby1' 2>/dev/null || echo 'stopped'")
    if echo "$STANDBY1_STATUS" | grep -q "running"; then
        echo -e "${GREEN}✓ 备库1 已在运行${NC}"
    else
        vm_cmd "su - omm -c 'gs_ctl start -D /usr/local/opengauss/data_standby1'"
        echo -e "${GREEN}✓ 备库1 启动完成${NC}"
    fi
    
    # 启动备库2
    STANDBY2_STATUS=$(vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_standby2' 2>/dev/null || echo 'stopped'")
    if echo "$STANDBY2_STATUS" | grep -q "running"; then
        echo -e "${GREEN}✓ 备库2 已在运行${NC}"
    else
        vm_cmd "su - omm -c 'gs_ctl start -D /usr/local/opengauss/data_standby2'"
        echo -e "${GREEN}✓ 备库2 启动完成${NC}"
    fi
else
    echo "单实例模式"
fi
echo ""

# 3. 启动 Docker 服务
echo "=== 3. 启动应用服务 (Docker Compose) ==="
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml up -d"
echo -e "${GREEN}✓ Docker 服务启动完成${NC}"
echo ""

# 4. 等待服务就绪
echo "=== 4. 等待服务就绪 ==="
sleep 10
echo -e "${GREEN}✓ 等待完成${NC}"
echo ""

# 5. 检查服务状态
echo "=== 5. 检查服务状态 ==="
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml ps"
echo ""

# 6. 健康检查
echo "=== 6. 健康检查 ==="
echo -n "检查后端服务: "
if curl -s "http://${VM_IP}:8081/actuator/health" | grep -q "UP"; then
    echo -e "${GREEN}✓ 后端服务正常${NC}"
else
    echo -e "${YELLOW}⚠ 后端服务可能未就绪，请稍后重试${NC}"
fi

echo -n "检查前端服务: "
if curl -s "http://${VM_IP}:8080" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 前端服务正常${NC}"
else
    echo -e "${YELLOW}⚠ 前端服务可能未就绪，请稍后重试${NC}"
fi
echo ""

echo "========================================="
echo -e "${GREEN}   虚拟机服务启动完成${NC}"
echo "========================================="
echo ""
echo "访问地址:"
echo "  前端: http://${VM_IP}:8080"
echo "  后端: http://${VM_IP}:8081"
echo "  GaussDB: ${VM_IP}:5432"
echo ""
echo "查看日志:"
echo "  ssh ${VM_USER}@${VM_IP}"
echo "  cd ${VM_PROJECT_DIR}"
echo "  docker-compose -f docker-compose-vm-gaussdb.yml logs -f"
echo ""
