#!/bin/bash

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
echo "  BlogCircle 虚拟机部署工具"
echo "  配置文件: ${COMPOSE_FILE}"
echo "  项目目录: ${PROJECT_DIR}"
echo "=========================================="
echo ""

# 检查是否在虚拟机上
if [ ! -f "${COMPOSE_FILE}" ]; then
    echo -e "${RED}错误: 找不到 ${COMPOSE_FILE}${NC}"
    echo "请确保在项目根目录下运行此脚本"
    exit 1
fi

# 检查 Docker 镜像源配置
echo -e "${YELLOW}检查 Docker 配置...${NC}"
if [ -f /etc/docker/daemon.json ]; then
    echo "  ✓ Docker 镜像源配置存在"
    # 检查 Docker 服务状态
    if ! systemctl is-active --quiet docker; then
        echo -e "${YELLOW}  ! Docker 服务未运行，正在启动...${NC}"
        systemctl start docker
        sleep 3
    fi
else
    echo -e "${YELLOW}  ! 未找到 Docker 镜像源配置${NC}"
    echo -e "${YELLOW}  建议: 配置 Docker 镜像加速器以加快镜像下载${NC}"
fi

# 测试网络连接（不中断执行）
echo -e "${YELLOW}测试网络连接...${NC}"
if timeout 5 curl -s --head https://registry-1.docker.io > /dev/null 2>&1; then
    echo "  ✓ Docker Hub 连接正常"
elif timeout 5 curl -s --head https://docker.mirrors.ustc.edu.cn > /dev/null 2>&1; then
    echo "  ✓ 国内镜像源连接正常"
else
    echo -e "${YELLOW}  ⚠ 网络连接可能较慢或不稳定${NC}"
    echo -e "${YELLOW}  提示: 如果构建失败，请检查网络或使用离线镜像${NC}"
fi
echo ""

# 1. 停止旧服务
echo -e "${BLUE}[1/7]${NC} 停止旧服务（如果存在）..."
docker-compose -f ${COMPOSE_FILE} down 2>/dev/null || true
echo -e "${GREEN}旧服务已停止${NC}"

# 2. 清理旧镜像
echo ""
echo -e "${BLUE}[2/7]${NC} 清理旧的应用镜像..."
docker rmi blogcircle-backend:vm 2>/dev/null || echo "  后端镜像不存在，跳过"
docker rmi blogcircle-frontend:vm 2>/dev/null || echo "  前端镜像不存在，跳过"
echo -e "清理完成"

# 3. 拉取 openGauss 镜像
echo ""
echo -e "${BLUE}[3/7]${NC} 拉取 openGauss 镜像..."
docker pull enmotech/opengauss-lite:latest || echo -e "openGauss 镜像可能已存在"
echo -e "openGauss 镜像准备完成"

# 4. 构建后端镜像
echo ""
echo -e "${BLUE}[4/7]${NC} 构建后端镜像..."
echo "  • 构建 Java 应用（这可能需要几分钟）..."

cd backend
docker build -t blogcircle-backend:vm -f Dockerfile . 2>&1 | while IFS= read -r line; do
    echo "    $line"
done
BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -eq 0 ]; then
    echo -e "${GREEN}后端镜像构建成功${NC}"
else
    echo -e "${RED}后端镜像构建失败 (退出码: $BUILD_STATUS)${NC}"
    echo -e "${YELLOW}提示: 请检查网络连接或 Docker 镜像源配置${NC}"
    cd ..
    exit 1
fi

cd ..

# 5. 构建前端镜像
echo ""
echo -e "${BLUE}[5/7]${NC} 构建前端镜像..."
echo "  • 构建 Vue 应用（这可能需要几分钟）..."

cd frontend
docker build -t blogcircle-frontend:vm -f Dockerfile . 2>&1 | while IFS= read -r line; do
    echo "    $line"
done
BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -eq 0 ]; then
    echo -e "${GREEN}前端镜像构建成功${NC}"
else
    echo -e "${RED}前端镜像构建失败 (退出码: $BUILD_STATUS)${NC}"
    echo -e "${YELLOW}提示: 请检查网络连接或 Docker 镜像源配置${NC}"
    cd ..
    exit 1
fi

cd ..

# 6. 启动服务
echo ""
echo -e "${BLUE}[6/7]${NC} 启动服务..."
echo "  • 启动 openGauss 三实例集群..."
echo "  • 启动后端服务..."
echo "  • 启动前端服务..."

docker-compose -f ${COMPOSE_FILE} up -d --remove-orphans

if [ $? -eq 0 ]; then
    echo -e "服务启动成功"
else
    echo -e "服务启动失败"
    exit 1
fi

# 等待服务就绪
echo ""
echo -e "${YELLOW}等待服务就绪..."
echo -n "  • 等待数据库初始化（30秒）"
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo -e " ${GREEN}完成${NC}"

echo -n "  • 等待后端服务启动（30秒）"
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo -e " ${GREEN}完成${NC}"

echo -n "  • 等待前端服务就绪（20秒）"
for i in {1..20}; do
    echo -n "."
    sleep 1
done
echo -e " ${GREEN}完成${NC}"

