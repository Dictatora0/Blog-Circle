#!/bin/bash

################################################################################
# Blog Circle API 完整测试套件
# 测试所有 REST API 端点，包括正常和异常场景
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
BACKEND_URL=${BACKEND_URL:-http://localhost:8081}
TEST_LOG="./test-logs/api-test-$(date +%Y%m%d-%H%M%S).log"
mkdir -p ./test-logs

# 测试统计
TOTAL_API_TESTS=0
PASSED_API_TESTS=0
FAILED_API_TESTS=0

# 测试数据
TEST_USERNAME="apitest_$(date +%s)"
TEST_PASSWORD="Test@123456"
TEST_EMAIL="apitest_$(date +%s)@example.com"
AUTH_TOKEN=""
USER_ID=""
POST_ID=""
COMMENT_ID=""

################################################################################
# 工具函数
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_LOG"
    ((PASSED_API_TESTS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_LOG"
    ((FAILED_API_TESTS++))
}

test_api() {
    ((TOTAL_API_TESTS++))
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local expected_code="$4"
    local description="$5"
    
    log_info "Testing: $description"
    log_info "  $method $endpoint"
    
    local headers=(-H "Content-Type: application/json")
    if [ -n "$AUTH_TOKEN" ]; then
        headers+=(-H "Authorization: Bearer $AUTH_TOKEN")
    fi
    
    local response
    local http_code
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "${headers[@]}" "$BACKEND_URL$endpoint")
    elif [ "$method" = "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST "${headers[@]}" -d "$data" "$BACKEND_URL$endpoint")
    elif [ "$method" = "PUT" ]; then
        response=$(curl -s -w "\n%{http_code}" -X PUT "${headers[@]}" -d "$data" "$BACKEND_URL$endpoint")
    elif [ "$method" = "DELETE" ]; then
        response=$(curl -s -w "\n%{http_code}" -X DELETE "${headers[@]}" "$BACKEND_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    echo "$body" >> "$TEST_LOG"
    
    if [ "$http_code" = "$expected_code" ]; then
        log_success "$description - HTTP $http_code"
        echo "$body"
        return 0
    else
        log_error "$description - Expected $expected_code, got $http_code"
        echo "$body"
        return 1
    fi
}

################################################################################
# 1. 认证 API 测试
################################################################################

test_auth_apis() {
    log_info "=== 1. 认证 API 测试 ==="
    
    # 1.1 用户注册 - 正常场景
    local register_data='{
        "username": "'$TEST_USERNAME'",
        "password": "'$TEST_PASSWORD'",
        "email": "'$TEST_EMAIL'",
        "nickname": "API测试用户"
    }'
    
    local response=$(test_api "POST" "/api/auth/register" "$register_data" "200" "用户注册（正常）")
    USER_ID=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    
    # 1.2 用户注册 - 重复用户名
    test_api "POST" "/api/auth/register" "$register_data" "400" "用户注册（重复用户名）" || true
    
    # 1.3 用户注册 - 无效密码
    local invalid_pwd_data='{
        "username": "test_invalid",
        "password": "123",
        "email": "invalid@test.com"
    }'
    test_api "POST" "/api/auth/register" "$invalid_pwd_data" "400" "用户注册（无效密码）" || true
    
    # 1.4 用户登录 - 正常场景
    local login_data='{
        "username": "'$TEST_USERNAME'",
        "password": "'$TEST_PASSWORD'"
    }'
    
    local login_response=$(test_api "POST" "/api/auth/login" "$login_data" "200" "用户登录（正常）")
    AUTH_TOKEN=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    log_info "获取到 Token: ${AUTH_TOKEN:0:30}..."
    
    # 1.5 用户登录 - 错误密码
    local wrong_pwd_data='{
        "username": "'$TEST_USERNAME'",
        "password": "WrongPassword123"
    }'
    test_api "POST" "/api/auth/login" "$wrong_pwd_data" "401" "用户登录（错误密码）" || true
    
    # 1.6 用户登录 - 不存在的用户
    local nonexist_data='{
        "username": "nonexistent_user_12345",
        "password": "Test@123"
    }'
    test_api "POST" "/api/auth/login" "$nonexist_data" "401" "用户登录（不存在的用户）" || true
}

################################################################################
# 2. 文章 API 测试
################################################################################

