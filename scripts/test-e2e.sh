#!/bin/bash

###############################################################
# 端到端测试脚本
# 测试完整的前后端功能和数据库集成
###############################################################

set -e

BASE_URL="${1:-http://localhost:8080}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo "========================================="
echo "   端到端功能测试"
echo "========================================="
echo ""
echo "测试地址: $BASE_URL"
echo ""

# 测试函数
test_api() {
    local name="$1"
    local method="$2"
    local url="$3"
    local data="$4"
    local expected="$5"
    
    echo -n "测试: $name ... "
    
    if [ "$method" == "POST" ]; then
        response=$(curl -s -X POST "$BASE_URL$url" \
            -H "Content-Type: application/json" \
            -d "$data" || echo "ERROR")
    elif [ "$method" == "GET" ]; then
        response=$(curl -s -X GET "$BASE_URL$url" || echo "ERROR")
    fi
    
    if echo "$response" | grep -q "$expected"; then
        echo -e "${GREEN}✓ 通过${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ 失败${NC}"
        echo "  响应: $response"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# 1. 健康检查
echo "=== 1. 基础健康检查 ==="
test_api "健康检查" "GET" "/actuator/health" "" "UP"
echo ""

# 2. 用户注册
echo "=== 2. 用户认证测试 ==="
TEST_USER="testuser_$(date +%s)"
test_api "用户注册" "POST" "/api/auth/register" \
    "{\"username\":\"$TEST_USER\",\"password\":\"test123\",\"email\":\"test@test.com\",\"nickname\":\"测试用户\"}" \
    "\"code\":200"

# 3. 用户登录
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEST_USER\",\"password\":\"test123\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"//' | sed 's/"//')

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    echo -e "测试: 用户登录 ... ${GREEN}✓ 通过${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "测试: 用户登录 ... ${RED}✗ 失败${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    echo -e "${RED}无法获取 Token，后续测试跳过${NC}"
    exit 1
fi

# 4. 获取当前用户信息
echo "=== 3. 用户信息测试 ==="
echo -n "测试: 获取当前用户 ... "
USER_RESPONSE=$(curl -s -X GET "$BASE_URL/api/users/current" \
    -H "Authorization: Bearer $TOKEN")
if echo "$USER_RESPONSE" | grep -q "\"code\":200"; then
    echo -e "${GREEN}✓ 通过${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ 失败${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# 5. 创建帖子
echo "=== 4. 帖子功能测试 ==="
POST_RESPONSE=$(curl -s -X POST "$BASE_URL/api/posts" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"测试帖子\",\"content\":\"这是端到端测试创建的帖子\"}")

POST_ID=$(echo "$POST_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')

if [ -n "$POST_ID" ] && [ "$POST_ID" != "null" ]; then
    echo -e "测试: 创建帖子 ... ${GREEN}✓ 通过${NC} (ID: $POST_ID)"
    PASSED=$((PASSED + 1))
else
    echo -e "测试: 创建帖子 ... ${RED}✗ 失败${NC}"
    FAILED=$((FAILED + 1))
fi

# 6. 获取帖子列表
test_api "获取帖子列表" "GET" "/api/posts/list" "" "\"code\":200"

# 7. 获取帖子详情
if [ -n "$POST_ID" ]; then
    test_api "获取帖子详情" "GET" "/api/posts/$POST_ID/detail" "" "\"code\":200"
fi
echo ""

# 8. 点赞功能
if [ -n "$POST_ID" ]; then
    echo "=== 5. 点赞功能测试 ==="
    echo -n "测试: 点赞帖子 ... "
    LIKE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/likes/$POST_ID" \
        -H "Authorization: Bearer $TOKEN")
    if echo "$LIKE_RESPONSE" | grep -q "\"code\":200"; then
        echo -e "${GREEN}✓ 通过${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ 失败${NC}"
        FAILED=$((FAILED + 1))
    fi
    echo ""
fi

# 9. 评论功能
if [ -n "$POST_ID" ]; then
    echo "=== 6. 评论功能测试 ==="
    echo -n "测试: 创建评论 ... "
    COMMENT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/comments" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"postId\":$POST_ID,\"content\":\"这是测试评论\"}")
    if echo "$COMMENT_RESPONSE" | grep -q "\"code\":200"; then
        echo -e "${GREEN}✓ 通过${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ 失败${NC}"
        FAILED=$((FAILED + 1))
    fi
    
    test_api "获取帖子评论" "GET" "/api/comments/post/$POST_ID" "" "\"code\":200"
    echo ""
fi

# 10. 统计功能
echo "=== 7. 统计功能测试 ==="
test_api "获取统计数据" "GET" "/api/stats/aggregated" "" "\"code\":200"
echo ""

# 总结
echo "========================================="
echo "   测试结果统计"
echo "========================================="
TOTAL=$((PASSED + FAILED))
echo "总测试数: $TOTAL"
echo -e "${GREEN}通过: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}失败: $FAILED${NC}"
else
    echo -e "${GREEN}失败: $FAILED${NC}"
fi
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}   所有测试通过！${NC}"
    echo -e "${GREEN}=========================================${NC}"
    exit 0
else
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}   部分测试失败${NC}"
    echo -e "${RED}=========================================${NC}"
    exit 1
fi
