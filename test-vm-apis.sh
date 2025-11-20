#!/bin/bash

# 虚拟机 API 测试脚本
# 测试通过前端 Nginx 代理访问后端 API

BASE_URL="http://10.211.55.11:8080"

echo "=========================================="
echo "开始测试虚拟机部署的 API"
echo "=========================================="

# 1. 测试注册 API
echo -e "\n=== 1. 测试注册 API ==="
REGISTER_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"testuser$(date +%s)\",\"password\":\"test123\",\"email\":\"test$(date +%s)@test.com\",\"nickname\":\"测试用户\"}")
echo "$REGISTER_RESPONSE"

# 2. 测试登录 API
echo -e "\n=== 2. 测试登录 API ==="
LOGIN_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"apitest","password":"test123"}')
echo "$LOGIN_RESPONSE"

# 提取 token (使用 grep 和 sed)
TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"\(.*\)"/\1/')
echo "Token: $TOKEN"

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo "错误: 无法获取 token，测试终止"
    exit 1
fi

# 3. 测试获取用户信息
echo -e "\n=== 3. 测试获取用户信息 ==="
curl -s -X GET ${BASE_URL}/api/users/current \
  -H "Authorization: Bearer $TOKEN"
echo ""

# 4. 测试创建帖子
echo -e "\n=== 4. 测试创建帖子 ==="
POST_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/posts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"测试帖子 $(date +%Y%m%d%H%M%S)\",\"content\":\"这是通过前端代理创建的测试帖子，时间：$(date)\"}")
echo "$POST_RESPONSE"

# 提取帖子 ID
POST_ID=$(echo "$POST_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
echo "帖子 ID: $POST_ID"

# 5. 测试获取帖子列表
echo -e "\n=== 5. 测试获取帖子列表 ==="
curl -s -X GET ${BASE_URL}/api/posts/list
echo ""

# 6. 测试获取单个帖子详情
if [ -n "$POST_ID" ] && [ "$POST_ID" != "null" ]; then
    echo -e "\n=== 6. 测试获取帖子详情 ==="
    curl -s -X GET ${BASE_URL}/api/posts/${POST_ID}/detail
    echo ""
    
    # 7. 测试点赞帖子
    echo -e "\n=== 7. 测试点赞帖子 ==="
    curl -s -X POST ${BASE_URL}/api/likes/${POST_ID} \
      -H "Authorization: Bearer $TOKEN"
    echo ""
    
    # 8. 测试评论帖子
    echo -e "\n=== 8. 测试评论帖子 ==="
    curl -s -X POST ${BASE_URL}/api/comments \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"postId\":${POST_ID},\"content\":\"这是一条测试评论，时间：$(date)\"}"
    echo ""
    
    # 9. 测试获取帖子评论
    echo -e "\n=== 9. 测试获取帖子评论 ==="
    curl -s -X GET ${BASE_URL}/api/comments/post/${POST_ID}
    echo ""
fi

# 10. 测试健康检查
echo -e "\n=== 10. 测试健康检查 ==="
curl -s -X GET ${BASE_URL}/actuator/health
echo ""

echo -e "\n=========================================="
echo "API 测试完成"
echo "=========================================="
