#!/bin/bash

###############################################################
# Blog Circle 本地停止脚本
# 优雅关闭所有服务
###############################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BOLD}${YELLOW}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${YELLOW}║                                                ║${NC}"
echo -e "${BOLD}${YELLOW}║       Blog Circle 本地停止                     ║${NC}"
echo -e "${BOLD}${YELLOW}║       Local System Shutdown                    ║${NC}"
echo -e "${BOLD}${YELLOW}║                                                ║${NC}"
echo -e "${BOLD}${YELLOW}╚════════════════════════════════════════════════╝${NC}"
echo ""

# 检查服务状态
echo -e "${YELLOW}[1/3]${NC} 检查服务状态..."
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✓ 没有运行中的服务${NC}"
    exit 0
fi

# 停止服务
echo ""
echo -e "${YELLOW}[2/3]${NC} 停止服务..."
echo "  • 停止前端服务..."
docker-compose stop frontend

echo "  • 停止后端服务..."
docker-compose stop backend

echo "  • 停止数据库..."
docker-compose stop db

# 移除容器
echo ""
echo -e "${YELLOW}[3/3]${NC} 清理容器..."
docker-compose down

echo ""
echo -e "${BOLD}${GREEN}✓ 服务已停止${NC}"
echo ""
echo -e "${BOLD}提示：${NC}"
echo "  • 数据已保留在 Docker volumes 中"
echo "  • 重新启动：${CYAN}./start-local.sh${NC}"
echo "  • 完全清理（包括数据）：${RED}docker-compose down -v${NC}"
echo ""
