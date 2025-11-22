#!/bin/bash

###############################################################
# 后端服务健康检查脚本
###############################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

BACKEND_URL="http://localhost:8081"

echo ""
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo -e "${BOLD}${CYAN}  后端服务健康检查  ${NC}"
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo ""

# 1. 健康检查端点
echo -e "${BOLD}1. Spring Boot Actuator 健康检查${NC}"
HEALTH=$(curl -s ${BACKEND_URL}/actuator/health 2>/dev/null || echo "{}")
STATUS=$(echo $HEALTH | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

if [ "$STATUS" = "UP" ]; then
    echo -e "${GREEN}  ✓ 服务状态: UP${NC}"
else
    echo -e "${RED}  ✗ 服务状态: ${STATUS:-UNKNOWN}${NC}"
fi

# 显示组件状态
if echo "$HEALTH" | grep -q "components"; then
    echo -e "${CYAN}  组件状态:${NC}"
    echo "$HEALTH" | python3 -m json.tool 2>/dev/null | grep -A1 "components" | tail -5 || echo "$HEALTH"
fi
echo ""

# 2. 数据库连接测试
echo -e "${BOLD}2. 数据库连接测试${NC}"
DB_STATUS=$(echo $HEALTH | grep -o '"db":{"status":"[^"]*"' | cut -d'"' -f6)

if [ "$DB_STATUS" = "UP" ]; then
    echo -e "${GREEN}  ✓ 数据库连接: UP${NC}"
else
    echo -e "${RED}  ✗ 数据库连接: ${DB_STATUS:-UNKNOWN}${NC}"
fi
echo ""

# 3. API 端点测试
echo -e "${BOLD}3. API 端点测试${NC}"

# 测试文章列表 API
echo -n "  /api/posts/list ..."
POSTS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" ${BACKEND_URL}/api/posts/list 2>/dev/null)
if [ "$POSTS_RESPONSE" = "200" ]; then
    echo -e " ${GREEN}✓ 200${NC}"
else
    echo -e " ${RED}✗ ${POSTS_RESPONSE}${NC}"
fi

# 测试用户注册 API（仅检查端点可达性）
echo -n "  /api/users/register ..."
REGISTER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    ${BACKEND_URL}/api/users/register 2>/dev/null)
if [ "$REGISTER_RESPONSE" = "200" ] || [ "$REGISTER_RESPONSE" = "400" ]; then
    echo -e " ${GREEN}✓ ${REGISTER_RESPONSE}${NC}"
else
    echo -e " ${YELLOW}⚠ ${REGISTER_RESPONSE}${NC}"
fi

# 测试登录 API（仅检查端点可达性）
echo -n "  /api/users/login ..."
LOGIN_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    ${BACKEND_URL}/api/users/login 2>/dev/null)
if [ "$LOGIN_RESPONSE" = "200" ] || [ "$LOGIN_RESPONSE" = "400" ] || [ "$LOGIN_RESPONSE" = "401" ]; then
    echo -e " ${GREEN}✓ ${LOGIN_RESPONSE}${NC}"
else
    echo -e " ${YELLOW}⚠ ${LOGIN_RESPONSE}${NC}"
fi

# 测试统计 API
echo -n "  /api/statistics/overview ..."
STATS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" ${BACKEND_URL}/api/statistics/overview 2>/dev/null)
if [ "$STATS_RESPONSE" = "200" ]; then
    echo -e " ${GREEN}✓ 200${NC}"
else
    echo -e " ${YELLOW}⚠ ${STATS_RESPONSE}${NC}"
fi

echo ""

# 4. 响应时间测试
echo -e "${BOLD}4. 响应时间测试${NC}"
START_TIME=$(date +%s%N)
curl -s ${BACKEND_URL}/api/posts/list > /dev/null 2>&1
END_TIME=$(date +%s%N)
RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))

if [ $RESPONSE_TIME -lt 500 ]; then
    echo -e "${GREEN}  ✓ 响应时间: ${RESPONSE_TIME}ms (优秀)${NC}"
elif [ $RESPONSE_TIME -lt 1000 ]; then
    echo -e "${YELLOW}  ⚠ 响应时间: ${RESPONSE_TIME}ms (良好)${NC}"
else
    echo -e "${RED}  ✗ 响应时间: ${RESPONSE_TIME}ms (较慢)${NC}"
fi
echo ""

# 5. 容器状态
echo -e "${BOLD}5. 容器状态${NC}"
CONTAINER_STATUS=$(docker inspect blogcircle-backend --format '{{.State.Status}}' 2>/dev/null || echo "not found")
if [ "$CONTAINER_STATUS" = "running" ]; then
    echo -e "${GREEN}  ✓ 容器运行中${NC}"
    
    # 获取资源使用情况
    STATS=$(docker stats blogcircle-backend --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | tail -1)
    if [ -n "$STATS" ]; then
        echo -e "${CYAN}  资源使用: ${STATS}${NC}"
    fi
else
    echo -e "${RED}  ✗ 容器状态: ${CONTAINER_STATUS}${NC}"
fi
echo ""

# 6. 日志检查（最后10行）
echo -e "${BOLD}6. 最近日志（最后5行）${NC}"
docker logs blogcircle-backend --tail 5 2>&1 | sed 's/^/  /'
echo ""

echo -e "${BOLD}${CYAN}=========================================${NC}"
echo -e "${BOLD}${CYAN}  检查完成  ${NC}"
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo ""
