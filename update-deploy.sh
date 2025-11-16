#!/bin/bash

set -e

echo "========================================="
echo "   Blog Circle 更新部署脚本"
echo "========================================="
echo ""

# 检查是否在项目目录
if [ ! -f "docker-compose.yml" ]; then
    echo "错误: 请在项目根目录执行此脚本"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "错误: 未找到 Git，请先安装 Git"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "错误: 未找到 Docker，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "错误: 未找到 Docker Compose，请先安装 Docker Compose"
    exit 1
fi

echo "1. 检查当前分支和状态..."
git status
echo ""

echo "2. 拉取最新代码（dev 分支）..."
git fetch origin dev
git pull origin dev
echo ""

echo "3. 显示最新提交信息..."
git log --oneline -3
echo ""

echo "4. 验证 docker-compose.yml 文件..."
if [ ! -f "docker-compose.yml" ]; then
    echo "错误: docker-compose.yml 文件不存在"
    exit 1
fi
echo "✓ docker-compose.yml 存在"
echo ""

echo "5. 停止现有容器（保留数据卷）..."
docker-compose down 2>/dev/null || true
echo ""

echo "6. 构建并启动所有服务..."
docker-compose up -d --build
echo ""

echo "7. 等待服务启动..."
sleep 15
echo ""

echo "8. 检查服务状态..."
docker-compose ps
echo ""

echo "9. 查看服务日志（最后20行）..."
echo ""
echo "=== 数据库日志 ==="
docker-compose logs --tail=20 db 2>/dev/null || echo "数据库日志暂不可用"
echo ""
echo "=== 后端日志 ==="
docker-compose logs --tail=20 backend 2>/dev/null || echo "后端日志暂不可用"
echo ""
echo "=== 前端日志 ==="
docker-compose logs --tail=20 frontend 2>/dev/null || echo "前端日志暂不可用"
echo ""

echo "========================================="
echo "   更新部署完成！"
echo "========================================="
echo ""
echo "访问地址："
echo "  前端: http://10.211.55.11:8080"
echo "  后端: http://10.211.55.11:8081"
echo ""
echo "常用命令："
echo "  查看所有日志: docker-compose logs -f"
echo "  查看后端日志: docker-compose logs -f backend"
echo "  重启服务: docker-compose restart"
echo "  停止服务: docker-compose down"
echo ""

