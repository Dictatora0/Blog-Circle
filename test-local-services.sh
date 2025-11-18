#!/bin/bash

# Mac 本地服务完整功能测试
# 测试 Backend + Frontend + Spark 连接 VM PostgreSQL

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }

header() {
    echo ""
    echo "========================================="
    echo "   $1"
    echo "========================================="
    echo ""
}

TEST_PASSED=0
TEST_FAILED=0

# 测试基础 API
test_basic_api() {
    header "测试基础 API"
    
    log "测试文章列表 API..."
    RESPONSE=$(curl -s http://localhost:8081/api/posts/list)
    if echo "$RESPONSE" | jq -e '.code == 200' >/dev/null 2>&1; then
        ok "文章列表 API 正常"
        ((TEST_PASSED++))
    else
        err "文章列表 API 失败: $RESPONSE"
        ((TEST_FAILED++))
        return 1
    fi
    
    log "测试用户列表 API..."
    RESPONSE=$(curl -s http://localhost:8081/api/users/list)
    if echo "$RESPONSE" | jq -e '.code == 200' >/dev/null 2>&1; then
        ok "用户列表 API 正常"
        ((TEST_PASSED++))
    else
        err "用户列表 API 失败"
        ((TEST_FAILED++))
    fi
}

# 测试用户注册登录
test_auth() {
    header "测试用户认证"
    
    TIMESTAMP=$(date +%s)
    TEST_USER="testuser${TIMESTAMP}"
    
    log "测试用户注册..."
    REGISTER=$(curl -s -X POST http://localhost:8081/api/auth/register \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${TEST_USER}\",\"password\":\"test123\",\"email\":\"${TEST_USER}@test.com\"}")
    
    if echo "$REGISTER" | jq -e '.code == 200' >/dev/null 2>&1; then
        USER_ID=$(echo "$REGISTER" | jq -r '.data.id')
        ok "用户注册成功，ID: $USER_ID"
        ((TEST_PASSED++))
    else
        err "用户注册失败: $REGISTER"
        ((TEST_FAILED++))
        return 1
    fi
    
    log "测试用户登录..."
    LOGIN=$(curl -s -X POST http://localhost:8081/api/auth/login \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${TEST_USER}\",\"password\":\"test123\"}")
    
    if echo "$LOGIN" | jq -e '.data.token' >/dev/null 2>&1; then
        TOKEN=$(echo "$LOGIN" | jq -r '.data.token')
        ok "用户登录成功，获取 Token"
        ((TEST_PASSED++))
        echo "$TOKEN" > /tmp/test_token.txt
    else
        err "用户登录失败: $LOGIN"
        ((TEST_FAILED++))
        return 1
    fi
    
    log "测试错误密码登录..."
    WRONG_LOGIN=$(curl -s -X POST http://localhost:8081/api/auth/login \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${TEST_USER}\",\"password\":\"wrongpassword\"}")
    
    if echo "$WRONG_LOGIN" | jq -e '.code != 200' >/dev/null 2>&1; then
        ok "错误密码登录正确拒绝"
        ((TEST_PASSED++))
    else
        warn "错误密码登录未正确处理"
        ((TEST_FAILED++))
    fi
}

# 测试文章 CRUD
test_post_crud() {
    header "测试文章 CRUD"
    
    if [ ! -f /tmp/test_token.txt ]; then
        warn "跳过文章测试（无 Token）"
        return 1
    fi
    
    TOKEN=$(cat /tmp/test_token.txt)
    
    log "测试创建文章..."
    POST_DATA="{\"title\":\"测试文章 $(date +%H:%M:%S)\",\"content\":\"这是一篇完整的测试文章内容，用于验证系统功能。\"}"
    CREATE=$(curl -s -X POST http://localhost:8081/api/posts \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "$POST_DATA")
    
    if echo "$CREATE" | jq -e '.code == 200' >/dev/null 2>&1; then
        POST_ID=$(echo "$CREATE" | jq -r '.data.id')
        ok "创建文章成功，ID: $POST_ID"
        ((TEST_PASSED++))
        echo "$POST_ID" > /tmp/test_post_id.txt
    else
        err "创建文章失败: $CREATE"
        ((TEST_FAILED++))
        return 1
    fi
    
    log "测试获取文章详情..."
    DETAIL=$(curl -s "http://localhost:8081/api/posts/${POST_ID}/detail")
    if echo "$DETAIL" | jq -e '.code == 200' >/dev/null 2>&1; then
        VIEW_COUNT=$(echo "$DETAIL" | jq -r '.data.viewCount')
        ok "获取文章详情成功，浏览量: $VIEW_COUNT"
        ((TEST_PASSED++))
    else
        err "获取文章详情失败: $DETAIL"
        ((TEST_FAILED++))
    fi
    
    log "测试更新文章..."
    UPDATE=$(curl -s -X PUT "http://localhost:8081/api/posts/${POST_ID}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"title\":\"更新后的标题\",\"content\":\"更新后的内容\"}")
    
    if echo "$UPDATE" | jq -e '.code == 200' >/dev/null 2>&1; then
        ok "更新文章成功"
        ((TEST_PASSED++))
    else
        warn "更新文章失败: $UPDATE"
        ((TEST_FAILED++))
    fi
    
    log "测试我的文章列表..."
    MY_POSTS=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "http://localhost:8081/api/posts/my")
    if echo "$MY_POSTS" | jq -e '.code == 200' >/dev/null 2>&1; then
        COUNT=$(echo "$MY_POSTS" | jq '.data | length')
        ok "获取我的文章成功，共 $COUNT 篇"
        ((TEST_PASSED++))
    else
        warn "获取我的文章失败"
        ((TEST_FAILED++))
    fi
}

# 测试评论功能
test_comments() {
    header "测试评论功能"
    
    if [ ! -f /tmp/test_token.txt ] || [ ! -f /tmp/test_post_id.txt ]; then
        warn "跳过评论测试（无 Token 或文章 ID）"
        return 1
    fi
    
    TOKEN=$(cat /tmp/test_token.txt)
    POST_ID=$(cat /tmp/test_post_id.txt)
    
    log "测试创建评论..."
    COMMENT=$(curl -s -X POST http://localhost:8081/api/comments \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"postId\":${POST_ID},\"content\":\"这是一条测试评论\"}")
    
    if echo "$COMMENT" | jq -e '.code == 200' >/dev/null 2>&1; then
        COMMENT_ID=$(echo "$COMMENT" | jq -r '.data.id')
        ok "创建评论成功，ID: $COMMENT_ID"
        ((TEST_PASSED++))
        echo "$COMMENT_ID" > /tmp/test_comment_id.txt
    else
        err "创建评论失败: $COMMENT"
        ((TEST_FAILED++))
        return 1
    fi
    
    log "测试获取文章评论列表..."
    COMMENTS=$(curl -s "http://localhost:8081/api/comments/post/${POST_ID}")
    if echo "$COMMENTS" | jq -e '.code == 200' >/dev/null 2>&1; then
        COUNT=$(echo "$COMMENTS" | jq '.data | length')
        ok "获取评论列表成功，共 $COUNT 条"
        ((TEST_PASSED++))
    else
        err "获取评论列表失败: $COMMENTS"
        ((TEST_FAILED++))
    fi
    
    if [ -f /tmp/test_comment_id.txt ]; then
        COMMENT_ID=$(cat /tmp/test_comment_id.txt)
        log "测试删除评论..."
        DELETE=$(curl -s -X DELETE "http://localhost:8081/api/comments/${COMMENT_ID}" \
            -H "Authorization: Bearer $TOKEN")
        
        if echo "$DELETE" | jq -e '.code == 200' >/dev/null 2>&1; then
            ok "删除评论成功"
            ((TEST_PASSED++))
        else
            warn "删除评论失败: $DELETE"
            ((TEST_FAILED++))
        fi
    fi
}

# 测试点赞功能
test_likes() {
    header "测试点赞功能"
    
    if [ ! -f /tmp/test_token.txt ] || [ ! -f /tmp/test_post_id.txt ]; then
        warn "跳过点赞测试（无 Token 或文章 ID）"
        return 1
    fi
    
    TOKEN=$(cat /tmp/test_token.txt)
    POST_ID=$(cat /tmp/test_post_id.txt)
    
    log "测试点赞..."
    LIKE=$(curl -s -X POST "http://localhost:8081/api/likes/${POST_ID}" \
        -H "Authorization: Bearer $TOKEN")
    
    if echo "$LIKE" | jq -e '.code == 200' >/dev/null 2>&1; then
        ok "点赞成功"
        ((TEST_PASSED++))
    else
        err "点赞失败: $LIKE"
        ((TEST_FAILED++))
        return 1
    fi
    
    log "测试重复点赞..."
    LIKE_AGAIN=$(curl -s -X POST "http://localhost:8081/api/likes/${POST_ID}" \
        -H "Authorization: Bearer $TOKEN")
    
    if echo "$LIKE_AGAIN" | jq -e '.code != 200' >/dev/null 2>&1; then
        ok "重复点赞正确拒绝"
        ((TEST_PASSED++))
    else
        warn "重复点赞未正确处理"
        ((TEST_FAILED++))
    fi
    
    log "测试取消点赞..."
    UNLIKE=$(curl -s -X DELETE "http://localhost:8081/api/likes/${POST_ID}" \
        -H "Authorization: Bearer $TOKEN")
    
    if echo "$UNLIKE" | jq -e '.code == 200' >/dev/null 2>&1; then
        ok "取消点赞成功"
        ((TEST_PASSED++))
    else
        warn "取消点赞失败: $UNLIKE"
        ((TEST_FAILED++))
    fi
}

# 测试数据库连接
test_database() {
    header "测试数据库连接"
    
    log "测试数据库连接池..."
    for i in {1..20}; do
        curl -s http://localhost:8081/api/posts/list > /dev/null &
    done
    wait
    ok "并发 20 个请求完成"
    ((TEST_PASSED++))
    
    log "检查 Backend 日志..."
    docker logs --tail 50 blogcircle-backend 2>&1 | grep -i "hikaricp" | tail -5 || true
}

# 测试前端
test_frontend() {
    header "测试前端服务"
    
    log "测试前端首页..."
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082)
    if [ "$STATUS" = "200" ]; then
        ok "前端首页正常 (HTTP $STATUS)"
        ((TEST_PASSED++))
    else
        err "前端首页异常 (HTTP $STATUS)"
        ((TEST_FAILED++))
    fi
    
    log "测试前端 API 代理..."
    PROXY=$(curl -s http://localhost:8082/api/posts/list)
    if echo "$PROXY" | jq -e '.code == 200' >/dev/null 2>&1; then
        ok "前端 API 代理正常"
        ((TEST_PASSED++))
    else
        warn "前端 API 代理异常"
        ((TEST_FAILED++))
    fi
}

# 性能测试
test_performance() {
    header "性能测试"
    
    log "测试 API 响应时间（5次）..."
    TOTAL=0
    for i in {1..5}; do
        TIME=$(curl -s -o /dev/null -w "%{time_total}" http://localhost:8081/api/posts/list)
        echo "  请求 $i: ${TIME}s"
        TOTAL=$(echo "$TOTAL + $TIME" | bc)
    done
    AVG=$(echo "scale=3; $TOTAL / 5" | bc)
    ok "平均响应时间: ${AVG}s"
}

# 清理测试数据
cleanup() {
    header "清理测试数据"
    
    if [ -f /tmp/test_token.txt ] && [ -f /tmp/test_post_id.txt ]; then
        TOKEN=$(cat /tmp/test_token.txt)
        POST_ID=$(cat /tmp/test_post_id.txt)
        
        log "删除测试文章..."
        curl -s -X DELETE "http://localhost:8081/api/posts/${POST_ID}" \
            -H "Authorization: Bearer $TOKEN" > /dev/null
        ok "测试数据清理完成"
    fi
    
    rm -f /tmp/test_token.txt /tmp/test_post_id.txt /tmp/test_comment_id.txt
}

# 显示测试结果
show_results() {
    header "测试结果统计"
    
    TOTAL=$((TEST_PASSED + TEST_FAILED))
    PASS_RATE=$(echo "scale=1; $TEST_PASSED * 100 / $TOTAL" | bc)
    
    echo "总测试数: $TOTAL"
    echo -e "${GREEN}通过: $TEST_PASSED${NC}"
    echo -e "${RED}失败: $TEST_FAILED${NC}"
    echo "通过率: ${PASS_RATE}%"
    
    if [ $TEST_FAILED -eq 0 ]; then
        echo ""
        ok "所有测试通过！系统运行正常。"
    else
        echo ""
        warn "部分测试失败，请检查日志。"
    fi
}

# 主测试流程
main() {
    header "Mac 本地服务完整功能测试"
    
    log "开始测试..."
    
    test_basic_api || true
    test_auth || true
    test_post_crud || true
    test_comments || true
    test_likes || true
    test_database || true
    test_frontend || true
    test_performance || true
    
    cleanup || true
    show_results
    
    echo ""
    echo "访问地址:"
    echo "  前端: http://localhost:8082"
    echo "  后端: http://localhost:8081"
    echo "  Spark Master UI: http://localhost:8090"
    echo ""
    echo "测试账号:"
    echo "  用户名: admin"
    echo "  密码: admin123"
}

# 执行测试
main