test_post_apis() {
    log_info "=== 2. 文章 API 测试 ==="
    
    # 2.1 获取文章列表
    test_api "GET" "/api/posts/list?page=1&size=10" "" "200" "获取文章列表"
    
    # 2.2 创建文章 - 需要认证
    local create_post_data='{
        "title": "API测试文章",
        "content": "这是通过API测试创建的文章内容",
        "summary": "测试摘要"
    }'
    
    local post_response=$(test_api "POST" "/api/posts" "$create_post_data" "200" "创建文章（需认证）")
    POST_ID=$(echo "$post_response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    log_info "创建的文章 ID: $POST_ID"
    
    # 2.3 创建文章 - 无认证
    AUTH_TOKEN_BACKUP="$AUTH_TOKEN"
    AUTH_TOKEN=""
    test_api "POST" "/api/posts" "$create_post_data" "401" "创建文章（无认证）" || true
    AUTH_TOKEN="$AUTH_TOKEN_BACKUP"
    
    # 2.4 获取文章详情
    if [ -n "$POST_ID" ]; then
        test_api "GET" "/api/posts/$POST_ID" "" "200" "获取文章详情"
    fi
    
    # 2.5 更新文章
    if [ -n "$POST_ID" ]; then
        local update_post_data='{
            "title": "API测试文章（已更新）",
            "content": "更新后的文章内容",
            "summary": "更新后的摘要"
        }'
        test_api "PUT" "/api/posts/$POST_ID" "$update_post_data" "200" "更新文章"
    fi
    
    # 2.6 点赞文章
    if [ -n "$POST_ID" ]; then
        test_api "POST" "/api/posts/$POST_ID/like" "" "200" "点赞文章"
    fi
    
    # 2.7 取消点赞
    if [ -n "$POST_ID" ]; then
        test_api "DELETE" "/api/posts/$POST_ID/like" "" "200" "取消点赞"
    fi
    
    # 2.8 获取好友时间线
    test_api "GET" "/api/posts/timeline?page=1&size=10" "" "200" "获取好友时间线"
}

################################################################################
# 3. 评论 API 测试
################################################################################

test_comment_apis() {
    log_info "=== 3. 评论 API 测试 ==="
    
    if [ -z "$POST_ID" ]; then
        log_info "跳过评论测试（无文章 ID）"
        return
    fi
    
    # 3.1 获取文章评论列表
    test_api "GET" "/api/comments/post/$POST_ID" "" "200" "获取文章评论列表"
    
    # 3.2 创建评论
    local create_comment_data='{
        "postId": '$POST_ID',
        "content": "这是一条API测试评论"
    }'
    
    local comment_response=$(test_api "POST" "/api/comments" "$create_comment_data" "200" "创建评论")
    COMMENT_ID=$(echo "$comment_response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    log_info "创建的评论 ID: $COMMENT_ID"
    
    # 3.3 更新评论
    if [ -n "$COMMENT_ID" ]; then
        local update_comment_data='{
            "content": "这是更新后的评论内容"
        }'
        test_api "PUT" "/api/comments/$COMMENT_ID" "$update_comment_data" "200" "更新评论"
    fi
    
    # 3.4 删除评论
    if [ -n "$COMMENT_ID" ]; then
        test_api "DELETE" "/api/comments/$COMMENT_ID" "" "200" "删除评论"
    fi
}

################################################################################
# 4. 好友 API 测试
################################################################################

test_friend_apis() {
    log_info "=== 4. 好友 API 测试 ==="
    
    # 4.1 搜索用户
    test_api "GET" "/api/friends/search?keyword=test" "" "200" "搜索用户"
    
    # 4.2 获取好友列表
    test_api "GET" "/api/friends/list" "" "200" "获取好友列表"
    
    # 4.3 获取好友请求列表
    test_api "GET" "/api/friends/requests" "" "200" "获取好友请求列表"
    
    # 4.4 发送好友请求（需要另一个用户ID，这里跳过实际测试）
    log_info "跳过发送好友请求测试（需要目标用户ID）"
}

################################################################################
# 5. 统计 API 测试
################################################################################

test_statistics_apis() {
    log_info "=== 5. 统计 API 测试 ==="
    
    # 5.1 获取统计汇总
    test_api "GET" "/api/stats" "" "200" "获取统计汇总"
    
    # 5.2 获取聚合统计
    test_api "GET" "/api/stats/aggregated" "" "200" "获取聚合统计"
    
    # 5.3 获取统计明细列表
    test_api "GET" "/api/stats/list" "" "200" "获取统计明细列表"
    
    # 5.4 按类型获取统计
    test_api "GET" "/api/stats/USER_POST_COUNT" "" "200" "按类型获取统计（用户发文）"
    
    # 5.5 触发统计分析
    test_api "POST" "/api/stats/analyze" "" "200" "触发统计分析" || true
}

