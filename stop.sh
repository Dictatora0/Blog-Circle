#!/bin/bash

# 简易博客系统停止脚本

echo "========================================="
echo "       停止博客系统服务"
echo "========================================="
echo ""

# 停止后端
if [ -f "logs/backend.pid" ]; then
    BACKEND_PID=$(cat logs/backend.pid)
    echo "正在停止后端服务 (PID: $BACKEND_PID)..."
    kill $BACKEND_PID 2>/dev/null
    rm logs/backend.pid
    echo "后端服务已停止"
else
    echo "⚠️  未找到后端服务 PID"
fi

# 停止前端
if [ -f "logs/frontend.pid" ]; then
    FRONTEND_PID=$(cat logs/frontend.pid)
    echo "正在停止前端服务 (PID: $FRONTEND_PID)..."
    kill $FRONTEND_PID 2>/dev/null
    rm logs/frontend.pid
    echo "前端服务已停止"
else
    echo "⚠️  未找到前端服务 PID"
fi

# 清理可能残留的进程
echo ""
echo "清理残留进程..."
pkill -f "spring-boot:run" 2>/dev/null
pkill -f "vite" 2>/dev/null

echo ""
echo "========================================="
echo "       所有服务已停止"
echo "========================================="


