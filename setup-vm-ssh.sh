#!/bin/bash

# 配置 VM SSH 密钥认证脚本

VM_IP="10.211.55.11"
VM_USER="parallels"  # 或 root

echo "配置 SSH 密钥认证到 VM ${VM_IP}..."

# 1. 检查本地是否有 SSH 密钥
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "生成 SSH 密钥..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
fi

# 2. 复制公钥到 VM
echo "复制公钥到 VM（需要输入 VM 密码）..."
ssh-copy-id -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP}

# 3. 测试连接
echo "测试 SSH 连接..."
if ssh -o ConnectTimeout=5 ${VM_USER}@${VM_IP} "echo 'SSH 密钥认证成功'"; then
    echo "✓ SSH 配置成功！"
    echo ""
    echo "现在可以无密码连接到 VM："
    echo "  ssh ${VM_USER}@${VM_IP}"
else
    echo "✗ SSH 配置失败"
    exit 1
fi
