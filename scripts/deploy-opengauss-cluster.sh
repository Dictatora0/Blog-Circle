#!/bin/bash

set -e

echo "========================================"
echo "openGauss 集群容器化部署脚本"
echo "========================================"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 Docker 和 Docker Compose
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}错误: Docker Compose 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker 环境检查通过${NC}"

# 停止并清理旧容器
echo -e "${YELLOW}停止旧容器...${NC}"
docker-compose -f docker-compose-opengauss-cluster.yml down -v 2>/dev/null || true

# 清理旧的数据卷
echo -e "${YELLOW}清理数据卷...${NC}"
docker volume rm cloudcom_opengauss-primary-data cloudcom_opengauss-standby1-data cloudcom_opengauss-standby2-data 2>/dev/null || true

# 确保脚本有执行权限
chmod +x scripts/opengauss-init-primary.sh
chmod +x scripts/opengauss-init-standby.sh

# 构建镜像
echo -e "${YELLOW}构建后端和前端镜像...${NC}"
docker-compose -f docker-compose-opengauss-cluster.yml build

# 启动服务
echo -e "${YELLOW}启动 openGauss 集群...${NC}"
docker-compose -f docker-compose-opengauss-cluster.yml up -d

# 等待服务启动
echo -e "${YELLOW}等待服务启动（预计需要 2-3 分钟）...${NC}"
sleep 30

# 检查容器状态
echo -e "\n${GREEN}=== 容器状态 ===${NC}"
docker-compose -f docker-compose-opengauss-cluster.yml ps

# 检查主库状态
echo -e "\n${GREEN}=== 检查主库状态 ===${NC}"
docker exec opengauss-primary su - omm -c "gs_ctl query -D /var/lib/opengauss/data" || echo "主库尚未完全启动"

# 等待集群完全就绪
echo -e "\n${YELLOW}等待集群完全就绪...${NC}"
for i in {1..30}; do
    if docker exec opengauss-primary su - omm -c "gsql -d blog_db -c 'SELECT 1'" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 主库已就绪${NC}"
        break
    fi
    echo "等待主库... ($i/30)"
    sleep 10
done

# 初始化数据库
echo -e "\n${YELLOW}初始化数据库表结构...${NC}"
if [ -f "backend/src/main/resources/db/01_init.sql" ]; then
    docker exec -i opengauss-primary su - omm -c "gsql -d blog_db" < backend/src/main/resources/db/01_init.sql
    echo -e "${GREEN}✓ 数据库初始化完成${NC}"
fi

# 显示访问信息
echo -e "\n${GREEN}========================================"
echo "部署完成！"
echo "========================================${NC}"
echo ""
echo "服务访问地址："
echo "  前端: http://localhost:8080"
echo "  后端: http://localhost:8082"
echo "  主库: localhost:5432"
echo "  备库1: localhost:5434"
echo "  备库2: localhost:5436"
echo ""
echo "数据库连接信息："
echo "  数据库: blog_db"
echo "  用户名: bloguser"
echo "  密码: Blog@2025"
echo ""
echo "管理命令："
echo "  查看日志: docker-compose -f docker-compose-opengauss-cluster.yml logs -f [service_name]"
echo "  停止服务: docker-compose -f docker-compose-opengauss-cluster.yml down"
echo "  重启服务: docker-compose -f docker-compose-opengauss-cluster.yml restart"
echo ""
echo "运行测试："
echo "  ./scripts/test-opengauss-cluster.sh"
echo ""
