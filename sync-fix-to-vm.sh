#!/bin/bash

# 快速同步修复文件到虚拟机

VM_IP="10.211.55.11"
VM_USER="root"

echo "同步修复文件到虚拟机..."
echo ""

# 同步修复后的脚本
rsync -avz \
    deploy-on-vm.sh \
    fix-docker-network.sh \
    NETWORK-FIX-GUIDE.md \
    ${VM_USER}@${VM_IP}:~/CloudCom/

echo ""
echo "✓ 文件同步完成"
echo ""
echo "下一步："
echo "  1. SSH 到虚拟机: ssh root@${VM_IP}"
echo "  2. 进入目录: cd ~/CloudCom"
echo "  3. 添加权限: chmod +x fix-docker-network.sh deploy-on-vm.sh"
echo "  4. 修复网络: ./fix-docker-network.sh"
echo "  5. 重新部署: ./deploy-on-vm.sh"
echo ""
