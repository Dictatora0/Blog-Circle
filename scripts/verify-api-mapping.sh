#!/bin/bash

###############################################################
# 前后端 API 映射验证脚本
# 自动验证前端 API 调用与后端接口的对应关系
###############################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   前后端 API 映射验证"
echo "========================================="
echo ""

# 前端 API 文件列表
FRONTEND_API_FILES=(
    "frontend/src/api/auth.js"
    "frontend/src/api/post.js"
    "frontend/src/api/comment.js"
    "frontend/src/api/friends.js"
    "frontend/src/api/upload.js"
    "frontend/src/api/statistics.js"
)

# 后端 Controller 文件列表
BACKEND_CONTROLLER_FILES=(
    "backend/src/main/java/com/cloudcom/blog/controller/AuthController.java"
    "backend/src/main/java/com/cloudcom/blog/controller/PostController.java"
    "backend/src/main/java/com/cloudcom/blog/controller/CommentController.java"
    "backend/src/main/java/com/cloudcom/blog/controller/FriendshipController.java"
    "backend/src/main/java/com/cloudcom/blog/controller/LikeController.java"
    "backend/src/main/java/com/cloudcom/blog/controller/UserController.java"
    "backend/src/main/java/com/cloudcom/blog/controller/UploadController.java"
    "backend/src/main/java/com/cloudcom/blog/controller/StatisticsController.java"
)

TOTAL_APIS=0
MATCHED_APIS=0
UNMATCHED_APIS=0

# 定义前端 API 到后端映射
declare -A API_MAPPINGS=(
    # Auth APIs
    ["/auth/login"]="@PostMapping.*\"/login\""
    ["/auth/register"]="@PostMapping.*\"/register\""
    ["/users/current"]="@GetMapping.*\"/current\""
    
    # Post APIs
    ["/posts"]="@PostMapping$"
    ["/posts/list"]="@GetMapping.*\"/list\""
    ["/posts/{id}/detail"]="@GetMapping.*\"/{id}/detail\""
    ["/posts/{id}"]="@PutMapping.*\"/{id}\""
    ["/posts/my"]="@GetMapping.*\"/my\""
    ["/posts/timeline"]="@GetMapping.*\"/timeline\""
    
    # Comment APIs
    ["/comments"]="@PostMapping$"
    ["/comments/post/{postId}"]="@GetMapping.*\"/post/{postId}\""
    ["/comments/{id}"]="@PutMapping.*\"/{id}\""
    ["/comments/my"]="@GetMapping.*\"/my\""
    
    # Friend APIs
    ["/friends/request/{receiverId}"]="@PostMapping.*\"/request/{receiverId}\""
    ["/friends/accept/{requestId}"]="@PostMapping.*\"/accept/{requestId}\""
    ["/friends/reject/{requestId}"]="@PostMapping.*\"/reject/{requestId}\""
    ["/friends/user/{friendUserId}"]="@DeleteMapping.*\"/user/{friendUserId}\""
    ["/friends/list"]="@GetMapping.*\"/list\""
    ["/friends/requests"]="@GetMapping.*\"/requests\""
    ["/friends/search"]="@GetMapping.*\"/search\""
    
    # Like APIs
    ["/likes/{postId}"]="@PostMapping.*\"/{postId}\""
    ["/likes/{postId}/check"]="@GetMapping.*\"/{postId}/check\""
    ["/likes/{postId}/count"]="@GetMapping.*\"/{postId}/count\""
    
    # Upload APIs
    ["/upload/image"]="@PostMapping.*\"/image\""
    
    # Statistics APIs
    ["/stats/analyze"]="@PostMapping.*\"/analyze\""
    ["/stats"]="@GetMapping$"
    ["/stats/aggregated"]="@GetMapping.*\"/aggregated\""
    ["/stats/list"]="@GetMapping.*\"/list\""
    ["/stats/{type}"]="@GetMapping.*\"/{type}\""
)

echo "检查前端 API 定义..."
echo ""

# 验证每个 API 映射
for api_path in "${!API_MAPPINGS[@]}"; do
    TOTAL_APIS=$((TOTAL_APIS + 1))
    pattern="${API_MAPPINGS[$api_path]}"
    
    # 在后端 Controller 中搜索对应的注解
    found=false
    for controller_file in "${BACKEND_CONTROLLER_FILES[@]}"; do
        if [ -f "$controller_file" ]; then
            if grep -Pzo "$pattern" "$controller_file" > /dev/null 2>&1 || grep -E "$pattern" "$controller_file" > /dev/null 2>&1; then
                found=true
                break
            fi
        fi
    done
    
    if [ "$found" = true ]; then
        echo -e "${GREEN}✓${NC} $api_path"
        MATCHED_APIS=$((MATCHED_APIS + 1))
    else
        echo -e "${RED}✗${NC} $api_path ${YELLOW}(后端接口未找到)${NC}"
        UNMATCHED_APIS=$((UNMATCHED_APIS + 1))
    fi
done

echo ""
echo "========================================="
echo "   验证结果统计"
echo "========================================="
echo "总 API 数: $TOTAL_APIS"
echo -e "${GREEN}已匹配: $MATCHED_APIS${NC}"
if [ $UNMATCHED_APIS -gt 0 ]; then
    echo -e "${RED}未匹配: $UNMATCHED_APIS${NC}"
else
    echo -e "${GREEN}未匹配: $UNMATCHED_APIS${NC}"
fi
echo ""

# 检查前端文件是否存在
echo "========================================="
echo "   前端 API 文件检查"
echo "========================================="
for file in "${FRONTEND_API_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file ${YELLOW}(文件不存在)${NC}"
    fi
done
echo ""

# 检查后端 Controller 文件是否存在
echo "========================================="
echo "   后端 Controller 文件检查"
echo "========================================="
for file in "${BACKEND_CONTROLLER_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file ${YELLOW}(文件不存在)${NC}"
    fi
done
echo ""

if [ $UNMATCHED_APIS -eq 0 ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}   所有 API 映射验证通过！${NC}"
    echo -e "${GREEN}=========================================${NC}"
    exit 0
else
    echo -e "${YELLOW}=========================================${NC}"
    echo -e "${YELLOW}   部分 API 映射未通过验证${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    exit 1
fi
