#!/bin/bash

# 头像上传功能测试脚本
# 使用方法: ./test-avatar-upload.sh

set -e

echo "========================================="
echo "    头像上传功能 E2E 测试"
echo "========================================="
echo ""

# 进入前端目录
cd "$(dirname "$0")/frontend"

# 检查是否安装了依赖
if [ ! -d "node_modules" ]; then
  echo "⚠️  未检测到 node_modules，正在安装依赖..."
  npm install
fi

# 检查 Playwright 是否已安装
if [ ! -d "node_modules/@playwright" ]; then
  echo "⚠️  Playwright 未安装，正在安装..."
  npx playwright install chromium
fi

echo ""
echo "🚀 开始运行头像上传功能测试..."
echo ""

# 运行头像上传测试
npx playwright test tests/e2e/avatar.spec.ts --reporter=list,html

echo ""
echo "========================================="
echo "    测试完成"
echo "========================================="
echo ""
echo "📊 查看详细报告:"
echo "   npx playwright show-report"
echo ""

