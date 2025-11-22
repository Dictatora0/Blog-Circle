#!/bin/bash

###############################################################
# 重建容器化系统
# 基于 Docker Compose 部署 GaussDB 集群 + 后端 + 前端
###############################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

cd "$(dirname "$0")/.."

echo ""
echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}║       重建容器化系统                                       ║${NC}"
echo -e "${BOLD}${MAGENTA}║       Rebuild Docker System                                ║${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查依赖
echo -e "${BOLD}${BLUE}▶ 检查依赖${NC}"

# 查找 Docker
if command -v docker &> /dev/null; then
    DOCKER_CMD="docker"
elif [ -f "/usr/local/bin/docker" ]; then
    DOCKER_CMD="/usr/local/bin/docker"
elif [ -f "/Applications/Docker.app/Contents/Resources/bin/docker" ]; then
    DOCKER_CMD="/Applications/Docker.app/Contents/Resources/bin/docker"
    export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
else
    echo -e "${RED}✗ Docker 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Docker: $($DOCKER_CMD --version | cut -d' ' -f3)${NC}"

# 查找 Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif $DOCKER_CMD compose version &> /dev/null; then
    COMPOSE_CMD="$DOCKER_CMD compose"
else
    echo -e "${RED}✗ Docker Compose 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Docker Compose 已安装${NC}"

if ! $DOCKER_CMD info &> /dev/null; then
    echo -e "${RED}✗ Docker 服务未运行${NC}"
    echo -e "${YELLOW}  请先启动 Docker Desktop${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Docker 服务运行中${NC}"
echo ""

# 设置脚本权限
echo -e "${BOLD}${BLUE}▶ 设置脚本权限${NC}"
chmod +x scripts/docker-entrypoint-standby.sh
chmod +x scripts/*.sh 2>/dev/null || true
echo -e "${GREEN}  ✓ 脚本权限已设置${NC}"
echo ""

# 停止旧容器
echo -e "${BOLD}${BLUE}▶ 停止旧容器（如果存在）${NC}"
$COMPOSE_CMD -f docker-compose-gaussdb-cluster.yml down -v 2>/dev/null || true
echo -e "${GREEN}  ✓ 旧容器已停止${NC}"
echo ""

# 构建镜像
echo -e "${BOLD}${BLUE}▶ 构建 Docker 镜像${NC}"
echo -e "${CYAN}  这可能需要几分钟...${NC}"
$COMPOSE_CMD -f docker-compose-gaussdb-cluster.yml build --no-cache

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ 镜像构建成功${NC}"
else
    echo -e "${RED}  ✗ 镜像构建失败${NC}"
    exit 1
fi
echo ""

# 启动服务
echo -e "${BOLD}${BLUE}▶ 启动容器集群${NC}"
$COMPOSE_CMD -f docker-compose-gaussdb-cluster.yml up -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ 容器启动成功${NC}"
else
    echo -e "${RED}  ✗ 容器启动失败${NC}"
    exit 1
fi
echo ""

# 等待服务就绪
echo -e "${BOLD}${BLUE}▶ 等待服务就绪${NC}"
echo -e "${CYAN}  这可能需要 1-2 分钟...${NC}"
echo ""

# 等待主库
echo -n "  等待 GaussDB 主库..."
for i in $(seq 1 60); do
    if $COMPOSE_CMD -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-primary pg_isready -U bloguser > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e " ${RED}✗ 超时${NC}"
        exit 1
    fi
    echo -n "."
    sleep 2
done

# 等待备库1
echo -n "  等待 GaussDB 备库1..."
for i in $(seq 1 60); do
    if $COMPOSE_CMD -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-standby1 pg_isready -U bloguser > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e " ${YELLOW}⚠ 超时（可选服务）${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# 等待备库2
echo -n "  等待 GaussDB 备库2..."
for i in $(seq 1 60); do
    if $COMPOSE_CMD -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-standby2 pg_isready -U bloguser > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e " ${YELLOW}⚠ 超时（可选服务）${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# 等待后端
echo -n "  等待后端服务..."
for i in $(seq 1 90); do
    if curl -s -f http://localhost:8081/actuator/health > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    if [ $i -eq 90 ]; then
        echo -e " ${RED}✗ 超时${NC}"
    fi
    echo -n "."
    sleep 2
done

# 等待前端
echo -n "  等待前端服务..."
for i in $(seq 1 30); do
    if curl -s -f http://localhost:8080 > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e " ${RED}✗ 超时${NC}"
    fi
    echo -n "."
    sleep 1
done

echo ""

# 显示服务状态
echo -e "${BOLD}${BLUE}▶ 服务状态${NC}"
$COMPOSE_CMD -f docker-compose-gaussdb-cluster.yml ps
echo ""

# 验证复制状态
echo -e "${BOLD}${BLUE}▶ 验证主备复制${NC}"
REPLICATION_STATUS=$($COMPOSE_CMD -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-primary \
    psql -U bloguser -d blog_db -t -c "SELECT count(*) FROM pg_stat_replication;" 2>/dev/null | tr -d ' \n')

if [ "$REPLICATION_STATUS" = "2" ]; then
    echo -e "${GREEN}  ✓ 主备复制正常 (2/2 备库已连接)${NC}"
elif [ "$REPLICATION_STATUS" = "1" ]; then
    echo -e "${YELLOW}  ⚠ 部分复制正常 (1/2 备库已连接)${NC}"
else
    echo -e "${YELLOW}  ⚠ 复制状态未知${NC}"
fi
echo ""

# 完成
echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}║              系统重建完成！                                ║${NC}"
echo -e "${BOLD}${MAGENTA}║              System Rebuild Complete!                      ║${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}访问地址:${NC}"
echo -e "  • 前端: ${CYAN}http://localhost:8080${NC}"
echo -e "  • 后端: ${CYAN}http://localhost:8081${NC}"
echo -e "  • GaussDB 主库: ${CYAN}localhost:5432${NC}"
echo -e "  • GaussDB 备库1: ${CYAN}localhost:5434${NC}"
echo -e "  • GaussDB 备库2: ${CYAN}localhost:5436${NC}"
echo ""

echo -e "${BOLD}管理命令:${NC}"
echo -e "  • 查看日志: ${CYAN}docker-compose -f docker-compose-gaussdb-cluster.yml logs -f${NC}"
echo -e "  • 停止服务: ${CYAN}docker-compose -f docker-compose-gaussdb-cluster.yml down${NC}"
echo -e "  • 重启服务: ${CYAN}docker-compose -f docker-compose-gaussdb-cluster.yml restart${NC}"
echo -e "  • 查看状态: ${CYAN}docker-compose -f docker-compose-gaussdb-cluster.yml ps${NC}"
echo ""

echo -e "${BOLD}验证脚本:${NC}"
echo -e "  • 检查数据库: ${CYAN}./scripts/check_db.sh${NC}"
echo -e "  • 检查后端: ${CYAN}./scripts/check_backend.sh${NC}"
echo -e "  • 检查前端: ${CYAN}./scripts/check_frontend.sh${NC}"
echo -e "  • 完整验证: ${CYAN}./scripts/full_verify.sh${NC}"
echo ""
