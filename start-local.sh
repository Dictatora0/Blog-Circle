#!/bin/bash

###############################################################
# Blog Circle 本地启动脚本
# 使用 PostgreSQL 数据库（简化开发环境）
###############################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# 加载环境变量
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

POSTGRES_DB="${LOCAL_POSTGRES_DB:-blog_db}"
POSTGRES_USER="${LOCAL_POSTGRES_USER:-bloguser}"
POSTGRES_PASSWORD="${LOCAL_POSTGRES_PASSWORD:-blogpass}"
LOCAL_BACKEND_PORT="${LOCAL_BACKEND_PORT:-8081}"
LOCAL_FRONTEND_PORT="${LOCAL_FRONTEND_PORT:-8080}"

echo ""
echo -e "${BOLD}${CYAN}Blog Circle 本地启动${NC}"
echo -e "${CYAN}Local Development Environment${NC}"
echo -e "${CYAN}PostgreSQL + Spring Boot + Vue${NC}"
echo ""

# 检查 Docker
echo -e "${BLUE}[1/5]${NC} 检查 Docker 环境..."
if ! command -v docker &> /dev/null; then
	echo -e "${RED}Docker 未安装${NC}"
	echo "请先安装 Docker Desktop: https://www.docker.com/products/docker-desktop"
	exit 1
fi

if ! docker info &> /dev/null; then
	echo -e "${RED}Docker 未运行${NC}"
    echo "请启动 Docker Desktop"
    exit 1
fi

echo -e "${GREEN}Docker 已就绪${NC}"
docker --version

# 检查 Docker Compose
if ! command -v docker-compose &> /dev/null; then
	echo -e "${RED}Docker Compose 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}Docker Compose 已就绪${NC}"
docker-compose --version

# 停止已有容器
echo ""
echo -e "${BLUE}[2/5]${NC} 停止已有容器..."
docker-compose down 2>/dev/null || true
echo -e "${GREEN}已清理旧容器${NC}"

# 拉取镜像
echo ""
echo -e "${BLUE}[3/5]${NC} 拉取 PostgreSQL 镜像..."
docker pull postgres:15-alpine
echo -e "${GREEN}镜像已就绪${NC}"

# 启动服务
echo ""
echo -e "${BLUE}[4/5]${NC} 启动服务..."
echo "  • 启动 PostgreSQL 数据库..."
echo "  • 构建并启动后端服务..."
echo "  • 构建并启动前端服务..."
docker-compose up -d --build

# 等待服务启动
echo ""
echo -e "${BLUE}[5/5]${NC} 等待服务就绪..."
echo "  • 等待数据库初始化（10秒）..."
sleep 10
echo "  • 等待后端服务启动（20秒）..."
sleep 20
echo "  • 等待前端服务就绪（10秒）..."
sleep 10

# 检查服务状态
echo ""
echo -e "${YELLOW}服务状态${NC}"
docker-compose ps

# 检查健康状态
echo ""
echo -e "${YELLOW}健康检查${NC}"

# 检查数据库
echo -n "  • PostgreSQL 数据库: "
if docker exec blogcircle-db pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} &>/dev/null; then
	echo -e "${GREEN}健康${NC}"
else
	echo -e "${YELLOW}未就绪${NC}"
fi

echo -n "  • 后端服务: "
if curl -sf http://localhost:${LOCAL_BACKEND_PORT}/actuator/health &>/dev/null; then
	echo -e "${GREEN}健康${NC}"
else
	echo -e "${YELLOW}未就绪（可能仍在初始化）${NC}"
fi

echo -n "  • 前端服务: "
if curl -sf http://localhost:${LOCAL_FRONTEND_PORT} &>/dev/null; then
	echo -e "${GREEN}健康${NC}"
else
	echo -e "${YELLOW}未就绪${NC}"
fi

# 完成
echo ""
echo -e "${BOLD}${GREEN}本地开发环境启动完成${NC}"
echo -e "${GREEN}Local Environment Started${NC}"
echo ""
echo -e "${BOLD}访问地址：${NC}"
echo -e "  • 前端：${CYAN}http://localhost:${LOCAL_FRONTEND_PORT}${NC}"
echo -e "  • 后端：${CYAN}http://localhost:${LOCAL_BACKEND_PORT}${NC}"
echo -e "  • 健康检查：${CYAN}http://localhost:${LOCAL_BACKEND_PORT}/actuator/health${NC}"
echo ""
echo -e "${BOLD}数据库连接：${NC}"
echo -e "  • PostgreSQL：${CYAN}localhost:5432${NC}"
echo -e "  • 数据库名：${CYAN}${POSTGRES_DB}${NC}"
echo -e "  • 用户名：${CYAN}${POSTGRES_USER}${NC}"
echo -e "  • 密码：${CYAN}${POSTGRES_PASSWORD}${NC}"
echo ""
echo -e "${BOLD}常用命令：${NC}"
echo -e "  • 查看日志：${CYAN}docker-compose logs -f${NC}"
echo -e "  • 停止服务：${CYAN}./stop-local.sh${NC}"
echo -e "  • 重新构建：${CYAN}docker-compose up -d --build${NC}"
echo ""
echo -e "${YELLOW}提示：如需使用 openGauss 集群环境，请使用 start-vm.sh${NC}"
echo ""