################################################################################
# 6. 用户 API 测试
################################################################################

test_user_apis() {
    log_info "=== 6. 用户 API 测试 ==="
    
    # 6.1 获取当前用户信息
    test_api "GET" "/api/users/me" "" "200" "获取当前用户信息"
    
    # 6.2 更新用户信息
    local update_user_data='{
        "nickname": "API测试用户（已更新）",
        "bio": "这是更新后的个人简介"
    }'
    test_api "PUT" "/api/users/me" "$update_user_data" "200" "更新用户信息"
    
    # 6.3 获取用户详情（通过ID）
    if [ -n "$USER_ID" ]; then
        test_api "GET" "/api/users/$USER_ID" "" "200" "获取用户详情"
    fi
}

################################################################################
# 7. 上传 API 测试
################################################################################

test_upload_apis() {
    log_info "=== 7. 上传 API 测试 ==="
    
    # 创建测试图片
    local test_image="/tmp/test_image_$$.png"
    # 创建一个简单的 1x1 PNG 图片
    echo -e '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > "$test_image"
    
    # 7.1 上传头像
    log_info "测试头像上传"
    local upload_response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -F "file=@$test_image" \
        "$BACKEND_URL/api/upload/avatar")
    
    local http_code=$(echo "$upload_response" | tail -n1)
    if [ "$http_code" = "200" ]; then
        log_success "头像上传成功"
        ((PASSED_API_TESTS++))
    else
        log_error "头像上传失败 - HTTP $http_code"
        ((FAILED_API_TESTS++))
    fi
    ((TOTAL_API_TESTS++))
    
    # 清理测试文件
    rm -f "$test_image"
}

################################################################################
# 清理测试数据
################################################################################

cleanup_test_data() {
    log_info "=== 清理测试数据 ==="
    
    # 删除测试文章
    if [ -n "$POST_ID" ]; then
        log_info "删除测试文章 ID: $POST_ID"
        test_api "DELETE" "/api/posts/$POST_ID" "" "200" "删除测试文章" || true
    fi
    
    log_info "测试数据清理完成"
}

################################################################################
# 生成测试报告
################################################################################

generate_api_report() {
    log_info "=== API 测试报告 ==="
    echo ""
    echo "========================================" | tee -a "$TEST_LOG"
    echo "  Blog Circle API 测试报告" | tee -a "$TEST_LOG"
    echo "========================================" | tee -a "$TEST_LOG"
    echo "测试时间: $(date)" | tee -a "$TEST_LOG"
    echo "后端地址: $BACKEND_URL" | tee -a "$TEST_LOG"
    echo "总API测试数: $TOTAL_API_TESTS" | tee -a "$TEST_LOG"
    echo -e "${GREEN}通过: $PASSED_API_TESTS${NC}" | tee -a "$TEST_LOG"
    echo -e "${RED}失败: $FAILED_API_TESTS${NC}" | tee -a "$TEST_LOG"
    
    if [ $TOTAL_API_TESTS -gt 0 ]; then
        local pass_rate=$(awk "BEGIN {printf \"%.2f\", ($PASSED_API_TESTS/$TOTAL_API_TESTS)*100}")
        echo "通过率: ${pass_rate}%" | tee -a "$TEST_LOG"
    fi
    
    echo "========================================" | tee -a "$TEST_LOG"
    echo ""
    echo "详细日志: $TEST_LOG"
    
    if [ $FAILED_API_TESTS -eq 0 ]; then
        log_success "所有 API 测试通过！"
        return 0
    else
        log_error "存在失败的 API 测试，请查看日志"
        return 1
    fi
}

################################################################################
# 主函数
################################################################################

main() {
    echo "========================================="
    echo "  Blog Circle API 完整测试套件"
    echo "========================================="
    echo ""
    
    log_info "后端地址: $BACKEND_URL"
    log_info "测试日志: $TEST_LOG"
    echo ""
    
    # 等待后端就绪
    log_info "等待后端服务就绪..."
    local max_retries=30
    local retry=0
    while [ $retry -lt $max_retries ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/actuator/health" | grep -q "200"; then
            log_success "后端服务已就绪"
            break
        fi
        ((retry++))
        sleep 2
    done
    
    if [ $retry -eq $max_retries ]; then
        log_error "后端服务启动超时"
        exit 1
    fi
    
    # 执行测试
    test_auth_apis
    test_post_apis
    test_comment_apis
    test_friend_apis
    test_statistics_apis
    test_user_apis
    test_upload_apis
    
    # 清理
    cleanup_test_data
    
    # 生成报告
    generate_api_report
}

# 运行主函数
main "$@"
