#!/bin/bash

# ========================================
# Blog Circle 后端系统性测试脚本
# ========================================

set -e

BASE_URL="http://localhost:8080"
TEST_LOG="backend-test-results.log"
TEST_USER="testuser_$(date +%s)"
TEST_PASSWORD="Test123456"
TOKEN=""
USER_ID=""
POST_ID=""
COMMENT_ID=""

# 颜色定义
RED='\033[0:31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 初始化日志
echo "========================================" > $TEST_LOG
echo "Blog Circle 后端测试报告" >> $TEST_LOG
echo "测试时间: $(date)" >> $TEST_LOG
echo "========================================" >> $TEST_LOG
echo "" >> $TEST_LOG

# 日志函数
log_test() {
    echo -e "${BLUE}[测试]${NC} $1"
    echo "[测试] $1" >> $TEST_LOG
}

log_success() {
    echo -e "${GREEN}[通过]${NC} $1"
    echo "[通过] $1" >> $TEST_LOG
}

log_error() {
    echo -e "${RED}[✗ 失败]${NC} $1"
    echo "[✗ 失败] $1" >> $TEST_LOG
}

log_warning() {
    echo -e "${YELLOW}[⚠ 警告]${NC} $1"
    echo "[⚠ 警告] $1" >> $TEST_LOG
}

log_info() {
    echo -e "${BLUE}[信息]${NC} $1"
    echo "[信息] $1" >> $TEST_LOG
}

# ========================================
# 1. 用户模块测试
# ========================================
test_user_module() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "1. 用户模块测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 1.1 用户注册
    log_test "1.1 测试用户注册"
    REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"$TEST_USER\",
            \"password\": \"$TEST_PASSWORD\",
            \"email\": \"${TEST_USER}@test.com\",
            \"nickname\": \"测试用户\"
        }")
    
    echo "响应: $REGISTER_RESPONSE" >> $TEST_LOG
    
    if echo "$REGISTER_RESPONSE" | grep -q '"code":200'; then
        log_success "用户注册成功"
        USER_ID=$(echo "$REGISTER_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        log_info "用户ID: $USER_ID"
    else
        log_error "用户注册失败"
        echo "$REGISTER_RESPONSE" | tee -a $TEST_LOG
    fi
    
    # 1.2 重复注册检测
    log_test "1.2 测试重复注册拦截"
    DUPLICATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"$TEST_USER\",
            \"password\": \"$TEST_PASSWORD\",
            \"email\": \"${TEST_USER}@test.com\"
        }")
    
    if echo "$DUPLICATE_RESPONSE" | grep -q '"code":500'; then
        log_success "重复注册被正确拦截"
    else
        log_error "重复注册未被拦截"
    fi
    
    # 1.3 用户登录
    log_test "1.3 测试用户登录"
    LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"$TEST_USER\",
            \"password\": \"$TEST_PASSWORD\"
        }")
    
    echo "登录响应: $LOGIN_RESPONSE" >> $TEST_LOG
    
    if echo "$LOGIN_RESPONSE" | grep -q '"code":200'; then
        log_success "用户登录成功"
        TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        log_info "Token: ${TOKEN:0:50}..."
    else
        log_error "用户登录失败"
        echo "$LOGIN_RESPONSE" | tee -a $TEST_LOG
    fi
    
    # 1.4 错误密码登录
    log_test "1.4 测试错误密码登录"
    WRONG_LOGIN=$(curl -s -X POST "$BASE_URL/api/auth/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"$TEST_USER\",
            \"password\": \"wrongpassword\"
        }")
    
    if echo "$WRONG_LOGIN" | grep -q '"code":500'; then
        log_success "错误密码被正确拦截"
    else
        log_error "错误密码未被拦截"
    fi
    
    # 1.5 未登录访问受限接口
    log_test "1.5 测试未登录访问受限接口"
    NO_TOKEN_RESPONSE=$(curl -s -X GET "$BASE_URL/api/posts/my")
    
    if echo "$NO_TOKEN_RESPONSE" | grep -q '"code":401'; then
        log_success "未登录访问被正确拦截"
    else
        log_error "未登录访问未被拦截"
    fi
}

