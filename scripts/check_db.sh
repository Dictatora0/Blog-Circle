#!/bin/bash

###############################################################
# GaussDB 集群健康检查脚本
###############################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo -e "${BOLD}${CYAN}  GaussDB 集群健康检查  ${NC}"
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo ""

# 检查主库
echo -e "${BOLD}1. 主库状态 (端口 5432)${NC}"
if docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-primary pg_isready -U bloguser > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ 主库运行正常${NC}"
    
    # 检查数据库连接
    VERSION=$(docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-primary \
        psql -U bloguser -d blog_db -t -c "SELECT version();" 2>/dev/null | head -1 | xargs)
    echo -e "${CYAN}  版本: ${VERSION:0:50}...${NC}"
else
    echo -e "${RED}  ✗ 主库无法连接${NC}"
fi
echo ""

# 检查备库1
echo -e "${BOLD}2. 备库1状态 (端口 5434)${NC}"
if docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-standby1 pg_isready -U bloguser > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ 备库1运行正常${NC}"
    
    # 检查是否处于恢复模式
    IN_RECOVERY=$(docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-standby1 \
        psql -U bloguser -d blog_db -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' \n')
    
    if [ "$IN_RECOVERY" = "t" ]; then
        echo -e "${GREEN}  ✓ 处于恢复模式（只读）${NC}"
    else
        echo -e "${YELLOW}  ⚠ 未处于恢复模式${NC}"
    fi
else
    echo -e "${RED}  ✗ 备库1无法连接${NC}"
fi
echo ""

# 检查备库2
echo -e "${BOLD}3. 备库2状态 (端口 5436)${NC}"
if docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-standby2 pg_isready -U bloguser > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ 备库2运行正常${NC}"
    
    # 检查是否处于恢复模式
    IN_RECOVERY=$(docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-standby2 \
        psql -U bloguser -d blog_db -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' \n')
    
    if [ "$IN_RECOVERY" = "t" ]; then
        echo -e "${GREEN}  ✓ 处于恢复模式（只读）${NC}"
    else
        echo -e "${YELLOW}  ⚠ 未处于恢复模式${NC}"
    fi
else
    echo -e "${RED}  ✗ 备库2无法连接${NC}"
fi
echo ""

# 检查主库复制状态
echo -e "${BOLD}4. 主备复制状态${NC}"
REPL_COUNT=$(docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-primary \
    psql -U bloguser -d blog_db -t -c "SELECT count(*) FROM pg_stat_replication;" 2>/dev/null | tr -d ' \n')

if [ "$REPL_COUNT" = "2" ]; then
    echo -e "${GREEN}  ✓ 2/2 备库已连接${NC}"
elif [ "$REPL_COUNT" = "1" ]; then
    echo -e "${YELLOW}  ⚠ 1/2 备库已连接${NC}"
else
    echo -e "${RED}  ✗ 无备库连接${NC}"
fi

# 显示复制详情
docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-primary \
    psql -U bloguser -d blog_db -c "SELECT application_name, state, sync_state FROM pg_stat_replication;" 2>/dev/null | grep -v "^$" || true
echo ""

# 读写测试
echo -e "${BOLD}5. 读写功能测试${NC}"

# 写入测试数据到主库
TIMESTAMP=$(date +%s)
TEST_RESULT=$(docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-primary \
    psql -U bloguser -d blog_db -t -c "CREATE TABLE IF NOT EXISTS health_check (id SERIAL PRIMARY KEY, timestamp BIGINT); INSERT INTO health_check (timestamp) VALUES ($TIMESTAMP) RETURNING id;" 2>/dev/null | tr -d ' \n')

if [ -n "$TEST_RESULT" ]; then
    echo -e "${GREEN}  ✓ 主库写入成功 (ID: $TEST_RESULT)${NC}"
    
    # 等待复制
    sleep 2
    
    # 从备库1读取
    STANDBY1_DATA=$(docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-standby1 \
        psql -U bloguser -d blog_db -t -c "SELECT count(*) FROM health_check WHERE timestamp = $TIMESTAMP;" 2>/dev/null | tr -d ' \n')
    
    if [ "$STANDBY1_DATA" = "1" ]; then
        echo -e "${GREEN}  ✓ 备库1读取成功 (数据已同步)${NC}"
    else
        echo -e "${YELLOW}  ⚠ 备库1数据未同步${NC}"
    fi
    
    # 从备库2读取
    STANDBY2_DATA=$(docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-standby2 \
        psql -U bloguser -d blog_db -t -c "SELECT count(*) FROM health_check WHERE timestamp = $TIMESTAMP;" 2>/dev/null | tr -d ' \n')
    
    if [ "$STANDBY2_DATA" = "1" ]; then
        echo -e "${GREEN}  ✓ 备库2读取成功 (数据已同步)${NC}"
    else
        echo -e "${YELLOW}  ⚠ 备库2数据未同步${NC}"
    fi
    
    # 清理测试数据
    docker-compose -f docker-compose-gaussdb-cluster.yml exec -T gaussdb-primary \
        psql -U bloguser -d blog_db -c "DELETE FROM health_check WHERE timestamp = $TIMESTAMP;" > /dev/null 2>&1
else
    echo -e "${RED}  ✗ 主库写入失败${NC}"
fi
echo ""

echo -e "${BOLD}${CYAN}=========================================${NC}"
echo -e "${BOLD}${CYAN}  检查完成  ${NC}"
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo ""
