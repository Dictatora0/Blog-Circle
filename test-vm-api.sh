#!/bin/bash

###############################################################
# Blog Circle 虚拟机 API 测试脚本
# 测试所有主要 API 功能
###############################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 加载环境变量
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# 虚拟机配置（在 .env 中提供）
if [ -z "${VM_IP}" ] || [ -z "${HOST_BACKEND_PORT}" ] || [ -z "${HOST_FRONTEND_PORT}" ]; then
    echo -e "${RED}VM_IP / HOST_BACKEND_PORT / HOST_FRONTEND_PORT 未配置，请在 .env 中设置${NC}"
    exit 1
fi

VM_IP="${VM_IP}"
HOST_BACKEND_PORT="${HOST_BACKEND_PORT}"
HOST_FRONTEND_PORT="${HOST_FRONTEND_PORT}"
BASE_URL="http://${VM_IP}:${HOST_BACKEND_PORT}"
FRONTEND_URL="http://${VM_IP}:${HOST_FRONTEND_PORT}"

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 临时文件
COOKIE_FILE="/tmp/blogcircle_test_cookies.txt"
TEST_LOG="/tmp/blogcircle_test_log.txt"
rm -f "$COOKIE_FILE" "$TEST_LOG"

# 测试用户数据
TEST_USERNAME="testuser_$(date +%s)"
TEST_PASSWORD="Test@123456"
TEST_EMAIL="${TEST_USERNAME}@test.com"
AUTH_TOKEN=""
USER_ID=""

echo ""
echo -e "${BOLD}${CYAN}Blog Circle API 测试${NC}"
echo -e "${CYAN}API Testing Suite${NC}"
echo ""
echo -e "${BLUE}测试目标: ${BASE_URL}${NC}"
echo ""

# 辅助函数：打印测试标题
print_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${YELLOW}----------------------------------------${NC}"
    echo -e "${BOLD}[测试 ${TOTAL_TESTS}] $1${NC}"
    echo -e "${YELLOW}----------------------------------------${NC}"
}

# 辅助函数：检查响应
check_response() {
    local response="$1"
    local expected_code="$2"
    local test_name="$3"
    
    # 提取 HTTP 状态码
    local http_code=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | sed '$d')
    
    echo "HTTP 状态码: $http_code"
    echo "响应内容: $body" | head -c 500
    echo ""
    
    if [ "$http_code" = "$expected_code" ]; then
        echo -e "${GREEN}测试通过${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo "$test_name: PASSED" >> "$TEST_LOG"
        echo "$body"
        return 0
    else
        echo -e "${RED}测试失败 (期望: $expected_code, 实际: $http_code)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "$test_name: FAILED (Expected: $expected_code, Got: $http_code)" >> "$TEST_LOG"
        return 1
    fi
}

echo -e "${CYAN}开始 API 测试...${NC}"
echo ""
sleep 1

###############################################################
# 测试 1: 健康检查
###############################################################
print_test "健康检查 API"
response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/actuator/health")
if check_response "$response" "200" "健康检查"; then
    echo -e "${GREEN}系统运行正常${NC}"
fi
echo ""
sleep 1

###############################################################
# 测试 2: 前端可访问性
###############################################################
print_test "前端页面可访问性"
response=$(curl -s -w "\n%{http_code}" "${FRONTEND_URL}/")
if check_response "$response" "200" "前端访问"; then
    echo -e "${GREEN}前端页面可访问${NC}"
fi
echo ""
sleep 1

###############################################################
# 测试 3: 用户注册
###############################################################
print_test "用户注册 API"
echo "注册信息:"
echo "  用户名: $TEST_USERNAME"
echo "  邮箱: $TEST_EMAIL"
echo "  密码: $TEST_PASSWORD"
echo ""