# ========================================
# 2. 动态模块测试
# ========================================
test_post_module() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "2. 动态（Post）模块测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 2.1 创建动态
    log_test "2.1 测试创建动态（纯文本）"
    CREATE_POST_RESPONSE=$(curl -s -X POST "$BASE_URL/api/posts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{
            \"title\": \"测试动态标题\",
            \"content\": \"这是一条测试动态内容\",
            \"images\": \"[]\"
        }")
    
    echo "创建动态响应: $CREATE_POST_RESPONSE" >> $TEST_LOG
    
    if echo "$CREATE_POST_RESPONSE" | grep -q '"code":200'; then
        log_success "动态创建成功"
        POST_ID=$(echo "$CREATE_POST_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        log_info "动态ID: $POST_ID"
    else
        log_error "动态创建失败"
        echo "$CREATE_POST_RESPONSE" | tee -a $TEST_LOG
    fi
    
    # 2.2 获取动态列表
    log_test "2.2 测试获取动态列表"
    LIST_RESPONSE=$(curl -s -X GET "$BASE_URL/api/posts/list")
    
    if echo "$LIST_RESPONSE" | grep -q '"code":200'; then
        COUNT=$(echo "$LIST_RESPONSE" | grep -o '"id":' | wc -l)
        log_success "获取动态列表成功，共 $COUNT 条动态"
    else
        log_error "获取动态列表失败"
    fi
    
    # 2.3 获取动态详情
    log_test "2.3 测试获取动态详情"
    if [ ! -z "$POST_ID" ]; then
        DETAIL_RESPONSE=$(curl -s -X GET "$BASE_URL/api/posts/${POST_ID}/detail" \
            -H "Authorization: Bearer $TOKEN")
        
        if echo "$DETAIL_RESPONSE" | grep -q '"code":200'; then
            log_success "获取动态详情成功"
        else
            log_error "获取动态详情失败"
        fi
    fi
    
    # 2.4 获取我的动态
    log_test "2.4 测试获取我的动态"
    MY_POSTS=$(curl -s -X GET "$BASE_URL/api/posts/my" \
        -H "Authorization: Bearer $TOKEN")
    
    if echo "$MY_POSTS" | grep -q '"code":200'; then
        log_success "获取我的动态成功"
    else
        log_error "获取我的动态失败"
    fi
    
    # 2.5 删除动态
    log_test "2.5 测试删除动态"
    if [ ! -z "$POST_ID" ]; then
        DELETE_RESPONSE=$(curl -s -X DELETE "$BASE_URL/api/posts/${POST_ID}" \
            -H "Authorization: Bearer $TOKEN")
        
        if echo "$DELETE_RESPONSE" | grep -q '"code":200'; then
            log_success "动态删除成功"
        else
            log_error "动态删除失败"
        fi
    fi
}

