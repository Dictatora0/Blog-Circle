#!/bin/bash

###############################################################
# 同步脚本到虚拟机
# 将 scripts 目录和根目录脚本传输到虚拟机
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

echo "========================================="
echo "   同步脚本到虚拟机"
echo "========================================="
echo ""
echo "目标虚拟机: $VM_IP"
echo "目标目录: ~/$VM_PROJECT_DIR"
echo ""

# 1. 检查虚拟机连接
echo "=== 1. 检查虚拟机连接 ==="
if $SSHPASS -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${VM_USER}@${VM_IP} "echo 'connected'" 2>/dev/null | grep -q "connected"; then
    echo -e "${GREEN}✓ 虚拟机连接正常${NC}"
else
    echo -e "${RED}✗ 无法连接到虚拟机${NC}"
    exit 1
fi
echo ""

# 2. 在虚拟机上创建 scripts 目录
echo "=== 2. 创建目标目录 ==="
$SSHPASS -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "mkdir -p ${VM_PROJECT_DIR}/scripts"
echo -e "${GREEN}✓ 目录已创建${NC}"
echo ""

# 3. 同步 scripts 目录下的所有脚本
echo "=== 3. 同步 scripts 目录 ==="
if [ -d "scripts" ]; then
    SCRIPT_COUNT=$(find scripts -name "*.sh" -type f | wc -l | tr -d ' ')
    echo "找到 $SCRIPT_COUNT 个脚本文件"
    echo ""
    
    for script in scripts/*.sh; do
        if [ -f "$script" ]; then
            echo -n "  同步: $(basename $script) ... "
            if $SSHPASS -p "$VM_PASSWORD" scp -o StrictHostKeyChecking=no "$script" ${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/scripts/ > /dev/null 2>&1; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗ 失败${NC}"
            fi
        fi
    done
    
    # 同步 README
    if [ -f "scripts/README.md" ]; then
        echo -n "  同步: README.md ... "
        $SSHPASS -p "$VM_PASSWORD" scp -o StrictHostKeyChecking=no scripts/README.md ${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/scripts/ > /dev/null 2>&1
        echo -e "${GREEN}✓${NC}"
    fi
else
    echo -e "${RED}✗ 本地 scripts 目录不存在${NC}"
    exit 1
fi
echo ""

# 4. 同步根目录的部署脚本
echo "=== 4. 同步根目录脚本 ==="
ROOT_SCRIPTS=(
    "deploy.sh"
    "init-gaussdb-cluster.sh"
    "setup-gaussdb-single-vm-cluster.sh"
    "start.sh"
    "stop.sh"
    "test.sh"
    "test-vm-apis.sh"
)

for script in "${ROOT_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo -n "  同步: $script ... "
        if $SSHPASS -p "$VM_PASSWORD" scp -o StrictHostKeyChecking=no "$script" ${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/ > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ 失败${NC}"
        fi
    fi
done
echo ""

# 5. 设置脚本权限
echo "=== 5. 设置脚本执行权限 ==="
$SSHPASS -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "cd ${VM_PROJECT_DIR} && chmod +x scripts/*.sh *.sh 2>/dev/null || true"
echo -e "${GREEN}✓ 权限已设置${NC}"
echo ""

# 6. 验证同步结果
echo "=== 6. 验证同步结果 ==="
VM_SCRIPT_COUNT=$($SSHPASS -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "find ${VM_PROJECT_DIR}/scripts -name '*.sh' -type f | wc -l" 2>/dev/null | tr -d ' ')
echo "虚拟机上的脚本数量: $VM_SCRIPT_COUNT"
echo ""

# 7. 列出虚拟机上的脚本
echo "=== 7. 虚拟机上的脚本列表 ==="
$SSHPASS -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "ls -lh ${VM_PROJECT_DIR}/scripts/*.sh" 2>/dev/null || echo "无法列出脚本"
echo ""

echo "========================================="
echo -e "${GREEN}   同步完成${NC}"
echo "========================================="
echo ""
echo "现在可以在虚拟机上执行脚本了："
echo "  ssh ${VM_USER}@${VM_IP}"
echo "  cd ${VM_PROJECT_DIR}"
echo "  ./scripts/verify-gaussdb-cluster.sh"
echo ""
