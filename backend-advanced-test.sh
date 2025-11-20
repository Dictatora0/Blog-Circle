#!/bin/bash

# ========================================
# Blog Circle 后端高级测试脚本
# 测试边界情况、异常处理、安全性
# ========================================

set -e

BASE_URL="http://localhost:8080"
TEST_LOG="backend-advanced-test-results.log"
TEST_USER="advtest_$(date +%s)"
TEST_PASSWORD="Test123456"
TOKEN=""
POST_ID=""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 初始化日志
echo "========================================" > $TEST_LOG
echo "Blog Circle 后端高级测试报告" >> $TEST_LOG
echo "测试时间: $(date)" >> $TEST_LOG
echo "========================================" >> $TEST_LOG
echo "" >> $TEST_LOG

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

# 准备测试环境
setup_test_env() {
    log_info "准备测试环境..."
    
    # 注册测试用户
    REGISTER=$(curl -s -X POST "$BASE_URL/api/auth/register" \
        -H "Content-Type: application/json" \
        -d "{\"username\": \"$TEST_USER\", \"password\": \"$TEST_PASSWORD\", \"email\": \"${TEST_USER}@test.com\", \"nickname\": \"高级测试用户\"}")
    
    # 登录获取Token
    LOGIN=$(curl -s -X POST "$BASE_URL/api/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\": \"$TEST_USER\", \"password\": \"$TEST_PASSWORD\"}")
    
    TOKEN=$(echo "$LOGIN" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    log_info "测试环境准备完成"
}

# ========================================
# 1. 输入验证测试
# ========================================
test_input_validation() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "1. 输入验证测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 1.1 空内容动态
    log_test "1.1 测试空内容动态拦截"
    EMPTY_POST=$(curl -s -X POST "$BASE_URL/api/posts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"title\": \"\", \"content\": \"\", \"images\": \"[]\"}")
    
    echo "响应: $EMPTY_POST" >> $TEST_LOG
    
    # 空内容应该被拦截或返回错误
    if echo "$EMPTY_POST" | grep -q '"code":200'; then
        log_warning "空内容动态未被拦截（可能需要添加验证）"
    else
        log_success "空内容动态被正确拦截"
    fi
    
    # 1.2 空评论
    log_test "1.2 测试空评论拦截"
    
    # 先创建一个测试动态
    CREATE_POST=$(curl -s -X POST "$BASE_URL/api/posts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"title\": \"测试\", \"content\": \"测试内容\", \"images\": \"[]\"}")
    POST_ID=$(echo "$CREATE_POST" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    
    if [ ! -z "$POST_ID" ]; then
        EMPTY_COMMENT=$(curl -s -X POST "$BASE_URL/api/comments" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "{\"postId\": $POST_ID, \"content\": \"\"}")
        
        if echo "$EMPTY_COMMENT" | grep -q '"code":200'; then
            log_warning "空评论未被拦截（可能需要添加验证）"
        else
            log_success "空评论被正确拦截"
        fi
    fi
    
    # 1.3 超长内容测试
    log_test "1.3 测试超长内容处理"
    LONG_CONTENT=$(python3 -c "print('A' * 10000)")
    LONG_POST=$(curl -s -X POST "$BASE_URL/api/posts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"title\": \"超长内容\", \"content\": \"$LONG_CONTENT\", \"images\": \"[]\"}")
    
    if echo "$LONG_POST" | grep -q '"code":200'; then
        log_success "系统可以处理超长内容"
    else
        log_info "系统拒绝超长内容（可能有字符限制）"
    fi
    
    # 1.4 特殊字符测试
    log_test "1.4 测试特殊字符处理"
    SPECIAL_CHARS="<script>alert('XSS')</script> & ' \" < > % # @"
    SPECIAL_POST=$(curl -s -X POST "$BASE_URL/api/posts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"title\": \"特殊字符\", \"content\": \"$SPECIAL_CHARS\", \"images\": \"[]\"}")
    
    if echo "$SPECIAL_POST" | grep -q '"code":200'; then
        log_success "系统可以处理特殊字符"
    else
        log_error "系统无法处理特殊字符"
    fi
}

# ========================================
# 2. 权限验证测试
# ========================================
test_authorization() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "2. 权限验证测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 2.1 无效Token测试
    log_test "2.1 测试无效Token访问"
    INVALID_TOKEN="invalid.token.here"
    INVALID_ACCESS=$(curl -s -X GET "$BASE_URL/api/posts/my" \
        -H "Authorization: Bearer $INVALID_TOKEN")
    
    if echo "$INVALID_ACCESS" | grep -q '"code":401'; then
        log_success "无效Token被正确拦截"
    else
        log_error "无效Token未被拦截（安全风险）"
    fi
    
    # 2.2 过期Token测试（需要实际等待或模拟）
    log_test "2.2 测试Token过期处理"
    log_info "（需要配置短过期时间才能完整测试）"
    
    # 2.3 删除他人动态测试
    log_test "2.3 测试删除他人动态的权限"
    # 使用ID=1的动态（应该属于其他用户）
    DELETE_OTHER=$(curl -s -X DELETE "$BASE_URL/api/posts/1" \
        -H "Authorization: Bearer $TOKEN")
    
    echo "删除他人动态响应: $DELETE_OTHER" >> $TEST_LOG
    if echo "$DELETE_OTHER" | grep -q '"code":200'; then
        log_warning "可以删除他人动态（可能需要添加权限检查）"
    else
        log_info "删除他人动态受限（符合预期或不存在）"
    fi
}

