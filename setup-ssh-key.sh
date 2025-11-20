#!/bin/bash

# 配置 SSH 免密登录脚本

echo "正在配置 SSH 免密登录到 10.211.55.11..."

# 检查本地是否有 SSH 密钥
if [ ! -f ~/.ssh/id_ed25519.pub ]; then
    echo "错误: 未找到 SSH 公钥 ~/.ssh/id_ed25519.pub"
    exit 1
fi

# 读取公钥
PUBLIC_KEY=$(cat ~/.ssh/id_ed25519.pub)

echo "请在虚拟机上执行以下命令："
echo ""
echo "=========================================="
echo "# 在虚拟机 (10.211.55.11) 上执行："
echo ""
echo "mkdir -p ~/.ssh"
echo "chmod 700 ~/.ssh"
echo "echo '$PUBLIC_KEY' >> ~/.ssh/authorized_keys"
echo "chmod 600 ~/.ssh/authorized_keys"
echo "=========================================="
echo ""
echo "执行完成后，测试连接："
echo "ssh root@10.211.55.11"
