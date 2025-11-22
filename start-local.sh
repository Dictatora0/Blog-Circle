#!/bin/bash

###############################################################
# Blog Circle 本地启动脚本
# 使用 docker-compose-opengauss-cluster.yml 启动完整服务
###############################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                ║${NC}"
echo -e "${BOLD}${CYAN}║       Blog Circle 本地启动                     ║${NC}"
echo -e "${BOLD}${CYAN}║       Local System Startup                     ║${NC}"
echo -e "${BOLD}${CYAN}║                                                ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════╝${NC}"
echo ""

# 检查 Docker
echo -e "${BLUE}[1/5]${NC} 检查 Docker 环境..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker 未安装${NC}"
    echo "请先安装 Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}✗ Docker 未运行${NC}"
    echo "请启动 Docker Desktop"
    exit 1
fi

echo -e "${GREEN}✓ Docker 已就绪${NC}"
docker --version

# 检查 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}✗ Docker Compose 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose 已就绪${NC}"
docker-compose --version

# 停止已有容器
echo ""
echo -e "${BLUE}[2/5]${NC} 停止已有容器..."
docker-compose -f docker-compose-opengauss-cluster.yml down 2>/dev/null || true
echo -e "${GREEN}✓ 已清理旧容器${NC}"

# 拉取镜像
echo ""
echo -e "${BLUE}[3/5]${NC} 拉取 openGauss 镜像..."
docker pull enmotech/opengauss-lite:latest
echo -e "${GREEN}✓ 镜像已就绪${NC}"

# 启动服务
echo ""
echo -e "${BLUE}[4/5]${NC} 启动服务..."
echo "  • 启动 openGauss 三实例集群..."
echo "  • 构建并启动后端服务..."
echo "  • 构建并启动前端服务..."
docker-compose -f docker-compose-opengauss-cluster.yml up -d --build

# 等待服务启动
echo ""
echo -e "${BLUE}[5/5]${NC} 等待服务就绪..."
echo "  • 等待数据库初始化（90秒）..."
sleep 30
echo "  • 等待后端服务启动（60秒）..."
sleep 30
echo "  • 等待前端服务就绪（30秒）..."
sleep 30

# 检查服务状态
echo ""
echo -e "${YELLOW}═══ 服务状态 ═══${NC}"
docker-compose -f docker-compose-opengauss-cluster.yml ps

# 检查健康状态
echo ""
echo -e "${YELLOW}═══ 健康检查 ═══${NC}"

# 检查数据库
echo -n "  • openGauss 主库: "
if docker exec opengauss-primary su - omm -c "/usr/local/opengauss/bin/gsql -d postgres -c 'SELECT 1'" &>/dev/null; then
    echo -e "${GREEN}✓ 健康${NC}"
else
    echo -e "${YELLOW}⚠ 未就绪${NC}"
fi

echo -n "  • openGauss 备库1: "
if docker exec opengauss-standby1 su - omm -c "PGPORT=15432 /usr/local/opengauss/bin/gsql -d postgres -p 15432 -c 'SELECT 1'" &>/dev/null; then
    echo -e "${GREEN}✓ 健康${NC}"
else
    echo -e "${YELLOW}⚠ 未就绪${NC}"
fi

echo -n "  • openGauss 备库2: "
if docker exec opengauss-standby2 su - omm -c "PGPORT=25432 /usr/local/opengauss/bin/gsql -d postgres -p 25432 -c 'SELECT 1'" &>/dev/null; then
    echo -e "${GREEN}✓ 健康${NC}"
else
    echo -e "${YELLOW}⚠ 未就绪${NC}"
fi

echo -n "  • 后端服务: "
if curl -sf http://localhost:8082/actuator/health &>/dev/null; then
    echo -e "${GREEN}✓ 健康${NC}"
else
    echo -e "${YELLOW}⚠ 未就绪（可能仍在初始化）${NC}"
fi

echo -n "  • 前端服务: "
if curl -sf http://localhost:8080 &>/dev/null; then
    echo -e "${GREEN}✓ 健康${NC}"
else
    echo -e "${YELLOW}⚠ 未就绪${NC}"
fi

# 完成
echo ""
echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                                                ║${NC}"
echo -e "${BOLD}${GREEN}║  ✓ 系统启动完成！                             ║${NC}"
echo -e "${BOLD}${GREEN}║    System Started Successfully!                ║${NC}"
echo -e "${BOLD}${GREEN}║                                                ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}访问地址：${NC}"
echo -e "  • 前端：${CYAN}http://localhost:8080${NC}"
echo -e "  • 后端：${CYAN}http://localhost:8082${NC}"
echo -e "  • 健康检查：${CYAN}http://localhost:8082/actuator/health${NC}"
echo ""
echo -e "${BOLD}数据库连接：${NC}"
echo -e "  • 主库：${CYAN}localhost:5432${NC}"
echo -e "  • 备库1：${CYAN}localhost:5434${NC}"
echo -e "  • 备库2：${CYAN}localhost:5436${NC}"
echo ""
echo -e "${BOLD}常用命令：${NC}"
echo -e "  • 查看日志：${CYAN}docker-compose -f docker-compose-opengauss-cluster.yml logs -f${NC}"
echo -e "  • 停止服务：${CYAN}./stop-local.sh${NC}"
echo -e "  • 系统验证：${CYAN}./scripts/full_verify.sh${NC}"
echo ""