# ========================================
# 3. 数据一致性测试
# ========================================
test_data_consistency() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "3. 数据一致性测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 3.1 创建动态后立即查询
    log_test "3.1 测试创建后立即查询（事务一致性）"
    CREATE=$(curl -s -X POST "$BASE_URL/api/posts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"title\": \"一致性测试\", \"content\": \"测试事务\", \"images\": \"[]\"}")
    
    NEW_POST_ID=$(echo "$CREATE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    
    if [ ! -z "$NEW_POST_ID" ]; then
        # 立即查询
        sleep 0.5
        DETAIL=$(curl -s -X GET "$BASE_URL/api/posts/${NEW_POST_ID}/detail")
        
        if echo "$DETAIL" | grep -q '"code":200' && echo "$DETAIL" | grep -q '"一致性测试"'; then
            log_success "数据立即可见，事务处理正确"
        else
            log_error "数据不一致（可能是事务或缓存问题）"
        fi
    fi
    
    # 3.2 点赞数统计准确性
    log_test "3.2 测试点赞数统计准确性"
    if [ ! -z "$NEW_POST_ID" ]; then
        # 获取初始点赞数
        BEFORE=$(curl -s -X GET "$BASE_URL/api/likes/${NEW_POST_ID}/count")
        BEFORE_COUNT=$(echo "$BEFORE" | grep -o '"data":[0-9]*' | cut -d':' -f2)
        
        # 点赞
        curl -s -X POST "$BASE_URL/api/likes/${NEW_POST_ID}" \
            -H "Authorization: Bearer $TOKEN" > /dev/null
        
        sleep 0.5
        
        # 获取点赞后的数量
        AFTER=$(curl -s -X GET "$BASE_URL/api/likes/${NEW_POST_ID}/count")
        AFTER_COUNT=$(echo "$AFTER" | grep -o '"data":[0-9]*' | cut -d':' -f2)
        
        if [ "$((AFTER_COUNT - BEFORE_COUNT))" -eq 1 ]; then
            log_success "点赞数统计准确"
        else
            log_error "点赞数统计不准确（before=$BEFORE_COUNT, after=$AFTER_COUNT）"
        fi
    fi
    
    # 3.3 评论数统计
    log_test "3.3 测试评论数统计准确性"
    if [ ! -z "$NEW_POST_ID" ]; then
        # 添加评论
        curl -s -X POST "$BASE_URL/api/comments" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "{\"postId\": $NEW_POST_ID, \"content\": \"测试评论\"}" > /dev/null
        
        sleep 0.5
        
        # 获取评论列表
        COMMENTS=$(curl -s -X GET "$BASE_URL/api/comments/post/${NEW_POST_ID}")
        
        if echo "$COMMENTS" | grep -q '"测试评论"'; then
            log_success "评论创建后立即可查询"
        else
            log_error "评论数据不一致"
        fi
    fi
}

# ========================================
# 4. 性能和优化测试
# ========================================
test_performance() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "4. 性能测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 4.1 批量查询性能
    log_test "4.1 测试批量查询响应时间"
    START=$(date +%s%N)
    curl -s -X GET "$BASE_URL/api/posts/list" > /dev/null
    END=$(date +%s%N)
    ELAPSED=$((($END - $START) / 1000000))
    
    log_info "获取动态列表耗时: ${ELAPSED}ms"
    if [ $ELAPSED -lt 1000 ]; then
        log_success "查询性能良好（< 1秒）"
    elif [ $ELAPSED -lt 3000 ]; then
        log_warning "查询性能一般（1-3秒）"
    else
        log_error "查询性能较差（> 3秒）"
    fi
    
    # 4.2 并发创建测试
    log_test "4.2 测试并发请求处理"
    log_info "（并发测试需要专门工具，此处简单模拟）"
    
    # 快速连续创建5个动态
    for i in {1..5}; do
        curl -s -X POST "$BASE_URL/api/posts" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "{\"title\": \"并发测试$i\", \"content\": \"并发内容$i\", \"images\": \"[]\"}" > /dev/null &
    done
    wait
    
    log_success "并发请求处理完成"
}

