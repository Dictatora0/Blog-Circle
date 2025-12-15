#!/bin/bash

# Docker 网络问题修复脚本
# 在虚拟机上运行此脚本来配置 Docker 镜像源并重启服务

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "=========================================="
echo "  Docker 网络配置修复工具"
echo "=========================================="
echo ""

# 1. 检查当前配置
echo -e "${BLUE}[1/4]${NC} 检查当前 Docker 配置..."
if [ -f /etc/docker/daemon.json ]; then
    echo "  当前配置:"
    cat /etc/docker/daemon.json | sed 's/^/    /'
else
    echo "  未找到配置文件"
fi
echo ""

# 2. 配置 Docker 镜像源
echo -e "${BLUE}[2/4]${NC} 配置 Docker 镜像源..."
mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com"
  ],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

echo -e "${GREEN}  ✓ 镜像源配置已更新${NC}"
echo ""

# 3. 重启 Docker 服务
echo -e "${BLUE}[3/4]${NC} 重启 Docker 服务..."
systemctl daemon-reload
systemctl restart docker

# 等待 Docker 启动
sleep 3

if systemctl is-active --quiet docker; then
    echo -e "${GREEN}  ✓ Docker 服务已重启${NC}"
else
    echo -e "${RED}  ✗ Docker 服务启动失败${NC}"
    exit 1
fi
echo ""

# 4. 测试网络连接
echo -e "${BLUE}[4/4]${NC} 测试网络连接..."

echo -n "  • Docker Hub: "
if timeout 10 docker pull hello-world > /dev/null 2>&1; then
    echo -e "${GREEN}连接成功${NC}"
    docker rmi hello-world > /dev/null 2>&1
else
    echo -e "${YELLOW}连接失败或超时${NC}"
fi

echo -n "  • 国内镜像源: "
if timeout 5 curl -s --head https://docker.mirrors.ustc.edu.cn > /dev/null 2>&1; then
    echo -e "${GREEN}连接正常${NC}"
else
    echo -e "${YELLOW}连接失败${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Docker 配置完成${NC}"
echo "=========================================="
echo ""
echo -e "${CYAN}提示:${NC}"
echo "  1. 如果网络仍然有问题，请检查防火墙设置"
echo "  2. 可以尝试重启虚拟机: reboot"
echo "  3. 或者考虑使用离线镜像部署"
echo ""
echo -e "${CYAN}测试命令:${NC}"
echo "  docker pull enmotech/opengauss-lite:latest"
echo "  docker pull maven:3.8.7-eclipse-temurin-17"
echo "  docker pull node:18-alpine"
echo ""
