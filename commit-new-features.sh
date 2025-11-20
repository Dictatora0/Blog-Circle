#!/bin/bash

# 提交新功能到Git的脚本
# 使用方法: ./commit-new-features.sh "提交信息"

set -e

COMMIT_MSG="${1:-feat: 添加头像上传和个人主页优化功能}"

echo "========================================="
echo "    提交新功能到Git"
echo "========================================="
echo ""

# 检查是否在git仓库中
if [ ! -d ".git" ]; then
  echo "错误：当前目录不是git仓库"
  exit 1
fi

# 显示当前状态
echo "当前 Git 状态："
git status --short
echo ""

# 添加所有更改的文件
echo "添加文件到暂存区..."
git add backend/src/main/java/com/cloudcom/blog/entity/User.java
git add backend/src/main/java/com/cloudcom/blog/config/WebConfig.java
git add backend/src/main/resources/db/init.sql
git add backend/src/main/resources/db/migration_add_cover_image.sql
git add backend/src/main/resources/mapper/UserMapper.xml
git add frontend/src/views/Profile.vue
git add frontend/src/api/auth.js
git add frontend/src/api/upload.js
git add frontend/tests/e2e/avatar.spec.ts
git add frontend/tests/e2e/profile.spec.ts
git add .github/workflows/test.yml
git add test-avatar-upload.sh

# 添加文档文件（可选）
if [ -f "PROFILE_FIXES_COMPLETE.md" ]; then
  git add PROFILE_FIXES_COMPLETE.md
fi
if [ -f "PROFILE_BUG_FIXES.md" ]; then
  git add PROFILE_BUG_FIXES.md
fi
if [ -f "PROFILE_LAYOUT_OPTIMIZATION.md" ]; then
  git add PROFILE_LAYOUT_OPTIMIZATION.md
fi
if [ -f "AVATAR_UPLOAD_TEST_README.md" ]; then
  git add AVATAR_UPLOAD_TEST_README.md
fi

echo ""
echo "文件已添加到暂存区"
echo ""

# 显示将要提交的文件
echo "将要提交的文件："
git status --short
echo ""

# 确认提交
read -p "确认提交？(y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "提交已取消"
  exit 1
fi

# 提交
echo ""
echo "提交更改..."
git commit -m "$COMMIT_MSG"

echo ""
echo "提交成功！"
echo ""
echo "推送到远程仓库："
echo "   git push origin dev"
echo ""

