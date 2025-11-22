#!/bin/bash

# openGauss 三实例测试脚本

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

echo "========================================"
echo "openGauss 多实例测试脚本"
echo "========================================"

# 1. 测试主库
echo -e "\n${YELLOW}=== 测试主库 (端口 5432) ===${NC}"
if docker exec opengauss-primary su - omm -c "/usr/local/opengauss/bin/gsql -d postgres -c 'SELECT 1'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 主库连接正常${NC}"
    docker exec opengauss-primary su - omm -c "/usr/local/opengauss/bin/gsql -d postgres -c 'SELECT version()'" | head -3
else
    echo -e "${RED}✗ 主库连接失败${NC}"
    ((ERRORS++))
fi

# 2. 测试备库1
echo -e "\n${YELLOW}=== 测试备库1 (端口 5434 -> 15432) ===${NC}"
if docker exec opengauss-standby1 su - omm -c "PGPORT=15432 /usr/local/opengauss/bin/gsql -d postgres -p 15432 -c 'SELECT 1'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 备库1连接正常${NC}"
    docker exec opengauss-standby1 su - omm -c "PGPORT=15432 /usr/local/opengauss/bin/gsql -d postgres -p 15432 -c 'SELECT version()'" | head -3
else
    echo -e "${RED}✗ 备库1连接失败${NC}"
    ((ERRORS++))
fi

# 3. 测试备库2
echo -e "\n${YELLOW}=== 测试备库2 (端口 5436 -> 25432) ===${NC}"
if docker exec opengauss-standby2 su - omm -c "PGPORT=25432 /usr/local/opengauss/bin/gsql -d postgres -p 25432 -c 'SELECT 1'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 备库2连接正常${NC}"
    docker exec opengauss-standby2 su - omm -c "PGPORT=25432 /usr/local/opengauss/bin/gsql -d postgres -p 25432 -c 'SELECT version()'" | head -3
else
    echo -e "${RED}✗ 备库2连接失败${NC}"
    ((ERRORS++))
fi

# 4. 测试数据库创建
echo -e "\n${YELLOW}=== 测试数据库操作 ===${NC}"
if docker exec opengauss-primary su - omm -c "/usr/local/opengauss/bin/gsql -d postgres -c 'SELECT datname FROM pg_database WHERE datname='\''blog_db'\'''" | grep -q blog_db; then
    echo -e "${GREEN}✓ blog_db 数据库存在${NC}"
else
    echo -e "${YELLOW}! blog_db 不存在，正在创建...${NC}"
    docker exec opengauss-primary su - omm -c "/usr/local/opengauss/bin/gsql -d postgres -c 'CREATE DATABASE blog_db'"
    echo -e "${GREEN}✓ blog_db 创建成功${NC}"
fi

# 5. 测试读写功能
echo -e "\n${YELLOW}=== 测试读写功能 ===${NC}"
TIMESTAMP=$(date +%s)
docker exec opengauss-primary su - omm -c "/usr/local/opengauss/bin/gsql -d blog_db -c 'CREATE TABLE IF NOT EXISTS health_check (id SERIAL PRIMARY KEY, timestamp BIGINT)'" >/dev/null 2>&1
docker exec opengauss-primary su - omm -c "/usr/local/opengauss/bin/gsql -d blog_db -c \"INSERT INTO health_check (timestamp) VALUES ($TIMESTAMP)\"" >/dev/null 2>&1
if docker exec opengauss-primary su - omm -c "/usr/local/opengauss/bin/gsql -d blog_db -t -c 'SELECT timestamp FROM health_check ORDER BY id DESC LIMIT 1'" | grep -q $TIMESTAMP; then
    echo -e "${GREEN}✓ 主库读写功能正常${NC}"
else
    echo -e "${RED}✗ 主库读写功能异常${NC}"
    ((ERRORS++))
fi
docker exec opengauss-primary su - omm -c "/usr/local/opengauss/bin/gsql -d blog_db -c 'DROP TABLE health_check'" >/dev/null 2>&1

# 6. 容器状态检查
echo -e "\n${YELLOW}=== 容器状态 ===${NC}"
docker ps --filter "name=opengauss" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 7. 资源使用情况
echo -e "\n${YELLOW}=== 资源使用情况 ===${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" opengauss-primary opengauss-standby1 opengauss-standby2

# 测试结果
echo -e "\n========================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}所有测试通过！${NC}"
    echo "========================================"
    exit 0
else
    echo -e "${RED}测试失败，共 $ERRORS 个错误${NC}"
    echo "========================================"
    exit 1
fi