# 7. 检查服务状态和初始化数据库
echo ""
echo -e "${BLUE}[7/7]${NC} 检查服务状态和初始化..."
echo ""
echo -e "${YELLOW}服务状态：${NC}"
docker-compose -f ${COMPOSE_FILE} ps

# 健康检查
echo ""
echo -e "${YELLOW}健康检查：${NC}"

# 检查主库
echo -n "  • openGauss 主库: "
if docker exec opengauss-primary bash -c 'su - omm -c "gsql -d postgres -c \"SELECT 1;\"" &>/dev/null'; then
    echo -e "${GREEN}健康${NC}"
else
    echo -e "${RED}异常${NC}"
fi

# 检查备库1
echo -n "  • openGauss 备库1: "
if docker exec opengauss-standby1 bash -c 'ps aux | grep gaussdb | grep -v grep &>/dev/null'; then
    echo -e "${GREEN}运行中${NC}"
else
    echo -e "${YELLOW}检查中...${NC}"
fi

# 检查备库2
echo -n "  • openGauss 备库2: "
if docker exec opengauss-standby2 bash -c 'ps aux | grep gaussdb | grep -v grep &>/dev/null'; then
    echo -e "${GREEN}运行中${NC}"
else
    echo -e "${YELLOW}检查中...${NC}"
fi

# 检查后端
echo -n "  • 后端服务: "
if docker exec blogcircle-backend curl -f http://localhost:8080/actuator/health &>/dev/null; then
    echo -e "${GREEN}健康${NC}"
else
    echo -e "${YELLOW}等待中...${NC}"
fi

# 检查前端
echo -n "  • 前端服务: "
if docker exec blogcircle-frontend wget --quiet --tries=1 --spider http://localhost:8080/ &>/dev/null; then
    echo -e "${GREEN}健康${NC}"
else
    echo -e "${YELLOW}等待中...${NC}"
fi

# 初始化数据库
echo ""
echo -e "${YELLOW}数据库初始化：${NC}"
echo "  检查 blog_db 是否存在..."

DB_EXISTS=$(docker exec opengauss-primary bash -c 'su - omm -c "gsql -d postgres -t -c \"SELECT 1 FROM pg_database WHERE datname='\''blog_db'\'';\""' 2>/dev/null | grep -c 1 || echo "0")

if [ "$DB_EXISTS" -eq "0" ]; then
    echo -e "  ${YELLOW}blog_db 不存在，正在创建...${NC}"
    
    # 创建用户
    echo "  • 创建 bloguser 用户..."
    docker exec opengauss-primary bash -c 'su - omm -c "gsql -d postgres -c \"CREATE USER bloguser WITH PASSWORD '\''Blog@2025'\'' CREATEDB;\""' 2>/dev/null || echo "    用户可能已存在"
    
    # 创建数据库
    echo "  • 创建 blog_db 数据库..."
    docker exec opengauss-primary bash -c 'su - omm -c "gsql -d postgres -c \"CREATE DATABASE blog_db OWNER bloguser;\""' 2>/dev/null || echo "    数据库可能已存在"
    
    # 创建备库用户和数据库
    echo "  • 在备库1创建用户和数据库..."
    docker exec opengauss-standby1 bash -c 'su - omm -c "gsql -d postgres -p 15432 -c \"CREATE USER bloguser WITH PASSWORD '\''Blog@2025'\'' CREATEDB;\""' 2>/dev/null || true
    docker exec opengauss-standby1 bash -c 'su - omm -c "gsql -d postgres -p 15432 -c \"CREATE DATABASE blog_db OWNER bloguser;\""' 2>/dev/null || true
    
    echo "  • 在备库2创建用户和数据库..."
    docker exec opengauss-standby2 bash -c 'su - omm -c "gsql -d postgres -p 25432 -c \"CREATE USER bloguser WITH PASSWORD '\''Blog@2025'\'' CREATEDB;\""' 2>/dev/null || true
    docker exec opengauss-standby2 bash -c 'su - omm -c "gsql -d postgres -p 25432 -c \"CREATE DATABASE blog_db OWNER bloguser;\""' 2>/dev/null || true
    
    echo -e "  ${GREEN}✓ 数据库初始化完成${NC}"
    echo ""
    echo -e "  ${YELLOW}注意：${NC}应用启动时会自动创建表结构，请稍等 1-2 分钟"
else
    echo -e "  ${GREEN}✓ blog_db 已存在${NC}"
fi

# 获取虚拟机 IP
VM_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "=========================================="
echo -e "${GREEN}${BOLD}部署完成${NC}"
echo "=========================================="
echo ""
echo -e "${BOLD}访问地址：${NC}"
echo -e "  • 前端：${CYAN}http://${VM_IP}:8080${NC}"
echo -e "  • 后端：${CYAN}http://${VM_IP}:8082${NC}"
echo -e "  • 健康检查：${CYAN}http://${VM_IP}:8082/actuator/health${NC}"
echo ""
echo -e "${BOLD}数据库连接：${NC}"
echo -e "  • 主库：${CYAN}${VM_IP}:5432${NC}"
echo -e "  • 备库1：${CYAN}${VM_IP}:5434${NC} (容器内端口: 15432)"
echo -e "  • 备库2：${CYAN}${VM_IP}:5436${NC} (容器内端口: 25432)"
echo ""
