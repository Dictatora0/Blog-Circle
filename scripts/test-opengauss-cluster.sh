#!/bin/bash

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

echo "========================================"
echo "openGauss 集群测试脚本"
echo "========================================"

# 1. 测试主库
echo -e "\n${YELLOW}=== 测试主库 ===${NC}"
if docker exec opengauss-primary su - omm -c "gsql -d blog_db -c 'SELECT version()'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 主库连接正常${NC}"
    docker exec opengauss-primary su - omm -c "gsql -d blog_db -c 'SELECT version()'" | head -3
else
    echo -e "${RED}✗ 主库连接失败${NC}"
    ((ERRORS++))
fi

# 2. 测试备库1
echo -e "\n${YELLOW}=== 测试备库1 ===${NC}"
if docker exec opengauss-standby1 su - omm -c "gsql -d blog_db -c 'SELECT 1'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 备库1连接正常${NC}"
    # 检查是否处于恢复模式
    RECOVERY1=$(docker exec opengauss-standby1 su - omm -c "gsql -d blog_db -t -c 'SELECT pg_is_in_recovery()'" | tr -d ' \n')
    if [ "$RECOVERY1" = "t" ]; then
        echo -e "${GREEN}✓ 备库1处于恢复模式（只读）${NC}"
    else
        echo -e "${RED}✗ 备库1不在恢复模式${NC}"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗ 备库1连接失败${NC}"
    ((ERRORS++))
fi

# 3. 测试备库2
echo -e "\n${YELLOW}=== 测试备库2 ===${NC}"
if docker exec opengauss-standby2 su - omm -c "gsql -d blog_db -c 'SELECT 1'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 备库2连接正常${NC}"
    # 检查是否处于恢复模式
    RECOVERY2=$(docker exec opengauss-standby2 su - omm -c "gsql -d blog_db -t -c 'SELECT pg_is_in_recovery()'" | tr -d ' \n')
    if [ "$RECOVERY2" = "t" ]; then
        echo -e "${GREEN}✓ 备库2处于恢复模式（只读）${NC}"
    else
        echo -e "${RED}✗ 备库2不在恢复模式${NC}"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗ 备库2连接失败${NC}"
    ((ERRORS++))
fi

# 4. 测试复制状态
echo -e "\n${YELLOW}=== 测试复制状态 ===${NC}"
REPLICATION_COUNT=$(docker exec opengauss-primary su - omm -c "gsql -d blog_db -t -c 'SELECT count(*) FROM pg_stat_replication'" | tr -d ' \n')
echo "当前复制连接数: $REPLICATION_COUNT"
if [ "$REPLICATION_COUNT" = "2" ]; then
    echo -e "${GREEN}✓ 2/2 备库已连接${NC}"
    docker exec opengauss-primary su - omm -c "gsql -d blog_db -c 'SELECT application_name, state, sync_state FROM pg_stat_replication'"
else
    echo -e "${RED}✗ 复制连接数不正确（期望: 2, 实际: $REPLICATION_COUNT）${NC}"
    ((ERRORS++))
fi

# 5. 测试读写功能
echo -e "\n${YELLOW}=== 测试读写功能 ===${NC}"

# 在主库写入测试数据
TIMESTAMP=$(date +%s)
docker exec opengauss-primary su - omm -c "gsql -d blog_db -c 'CREATE TABLE IF NOT EXISTS health_check (id SERIAL PRIMARY KEY, timestamp BIGINT)'" >/dev/null 2>&1
docker exec opengauss-primary su - omm -c "gsql -d blog_db -c \"INSERT INTO health_check (timestamp) VALUES ($TIMESTAMP)\" >/dev/null 2>&1
echo -e "${GREEN}✓ 主库写入成功${NC}"

# 等待复制
sleep 3

# 从备库1读取
if READ1=$(docker exec opengauss-standby1 su - omm -c "gsql -d blog_db -t -c 'SELECT timestamp FROM health_check ORDER BY id DESC LIMIT 1'" 2>/dev/null | tr -d ' \n'); then
    if [ "$READ1" = "$TIMESTAMP" ]; then
        echo -e "${GREEN}✓ 备库1数据同步成功${NC}"
    else
        echo -e "${RED}✗ 备库1数据不一致（期望: $TIMESTAMP, 实际: $READ1）${NC}"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗ 备库1读取失败${NC}"
    ((ERRORS++))
fi

# 从备库2读取
if READ2=$(docker exec opengauss-standby2 su - omm -c "gsql -d blog_db -t -c 'SELECT timestamp FROM health_check ORDER BY id DESC LIMIT 1'" 2>/dev/null | tr -d ' \n'); then
    if [ "$READ2" = "$TIMESTAMP" ]; then
        echo -e "${GREEN}✓ 备库2数据同步成功${NC}"
    else
        echo -e "${RED}✗ 备库2数据不一致（期望: $TIMESTAMP, 实际: $READ2）${NC}"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗ 备库2读取失败${NC}"
    ((ERRORS++))
fi

# 清理测试数据
docker exec opengauss-primary su - omm -c "gsql -d blog_db -c 'DROP TABLE IF EXISTS health_check'" >/dev/null 2>&1

# 6. 测试后端服务
echo -e "\n${YELLOW}=== 测试后端服务 ===${NC}"
if curl -s http://localhost:8082/actuator/health | grep -q '"status":"UP"'; then
    echo -e "${GREEN}✓ 后端服务健康${NC}"
else
    echo -e "${RED}✗ 后端服务异常${NC}"
    ((ERRORS++))
fi

# 7. 测试前端服务
echo -e "\n${YELLOW}=== 测试前端服务 ===${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ 前端服务正常 (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ 前端服务异常 (HTTP $HTTP_CODE)${NC}"
    ((ERRORS++))
fi

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
