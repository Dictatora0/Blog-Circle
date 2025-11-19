#!/bin/bash
# 快速测试脚本 - 假设服务器已经在运行

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================="
echo "   快速 E2E 测试 (服务器已运行)"
echo "========================================="
echo ""

# 检查服务器
echo "检查后端服务..."
if curl -f http://localhost:8080/ > /dev/null 2>&1; then
    echo -e "${GREEN}后端运行中${NC}"
else
    echo -e "${RED}❌ 后端未运行，请先启动：cd backend && mvn spring-boot:run${NC}"
    exit 1
fi

echo "检查前端服务..."
if curl -f http://localhost:5173 > /dev/null 2>&1; then
    echo -e "${GREEN}前端运行中${NC}"
else
    echo -e "${RED}❌ 前端未运行，请先启动：cd frontend && npm run dev${NC}"
    exit 1
fi

echo ""
echo "运行 E2E 测试..."
cd frontend

# 不设置 CI=true，让 Playwright 配置重用现有服务器
export BASE_URL=http://localhost:5173
export API_BASE_URL=http://localhost:8080/api

# 运行特定测试或所有测试
if [ -n "$1" ]; then
    echo "运行指定测试: $1"
    npx playwright test "$1" --reporter=list
else
    echo "运行所有 E2E 测试..."
    npx playwright test --reporter=list
fi

echo ""
echo "测试完成！查看报告："
echo "  npx playwright show-report"

