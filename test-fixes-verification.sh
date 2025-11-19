#!/bin/bash

# 测试修复验证脚本

echo "🧪 Blog Circle 测试修复验证"
echo "================================"
echo ""

cd frontend

echo "📋 测试 1/3: 验证认证模块（核心修复）"
echo "-----------------------------------"
npx playwright test tests/e2e/auth.spec.ts::18 --reporter=line || true
echo ""

echo "📋 测试 2/3: 验证上传模块（localStorage修复）"
echo "-----------------------------------"
npx playwright test tests/e2e/upload.spec.ts::19 --reporter=line || true
echo ""

echo "📋 测试 3/3: 验证动态发布（综合测试）"
echo "-----------------------------------"
npx playwright test tests/e2e/posts.spec.ts::18 --reporter=line || true
echo ""

echo "================================"
echo "验证完成！"
echo ""
echo "💡 提示："
echo "  - 如果以上3个测试都通过，说明修复成功"
echo "  - 运行完整测试: npm run test:e2e"
echo "  - 查看报告: npx playwright show-report"
