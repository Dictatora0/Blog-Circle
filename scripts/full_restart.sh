#!/bin/bash

###############################################################
# 一键关闭并重启整个容器集群
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
echo -e "${BOLD}${MAGENTA}║       一键重启容器集群                                     ║${NC}"
echo -e "${BOLD}${MAGENTA}║       Full Cluster Restart                                 ║${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. 停止所有容器
echo -e "${BOLD}${BLUE}▶ 步骤 1/5: 停止所有容器${NC}"
docker-compose -f docker-compose-gaussdb-cluster.yml down

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ 容器已停止${NC}"
else
    echo -e "${RED}  ✗ 停止失败${NC}"
    exit 1
fi
echo ""

# 2. 清理网络和孤立容器
echo -e "${BOLD}${BLUE}▶ 步骤 2/5: 清理网络和孤立容器${NC}"
docker-compose -f docker-compose-gaussdb-cluster.yml down --remove-orphans
docker network prune -f > /dev/null 2>&1
echo -e "${GREEN}  ✓ 清理完成${NC}"
echo ""

# 3. 重新启动容器
echo -e "${BOLD}${BLUE}▶ 步骤 3/5: 启动容器集群${NC}"
docker-compose -f docker-compose-gaussdb-cluster.yml up -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ 容器启动成功${NC}"
else
    echo -e "${RED}  ✗ 启动失败${NC}"
    exit 1
fi
echo ""

# 4. 等待服务就绪
echo -e "${BOLD}${BLUE}▶ 步骤 4/5: 等待服务就绪${NC}"
echo -e "${CYAN}  这可能需要 1-2 分钟...${NC}"
echo ""

# 等待主库
echo -n "  等待 GaussDB 主库..."
for i in $(seq 1 60); do
    if docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-primary pg_isready -U bloguser > /dev/null 2>&1; then
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

# 等待后端
echo -n "  等待后端服务..."
for i in $(seq 1 90); do
    if curl -s -f http://localhost:8081/actuator/health > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    if [ $i -eq 90 ]; then
        echo -e " ${RED}✗ 超时${NC}"
        echo -e "${YELLOW}  提示: 运行 'docker logs blogcircle-backend' 查看日志${NC}"
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

# 5. 显示服务状态
echo -e "${BOLD}${BLUE}▶ 步骤 5/5: 服务状态${NC}"
docker-compose -f docker-compose-gaussdb-cluster.yml ps
echo ""

# 完成
echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}║              重启完成！                                    ║${NC}"
echo -e "${BOLD}${MAGENTA}║              Restart Complete!                             ║${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}访问地址:${NC}"
echo -e "  • 前端: ${CYAN}http://localhost:8080${NC}"
echo -e "  • 后端: ${CYAN}http://localhost:8081${NC}"
echo ""

echo -e "${BOLD}验证系统:${NC}"
echo -e "  ${CYAN}./scripts/full_verify.sh${NC}"
echo ""
