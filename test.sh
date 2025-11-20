#!/bin/bash

# ==============================================================================
# CloudCom Blog Circle - Unified Test Script
# ==============================================================================

###############################################################
# Blog Circle 本地测试脚本
# 测试 Docker Compose 部署的服务
###############################################################

set -e

BASE_URL="http://localhost:8080"

echo "=========================================="
echo "Blog Circle 本地测试套件"
echo "=========================================="
echo ""

# 检查服务是否运行
echo "检查服务状态..."
if ! docker-compose ps | grep -q "Up"; then
    echo "错误: 服务未运行，请先执行: docker-compose up -d"
    exit 1
fi
echo "✓ 服务正在运行"
echo ""

# 1. 健康检查
echo "=== 1. 健康检查 ==="
HEALTH=$(curl -s ${BASE_URL}/actuator/health || echo '{"status":"DOWN"}')
echo "$HEALTH"
if echo "$HEALTH" | grep -q '"status":"UP"'; then
    echo "✓ 健康检查通过"
else
    echo "✗ 健康检查失败"
    exit 1
fi
echo ""

# 2. 测试注册
echo "=== 2. 测试用户注册 ==="
REGISTER_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"testuser$(date +%s)\",\"password\":\"test123\",\"email\":\"test$(date +%s)@test.com\",\"nickname\":\"测试用户\"}")
echo "$REGISTER_RESPONSE"
if echo "$REGISTER_RESPONSE" | grep -q '"code":200'; then
    echo "✓ 注册测试通过"
else
    echo "✗ 注册测试失败"
fi
echo ""

# 3. 测试登录
echo "=== 3. 测试用户登录 ==="
LOGIN_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"apitest","password":"test123"}')
echo "$LOGIN_RESPONSE"

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"//' | sed 's/"//')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    echo "✗ 登录失败，无法获取 token"
    echo "提示: 请确保数据库中存在用户 apitest，密码 test123"
    echo "或运行: docker-compose exec backend bash -c 'curl -X POST http://localhost:8080/api/auth/register -H \"Content-Type: application/json\" -d \"{\\\"username\\\":\\\"apitest\\\",\\\"password\\\":\\\"test123\\\",\\\"email\\\":\\\"apitest@test.com\\\"}\"'"
    exit 1
fi
echo "✓ 登录成功，Token: ${TOKEN:0:20}..."
echo ""

# 4. 测试获取用户信息
echo "=== 4. 测试获取用户信息 ==="
USER_RESPONSE=$(curl -s -X GET ${BASE_URL}/api/users/current \
  -H "Authorization: Bearer $TOKEN")
echo "$USER_RESPONSE"
if echo "$USER_RESPONSE" | grep -q '"code":200'; then
    echo "✓ 获取用户信息成功"
else
    echo "✗ 获取用户信息失败"
fi
echo ""

# 5. 测试创建帖子
echo "=== 5. 测试创建帖子 ==="
POST_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/posts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"测试帖子 $(date +%Y%m%d%H%M%S)\",\"content\":\"这是本地测试创建的帖子\"}")
echo "$POST_RESPONSE"

POST_ID=$(echo "$POST_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')

if [ -n "$POST_ID" ] && [ "$POST_ID" != "null" ]; then
    echo "✓ 创建帖子成功，ID: $POST_ID"
else
    echo "✗ 创建帖子失败"
fi
echo ""

# 6. 测试获取帖子列表
echo "=== 6. 测试获取帖子列表 ==="
POST_LIST=$(curl -s -X GET ${BASE_URL}/api/posts/list)
if echo "$POST_LIST" | grep -q '"code":200'; then
    POST_COUNT=$(echo "$POST_LIST" | grep -o '"id":[0-9]*' | wc -l)
    echo "✓ 获取帖子列表成功，共 $POST_COUNT 篇帖子"
else
    echo "✗ 获取帖子列表失败"
fi
echo ""

# 7. 测试点赞（如果有帖子ID）
if [ -n "$POST_ID" ] && [ "$POST_ID" != "null" ]; then
    echo "=== 7. 测试点赞功能 ==="
    LIKE_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/likes/${POST_ID} \
      -H "Authorization: Bearer $TOKEN")
    echo "$LIKE_RESPONSE"
    if echo "$LIKE_RESPONSE" | grep -q '"code":200'; then
        echo "✓ 点赞测试通过"
    else
        echo "✗ 点赞测试失败"
    fi
    echo ""
    
    # 8. 测试评论
    echo "=== 8. 测试评论功能 ==="
    COMMENT_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/comments \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"postId\":${POST_ID},\"content\":\"这是一条测试评论\"}")
    echo "$COMMENT_RESPONSE"
    if echo "$COMMENT_RESPONSE" | grep -q '"code":200'; then
        echo "✓ 评论测试通过"
    else
        echo "✗ 评论测试失败"
    fi
    echo ""
fi

echo "=========================================="
echo "测试完成！"
echo "=========================================="
echo ""
echo "查看详细日志:"
echo "  docker-compose logs -f backend"
echo "  docker-compose logs -f frontend"
echo ""
