#!/bin/bash

###############################################################
# 前端服务健康检查脚本
###############################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

FRONTEND_URL="http://localhost:8080"
BACKEND_URL="http://localhost:8081"

echo ""
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo -e "${BOLD}${CYAN}  前端服务健康检查  ${NC}"
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo ""

# 1. 前端可访问性
echo -e "${BOLD}1. 前端可访问性测试${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${FRONTEND_URL} 2>/dev/null)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ 前端可访问 (HTTP ${HTTP_CODE})${NC}"
else
    echo -e "${RED}  ✗ 前端访问失败 (HTTP ${HTTP_CODE})${NC}"
fi
echo ""

# 2. 静态资源检查
echo -e "${BOLD}2. 静态资源检查${NC}"

# 检查 index.html
echo -n "  /index.html ..."
INDEX_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${FRONTEND_URL}/index.html 2>/dev/null)
if [ "$INDEX_CODE" = "200" ]; then
    echo -e " ${GREEN}✓ 200${NC}"
else
    echo -e " ${RED}✗ ${INDEX_CODE}${NC}"
fi

# 检查 favicon
echo -n "  /favicon.ico ..."
FAVICON_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${FRONTEND_URL}/favicon.ico 2>/dev/null)
if [ "$FAVICON_CODE" = "200" ]; then
    echo -e " ${GREEN}✓ 200${NC}"
else
    echo -e " ${YELLOW}⚠ ${FAVICON_CODE}${NC}"
fi

echo ""

# 3. API 代理测试
echo -e "${BOLD}3. API 代理功能测试${NC}"
echo -n "  前端 -> 后端 API 代理 ..."

# 通过前端访问后端 API
PROXY_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${FRONTEND_URL}/api/posts/list 2>/dev/null)

if [ "$PROXY_CODE" = "200" ]; then
    echo -e " ${GREEN}✓ 代理正常 (${PROXY_CODE})${NC}"
else
    echo -e " ${RED}✗ 代理失败 (${PROXY_CODE})${NC}"
fi
echo ""

# 4. 响应时间测试
echo -e "${BOLD}4. 响应时间测试${NC}"
START_TIME=$(date +%s%N)
curl -s ${FRONTEND_URL} > /dev/null 2>&1
END_TIME=$(date +%s%N)
RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))

if [ $RESPONSE_TIME -lt 200 ]; then
    echo -e "${GREEN}  ✓ 响应时间: ${RESPONSE_TIME}ms (优秀)${NC}"
elif [ $RESPONSE_TIME -lt 500 ]; then
    echo -e "${YELLOW}  ⚠ 响应时间: ${RESPONSE_TIME}ms (良好)${NC}"
else
    echo -e "${RED}  ✗ 响应时间: ${RESPONSE_TIME}ms (较慢)${NC}"
fi
echo ""

# 5. Nginx 配置检查
echo -e "${BOLD}5. Nginx 配置检查${NC}"
NGINX_CONFIG=$(docker exec blogcircle-frontend cat /etc/nginx/conf.d/default.conf 2>/dev/null)

if echo "$NGINX_CONFIG" | grep -q "proxy_pass"; then
    echo -e "${GREEN}  ✓ API 代理配置已启用${NC}"
    
    # 显示代理配置
    PROXY_CONFIG=$(echo "$NGINX_CONFIG" | grep "proxy_pass" | head -1 | xargs)
    echo -e "${CYAN}  配置: ${PROXY_CONFIG}${NC}"
else
    echo -e "${YELLOW}  ⚠ 未检测到 API 代理配置${NC}"
fi
echo ""

# 6. 容器状态
echo -e "${BOLD}6. 容器状态${NC}"
CONTAINER_STATUS=$(docker inspect blogcircle-frontend --format '{{.State.Status}}' 2>/dev/null || echo "not found")

if [ "$CONTAINER_STATUS" = "running" ]; then
    echo -e "${GREEN}  ✓ 容器运行中${NC}"
    
    # 获取资源使用情况
    STATS=$(docker stats blogcircle-frontend --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | tail -1)
    if [ -n "$STATS" ]; then
        echo -e "${CYAN}  资源使用: ${STATS}${NC}"
    fi
else
    echo -e "${RED}  ✗ 容器状态: ${CONTAINER_STATUS}${NC}"
fi
echo ""

# 7. Nginx 访问日志（最后5条）
echo -e "${BOLD}7. Nginx 访问日志（最后5条）${NC}"
docker exec blogcircle-frontend tail -5 /var/log/nginx/access.log 2>/dev/null | sed 's/^/  /' || \
    echo -e "${YELLOW}  ⚠ 无法访问日志${NC}"
echo ""

echo -e "${BOLD}${CYAN}=========================================${NC}"
echo -e "${BOLD}${CYAN}  检查完成  ${NC}"
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo ""