register_response=$(curl -s -w "\n%{http_code}" \
    -X POST "${BASE_URL}/api/auth/register" \
    -H "Content-Type: application/json" \
    -d "{
        \"username\": \"$TEST_USERNAME\",
        \"password\": \"$TEST_PASSWORD\",
        \"email\": \"$TEST_EMAIL\"
    }")

if check_response "$register_response" "200" "用户注册"; then
    echo -e "${GREEN}用户注册成功${NC}"
    # 提取用户 ID
    USER_ID=$(echo "$register_response" | sed '$d' | grep -o '"id":[0-9]*' | sed 's/"id"://')
    echo "用户 ID: $USER_ID"
fi
echo ""
sleep 1

###############################################################
# 测试 4: 用户登录
###############################################################
print_test "用户登录 API"
echo "登录信息:"
echo "  用户名: $TEST_USERNAME"
echo "  密码: $TEST_PASSWORD"
echo ""

login_response=$(curl -s -w "\n%{http_code}" \
    -X POST "${BASE_URL}/api/auth/login" \
    -H "Content-Type: application/json" \
    -c "$COOKIE_FILE" \
    -d "{
        \"username\": \"$TEST_USERNAME\",
        \"password\": \"$TEST_PASSWORD\"
    }")

if check_response "$login_response" "200" "用户登录"; then
    echo -e "${GREEN}用户登录成功${NC}"
    # 提取 token
    AUTH_TOKEN=$(echo "$login_response" | sed '$d' | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')
    echo "认证 Token: ${AUTH_TOKEN:0:50}..."
fi
echo ""
sleep 1

###############################################################
# 测试 5: 获取当前用户信息
###############################################################
print_test "获取当前用户信息 API"
user_info_response=$(curl -s -w "\n%{http_code}" \
    -X GET "${BASE_URL}/api/users/current" \
    -H "Authorization: Bearer $AUTH_TOKEN")

if check_response "$user_info_response" "200" "获取用户信息"; then
    echo -e "${GREEN}成功获取用户信息${NC}"
fi
echo ""
sleep 1

###############################################################
# 测试 6: 发布动态
###############################################################
print_test "发布动态 API"
post_content="这是一条测试动态，发布时间：$(date '+%Y-%m-%d %H:%M:%S')"
echo "动态内容: $post_content"
echo ""

create_post_response=$(curl -s -w "\n%{http_code}" \
    -X POST "${BASE_URL}/api/posts" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"content\": \"$post_content\",
        \"visibility\": \"public\"
    }")

POST_ID=""
if check_response "$create_post_response" "200" "发布动态"; then
    echo -e "${GREEN}动态发布成功${NC}"
    POST_ID=$(echo "$create_post_response" | sed '$d' | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
    echo "动态 ID: $POST_ID"
fi
echo ""
sleep 1

###############################################################
# 测试 7: 获取动态列表
###############################################################
print_test "获取动态列表 API"
get_posts_response=$(curl -s -w "\n%{http_code}" \
    -X GET "${BASE_URL}/api/posts/list" \
    -H "Authorization: Bearer $AUTH_TOKEN")

if check_response "$get_posts_response" "200" "获取动态列表"; then
    echo -e "${GREEN}成功获取动态列表${NC}"
fi
echo ""
sleep 1

###############################################################
# 测试 8: 获取单个动态详情
###############################################################
if [ -n "$POST_ID" ]; then
    print_test "获取动态详情 API"
    get_post_response=$(curl -s -w "\n%{http_code}" \
        -X GET "${BASE_URL}/api/posts/${POST_ID}/detail" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    
    if check_response "$get_post_response" "200" "获取动态详情"; then
        echo -e "${GREEN}成功获取动态详情${NC}"
    fi
    echo ""
    sleep 1
fi

###############################################################
# 测试 9: 点赞动态
###############################################################
if [ -n "$POST_ID" ]; then
    print_test "点赞动态 API"
    echo "点赞动态 ID: $POST_ID"
    echo ""
    
    like_response=$(curl -s -w "\n%{http_code}" \
        -X POST "${BASE_URL}/api/likes/${POST_ID}" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    
    if check_response "$like_response" "200" "点赞动态"; then
        echo -e "${GREEN}点赞成功${NC}"
    fi
    echo ""
    sleep 1
fi

###############################################################
# 测试 10: 评论动态
###############################################################
if [ -n "$POST_ID" ]; then
    print_test "评论动态 API"
    comment_content="这是一条测试评论：$(date '+%H:%M:%S')"
    echo "评论内容: $comment_content"
    echo ""
    
    comment_response=$(curl -s -w "\n%{http_code}" \
        -X POST "${BASE_URL}/api/comments" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"postId\": $POST_ID,
            \"content\": \"$comment_content\"
        }")
    
    COMMENT_ID=""
    if check_response "$comment_response" "200" "发布评论"; then
        echo -e "${GREEN}评论成功${NC}"
        COMMENT_ID=$(echo "$comment_response" | sed '$d' | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
        echo "评论 ID: $COMMENT_ID"
    fi
    echo ""
    sleep 1
fi

###############################################################
# 测试 11: 获取动态评论列表
###############################################################
if [ -n "$POST_ID" ]; then
    print_test "获取评论列表 API"
    get_comments_response=$(curl -s -w "\n%{http_code}" \
        -X GET "${BASE_URL}/api/comments/post/${POST_ID}" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    
    if check_response "$get_comments_response" "200" "获取评论列表"; then
        echo -e "${GREEN}成功获取评论列表${NC}"
    fi
    echo ""
    sleep 1
fi

###############################################################
# 测试 12: 获取我的动态
###############################################################
print_test "获取我的动态 API"
echo ""

my_posts_response=$(curl -s -w "\n%{http_code}" \
    -X GET "${BASE_URL}/api/posts/my" \
    -H "Authorization: Bearer $AUTH_TOKEN")

if check_response "$my_posts_response" "200" "获取我的动态"; then
    echo -e "${GREEN}成功获取我的动态${NC}"
fi
echo ""
sleep 1

###############################################################
# 测试 13: 获取统计数据
###############################################################
print_test "获取统计数据 API"
stats_response=$(curl -s -w "\n%{http_code}" \
    -X GET "${BASE_URL}/api/stats" \
    -H "Authorization: Bearer $AUTH_TOKEN")

if check_response "$stats_response" "200" "获取统计数据"; then
    echo -e "${GREEN}成功获取统计数据${NC}"
fi
echo ""
sleep 1

###############################################################
# 测试 14: 图片上传测试（创建测试图片）
###############################################################
print_test "图片上传 API"
echo "创建测试图片..."

# 创建一个小的测试图片（1x1 PNG）
test_image="/tmp/test_image.png"
echo -n -e '\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\x0a\x49\x44\x41\x54\x78\x9c\x63\x00\x01\x00\x00\x05\x00\x01\x0d\x0a\x2d\xb4\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82' > "$test_image"

upload_response=$(curl -s -w "\n%{http_code}" \
    -X POST "${BASE_URL}/api/upload/image" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -F "file=@${test_image}")

if check_response "$upload_response" "200" "图片上传"; then
    echo -e "${GREEN}图片上传成功${NC}"
    IMAGE_URL=$(echo "$upload_response" | sed '$d' | grep -o '"url":"[^"]*"' | sed 's/"url":"//;s/"//')
    echo "图片 URL: $IMAGE_URL"
fi
rm -f "$test_image"
echo ""
sleep 1

###############################################################
# 测试 15: 取消点赞
###############################################################
if [ -n "$POST_ID" ]; then
    print_test "取消点赞 API"
    echo "取消点赞动态 ID: $POST_ID"
    echo ""
    
    unlike_response=$(curl -s -w "\n%{http_code}" \
        -X DELETE "${BASE_URL}/api/likes/${POST_ID}" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    
    if check_response "$unlike_response" "200" "取消点赞"; then
        echo -e "${GREEN}取消点赞成功${NC}"
    fi
    echo ""
    sleep 1
fi

###############################################################
# 测试 16: 删除评论
###############################################################
if [ -n "$COMMENT_ID" ]; then
    print_test "删除评论 API"
    echo "删除评论 ID: $COMMENT_ID"
    echo ""
    
    delete_comment_response=$(curl -s -w "\n%{http_code}" \
        -X DELETE "${BASE_URL}/api/comments/${COMMENT_ID}" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    
    if check_response "$delete_comment_response" "200" "删除评论"; then
        echo -e "${GREEN}删除评论成功${NC}"
    fi
    echo ""
    sleep 1
fi

###############################################################
# 测试 17: 删除动态
###############################################################
if [ -n "$POST_ID" ]; then
    print_test "删除动态 API"
    echo "删除动态 ID: $POST_ID"
    echo ""
    
    delete_post_response=$(curl -s -w "\n%{http_code}" \
        -X DELETE "${BASE_URL}/api/posts/${POST_ID}" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    
    if check_response "$delete_post_response" "200" "删除动态"; then
        echo -e "${GREEN}删除动态成功${NC}"
    fi
    echo ""
    sleep 1
fi

###############################################################
# 测试 18: openGauss 数据库连接测试
###############################################################
print_test "数据库连接测试"
echo "通过健康检查端点验证数据库连接..."
echo ""

db_health_response=$(curl -s -w "\n%{http_code}" "${BASE_URL}/actuator/health")
db_status=$(echo "$db_health_response" | sed '$d' | grep -o '"db":{"status":"[^"]*"' | sed 's/"db":{"status":"//;s/"//')

# 通过访问 /actuator/health 接口，解析返回的 JSON，从中提取数据库（db）的健康状态（UP / DOWN），供后续自动化脚本判断系统是否可以继续运行

echo "数据库状态: $db_status"
if [ "$db_status" = "UP" ]; then
    echo -e "${GREEN}数据库连接正常${NC}"
    ((PASSED_TESTS++))
    echo "数据库连接测试: PASSED" >> "$TEST_LOG"
else
    echo -e "${RED}数据库连接异常${NC}"
    ((FAILED_TESTS++))
    echo "数据库连接测试: FAILED" >> "$TEST_LOG"
fi
echo ""

###############################################################
# 测试总结
###############################################################
echo ""
echo -e "${BOLD}${CYAN}测试结果总结 (Test Summary)${NC}"
echo ""

echo -e "${BOLD}测试统计：${NC}"
echo -e "  总测试数: ${BOLD}${TOTAL_TESTS}${NC}"
echo -e "  ${GREEN}通过: ${PASSED_TESTS}${NC}"
echo -e "  ${RED}失败: ${FAILED_TESTS}${NC}"
echo ""

PASS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")
echo -e "  通过率: ${BOLD}${PASS_RATE}%${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}${BOLD}所有测试通过，系统运行正常。${NC}"
    echo ""
    echo -e "${CYAN}系统信息：${NC}"
    echo -e "  前端地址: ${FRONTEND_URL}"
    echo -e "  后端地址: ${BASE_URL}"
    echo -e "  健康检查: ${BASE_URL}/actuator/health"
    EXIT_CODE=0
else
    echo -e "${RED}${BOLD}有 ${FAILED_TESTS} 个测试失败，请检查系统。${NC}"
    echo ""
    echo -e "${YELLOW}查看详细日志：${NC}"
    echo -e "  cat $TEST_LOG"
    EXIT_CODE=1
fi

echo ""
echo -e "${BLUE}详细日志已保存到: ${TEST_LOG}${NC}"
echo -e "${BLUE}Cookie 文件: ${COOKIE_FILE}${NC}"
echo ""

# 清理临时文件（可选）
# rm -f "$COOKIE_FILE"

exit $EXIT_CODE
