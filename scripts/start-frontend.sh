#!/bin/bash

###############################################################
# 前端服务启动脚本
# 支持开发模式和生产构建
###############################################################

set -e

MODE="${1:-dev}"
PORT="${2:-5173}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   启动前端服务"
echo "========================================="
echo ""
echo "模式: $MODE"
echo "端口: $PORT"
echo ""

cd frontend

# 1. 检查 Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}✗ 未找到 Node.js，请先安装${NC}"
    exit 1
fi

# 2. 检查 npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}✗ 未找到 npm，请先安装${NC}"
    exit 1
fi

# 3. 安装依赖
if [ ! -d "node_modules" ]; then
    echo "=== 安装依赖 ==="
    npm install
    echo ""
fi

# 4. 启动服务
if [ "$MODE" == "prod" ] || [ "$MODE" == "build" ]; then
    echo "=== 构建生产版本 ==="
    npm run build
    echo ""
    echo -e "${GREEN}✓ 构建完成${NC}"
    echo "构建文件位于: dist/"
    echo ""
    echo "使用以下命令启动生产服务器:"
    echo "  cd dist && python3 -m http.server $PORT"
else
    echo "=== 启动开发服务器 ==="
    echo "访问地址: http://localhost:$PORT"
    echo ""
    echo "按 Ctrl+C 停止服务"
    echo ""
    npm run dev -- --port $PORT
fi
