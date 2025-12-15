#!/bin/bash

# 直接在虚拟机上运行的停止脚本
# 使用配置：docker-compose-opengauss-cluster-legacy.yml
#
# 使用方法：
# 在虚拟机上执行：./stop-on-vm.sh

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
COMPOSE_FILE="docker-compose-opengauss-cluster-legacy.yml"
PROJECT_DIR=$(pwd)

echo "=========================================="
echo "  停止 BlogCircle 服务"
echo "  配置文件: ${COMPOSE_FILE}"
echo "=========================================="
echo ""

# 检查配置文件
if [ ! -f "${COMPOSE_FILE}" ]; then
    echo -e "${RED}错误: 找不到 ${COMPOSE_FILE}${NC}"
    echo "请确保在项目根目录下运行此脚本"
    exit 1
fi

# 1. 检查服务状态
echo -e "${BLUE}[1/3]${NC} 当前服务状态..."
echo ""
docker-compose -f ${COMPOSE_FILE} ps || echo -e "${YELLOW}没有运行中的服务${NC}"

# 2. 停止服务
echo ""
echo -e "${BLUE}[2/3]${NC} 停止服务..."
echo "  • 停止前端服务..."
docker-compose -f ${COMPOSE_FILE} stop frontend 2>/dev/null || true

echo "  • 停止后端服务..."
docker-compose -f ${COMPOSE_FILE} stop backend 2>/dev/null || true

echo "  • 停止备库2..."
docker-compose -f ${COMPOSE_FILE} stop opengauss-standby2 2>/dev/null || true

echo "  • 停止备库1..."
docker-compose -f ${COMPOSE_FILE} stop opengauss-standby1 2>/dev/null || true

echo "  • 停止主库..."
docker-compose -f ${COMPOSE_FILE} stop opengauss-primary 2>/dev/null || true

echo -e "${GREEN}✓ 所有服务已停止${NC}"

# 3. 清理容器
echo ""
echo -e "${BLUE}[3/3]${NC} 清理容器..."
docker-compose -f ${COMPOSE_FILE} rm -f 2>/dev/null || true
echo -e "${GREEN}✓ 容器已清理${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}${BOLD}服务已停止${NC}"
echo "=========================================="
echo ""
echo -e "${BOLD}提示：${NC}"
echo "  • 数据已保留在 Docker volumes 中"
echo "  • 重新启动服务：${CYAN}./deploy-on-vm.sh${NC}"
echo ""
echo -e "${BOLD}查看保留的数据卷：${NC}"
echo "  ${CYAN}docker volume ls | grep cloudcom${NC}"
echo ""
echo -e "${BOLD}完全清理（删除所有数据和镜像）：${NC}"
echo "  ${CYAN}docker-compose -f ${COMPOSE_FILE} down -v${NC}"
echo "  ${CYAN}docker rmi blogcircle-backend:vm blogcircle-frontend:vm${NC}"
echo ""