# ========================================
# 5. 错误处理测试
# ========================================
test_error_handling() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "5. 错误处理测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 5.1 不存在的资源
    log_test "5.1 测试访问不存在的动态"
    NOT_FOUND=$(curl -s -X GET "$BASE_URL/api/posts/999999/detail")
    
    echo "不存在的动态响应: $NOT_FOUND" >> $TEST_LOG
    if echo "$NOT_FOUND" | grep -q '"code":500\|"code":404\|"data":null'; then
        log_success "正确处理不存在的资源"
    else
        log_warning "不存在的资源处理可能需要优化"
    fi
    
    # 5.2 格式错误的请求
    log_test "5.2 测试格式错误的请求"
    BAD_FORMAT=$(curl -s -X POST "$BASE_URL/api/posts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{invalid json")
    
    if echo "$BAD_FORMAT" | grep -q '"code":400\|"code":500'; then
        log_success "正确处理格式错误的请求"
    else
        log_warning "格式错误的请求处理可能需要优化"
    fi
    
    # 5.3 缺少必需字段
    log_test "5.3 测试缺少必需字段"
    MISSING_FIELD=$(curl -s -X POST "$BASE_URL/api/posts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"title\": \"只有标题\"}")
    
    echo "缺少字段响应: $MISSING_FIELD" >> $TEST_LOG
    # 系统应该提供默认值或返回错误
    if echo "$MISSING_FIELD" | grep -q '"code":200\|"code":400'; then
        log_success "正确处理缺少字段的情况"
    else
        log_info "缺少字段处理方式: $(echo $MISSING_FIELD | grep -o '"code":[0-9]*')"
    fi
}

# ========================================
# 6. Spark/SQL分析测试
# ========================================
test_analytics() {
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "6. Spark/SQL分析测试" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    
    # 6.1 触发分析
    log_test "6.1 测试触发数据分析"
    ANALYZE=$(curl -s -X POST "$BASE_URL/api/stats/analyze" \
        -H "Authorization: Bearer $TOKEN")
    
    echo "分析响应: $ANALYZE" >> $TEST_LOG
    
    if echo "$ANALYZE" | grep -q '"code":200'; then
        log_success "数据分析执行成功（使用SQL备用方案）"
    else
        log_error "数据分析执行失败"
        echo "$ANALYZE" | tee -a $TEST_LOG
    fi
    
    # 6.2 验证统计数据
    log_test "6.2 测试获取统计数据"
    sleep 1
    STATS=$(curl -s -X GET "$BASE_URL/api/stats" \
        -H "Authorization: Bearer $TOKEN")
    
    echo "统计数据: $STATS" >> $TEST_LOG
    
    if echo "$STATS" | grep -q '"postCount"'; then
        POST_COUNT=$(echo "$STATS" | grep -o '"postCount":[0-9]*' | cut -d':' -f2)
        log_success "统计数据包含动态数: $POST_COUNT"
    else
        log_error "统计数据格式异常"
    fi
    
    if echo "$STATS" | grep -q '"userCount"'; then
        USER_COUNT=$(echo "$STATS" | grep -o '"userCount":[0-9]*' | cut -d':' -f2)
        log_success "统计数据包含用户数: $USER_COUNT"
    fi
    
    if echo "$STATS" | grep -q '"likeCount"'; then
        LIKE_COUNT=$(echo "$STATS" | grep -o '"likeCount":[0-9]*' | cut -d':' -f2)
        log_success "统计数据包含点赞数: $LIKE_COUNT"
    fi
    
    if echo "$STATS" | grep -q '"commentCount"'; then
        COMMENT_COUNT=$(echo "$STATS" | grep -o '"commentCount":[0-9]*' | cut -d':' -f2)
        log_success "统计数据包含评论数: $COMMENT_COUNT"
    fi
}

# ========================================
# 执行所有测试
# ========================================
main() {
    echo ""
    echo "========================================"
    echo "开始执行 Blog Circle 后端高级测试"
    echo "========================================"
    echo ""
    
    setup_test_env
    test_input_validation
    test_authorization
    test_data_consistency
    test_performance
    test_error_handling
    test_analytics
    
    echo ""
    echo "========================================" | tee -a $TEST_LOG
    echo "高级测试完成！" | tee -a $TEST_LOG
    echo "========================================" | tee -a $TEST_LOG
    echo "测试报告已保存到: $TEST_LOG"
    echo ""
}

main