# ========================================
# 3. 评论模块测试
# ========================================
test_comment_module() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "3. 评论模块测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 先创建一个动态用于测试评论
    log_test "3.0 准备测试环境：创建动态"
    CREATE_POST=$(curl -s -X POST "$BASE_URL/api/posts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{
            \"title\": \"评论测试动态\",
            \"content\": \"用于测试评论功能\",
            \"images\": \"[]\"
        }")
    
    POST_ID=$(echo "$CREATE_POST" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    log_info "测试动态ID: $POST_ID"
    
    # 3.1 创建评论
    log_test "3.1 测试创建评论"
    if [ ! -z "$POST_ID" ]; then
        CREATE_COMMENT=$(curl -s -X POST "$BASE_URL/api/comments" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "{
                \"postId\": $POST_ID,
                \"content\": \"这是一条测试评论\"
            }")
        
        echo "创建评论响应: $CREATE_COMMENT" >> $TEST_LOG
        
        if echo "$CREATE_COMMENT" | grep -q '"code":200'; then
            log_success "评论创建成功"
            COMMENT_ID=$(echo "$CREATE_COMMENT" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
            log_info "评论ID: $COMMENT_ID"
        else
            log_error "评论创建失败"
        fi
    fi
    
    # 3.2 获取动态的评论列表
    log_test "3.2 测试获取动态的评论列表"
    if [ ! -z "$POST_ID" ]; then
        COMMENTS_LIST=$(curl -s -X GET "$BASE_URL/api/comments/post/${POST_ID}")
        
        if echo "$COMMENTS_LIST" | grep -q '"code":200'; then
            log_success "获取评论列表成功"
        else
            log_error "获取评论列表失败"
        fi
    fi
    
    # 3.3 获取我的评论
    log_test "3.3 测试获取我的评论"
    MY_COMMENTS=$(curl -s -X GET "$BASE_URL/api/comments/my" \
        -H "Authorization: Bearer $TOKEN")
    
    if echo "$MY_COMMENTS" | grep -q '"code":200'; then
        log_success "获取我的评论成功"
    else
        log_error "获取我的评论失败"
    fi
    
    # 3.4 删除评论
    log_test "3.4 测试删除评论"
    if [ ! -z "$COMMENT_ID" ]; then
        DELETE_COMMENT=$(curl -s -X DELETE "$BASE_URL/api/comments/${COMMENT_ID}" \
            -H "Authorization: Bearer $TOKEN")
        
        if echo "$DELETE_COMMENT" | grep -q '"code":200'; then
            log_success "评论删除成功"
        else
            log_error "评论删除失败"
        fi
    fi
}

# ========================================
# 4. 点赞模块测试
# ========================================
test_like_module() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "4. 点赞模块测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 使用之前创建的动态
    if [ -z "$POST_ID" ]; then
        # 如果没有POST_ID，创建一个
        CREATE_POST=$(curl -s -X POST "$BASE_URL/api/posts" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "{
                \"title\": \"点赞测试动态\",
                \"content\": \"用于测试点赞功能\",
                \"images\": \"[]\"
            }")
        POST_ID=$(echo "$CREATE_POST" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    fi
    
    # 4.1 点赞动态
    log_test "4.1 测试点赞动态"
    if [ ! -z "$POST_ID" ]; then
        LIKE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/likes/${POST_ID}" \
            -H "Authorization: Bearer $TOKEN")
        
        echo "点赞响应: $LIKE_RESPONSE" >> $TEST_LOG
        
        if echo "$LIKE_RESPONSE" | grep -q '"code":200' && echo "$LIKE_RESPONSE" | grep -q '"liked":true'; then
            log_success "点赞成功"
        else
            log_error "点赞失败"
        fi
    fi
    
    # 4.2 检查点赞状态
    log_test "4.2 测试检查点赞状态"
    if [ ! -z "$POST_ID" ]; then
        CHECK_LIKE=$(curl -s -X GET "$BASE_URL/api/likes/${POST_ID}/check" \
            -H "Authorization: Bearer $TOKEN")
        
        if echo "$CHECK_LIKE" | grep -q '"code":200'; then
            log_success "检查点赞状态成功"
        else
            log_error "检查点赞状态失败"
        fi
    fi
    
    # 4.3 获取点赞数
    log_test "4.3 测试获取点赞数"
    if [ ! -z "$POST_ID" ]; then
        LIKE_COUNT=$(curl -s -X GET "$BASE_URL/api/likes/${POST_ID}/count")
        
        if echo "$LIKE_COUNT" | grep -q '"code":200'; then
            log_success "获取点赞数成功"
        else
            log_error "获取点赞数失败"
        fi
    fi
    
    # 4.4 取消点赞
    log_test "4.4 测试取消点赞"
    if [ ! -z "$POST_ID" ]; then
        UNLIKE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/likes/${POST_ID}" \
            -H "Authorization: Bearer $TOKEN")
        
        if echo "$UNLIKE_RESPONSE" | grep -q '"code":200' && echo "$UNLIKE_RESPONSE" | grep -q '"liked":false'; then
            log_success "取消点赞成功"
        else
            log_error "取消点赞失败"
        fi
    fi
}

# ========================================
# 5. 好友模块测试
# ========================================
test_friend_module() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "5. 好友模块测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 先创建第二个测试用户
    log_test "5.0 准备测试环境：创建第二个用户"
    TEST_USER2="testuser2_$(date +%s)"
    REGISTER2=$(curl -s -X POST "$BASE_URL/api/auth/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"$TEST_USER2\",
            \"password\": \"$TEST_PASSWORD\",
            \"email\": \"${TEST_USER2}@test.com\",
            \"nickname\": \"测试用户2\"
        }")
    
    USER2_ID=$(echo "$REGISTER2" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    log_info "第二个用户ID: $USER2_ID"
    
    # 5.1 搜索用户
    log_test "5.1 测试搜索用户"
    SEARCH_USERS=$(curl -s -X GET "$BASE_URL/api/friends/search?keyword=$TEST_USER2" \
        -H "Authorization: Bearer $TOKEN")
    
    if echo "$SEARCH_USERS" | grep -q '"code":200'; then
        log_success "搜索用户成功"
    else
        log_error "搜索用户失败"
    fi
    
    # 5.2 发送好友请求
    log_test "5.2 测试发送好友请求"
    if [ ! -z "$USER2_ID" ]; then
        SEND_REQUEST=$(curl -s -X POST "$BASE_URL/api/friends/request/${USER2_ID}" \
            -H "Authorization: Bearer $TOKEN")
        
        echo "好友请求响应: $SEND_REQUEST" >> $TEST_LOG
        
        if echo "$SEND_REQUEST" | grep -q '"code":200'; then
            log_success "发送好友请求成功"
            FRIENDSHIP_ID=$(echo "$SEND_REQUEST" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        else
            log_error "发送好友请求失败"
        fi
    fi
    
    # 5.3 获取好友列表
    log_test "5.3 测试获取好友列表"
    FRIENDS_LIST=$(curl -s -X GET "$BASE_URL/api/friends/list" \
        -H "Authorization: Bearer $TOKEN")
    
    if echo "$FRIENDS_LIST" | grep -q '"code":200'; then
        log_success "获取好友列表成功"
    else
        log_error "获取好友列表失败"
    fi
    
    # 5.4 检查好友关系状态
    log_test "5.4 测试检查好友关系状态"
    if [ ! -z "$USER2_ID" ]; then
        FRIEND_STATUS=$(curl -s -X GET "$BASE_URL/api/friends/status/${USER2_ID}" \
            -H "Authorization: Bearer $TOKEN")
        
        if echo "$FRIEND_STATUS" | grep -q '"code":200'; then
            log_success "检查好友关系状态成功"
        else
            log_error "检查好友关系状态失败"
        fi
    fi
}

# ========================================
# 6. 好友时间线测试
# ========================================
test_timeline() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "6. 好友时间线测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 6.1 获取时间线
    log_test "6.1 测试获取好友时间线"
    TIMELINE=$(curl -s -X GET "$BASE_URL/api/posts/timeline" \
        -H "Authorization: Bearer $TOKEN")
    
    echo "时间线响应: $TIMELINE" >> $TEST_LOG
    
    if echo "$TIMELINE" | grep -q '"code":200'; then
        log_success "获取好友时间线成功"
    else
        log_error "获取好友时间线失败"
    fi
}

# ========================================
# 7. 数据统计模块测试
# ========================================
test_statistics() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "7. 数据统计模块测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 7.1 获取统计数据
    log_test "7.1 测试获取统计数据"
    STATS=$(curl -s -X GET "$BASE_URL/api/stats" \
        -H "Authorization: Bearer $TOKEN")
    
    echo "统计数据响应: $STATS" >> $TEST_LOG
    
    if echo "$STATS" | grep -q '"code":200'; then
        log_success "获取统计数据成功"
        echo "$STATS" | tee -a $TEST_LOG
    else
        log_error "获取统计数据失败"
    fi
    
    # 7.2 触发数据分析
    log_test "7.2 测试触发数据分析（Spark/SQL）"
    ANALYZE=$(curl -s -X POST "$BASE_URL/api/stats/analyze" \
        -H "Authorization: Bearer $TOKEN")
    
    echo "数据分析响应: $ANALYZE" >> $TEST_LOG
    
    if echo "$ANALYZE" | grep -q '"code":200'; then
        log_success "数据分析执行成功"
    else
        log_warning "数据分析执行失败（可能是Spark配置问题）"
        echo "$ANALYZE" | tee -a $TEST_LOG
    fi
}

# ========================================
# 执行所有测试
# ========================================
main() {
    echo ""
    echo "========================================"
    echo "开始执行 Blog Circle 后端系统性测试"
    echo "========================================"
    echo ""
    
    test_user_module
    test_post_module
    test_comment_module
    test_like_module
    test_friend_module
    test_timeline
    test_statistics
    
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "测试完成！" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    echo "测试报告已保存到: $TEST_LOG"
    echo ""
}

# 运行测试
main

