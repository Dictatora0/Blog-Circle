#!/bin/bash

set -e

echo "========================================="
echo "   Blog Circle 容器化部署脚本"
echo "========================================="
echo ""

if ! command -v docker &> /dev/null; then
    echo "错误: 未找到 Docker，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "错误: 未找到 Docker Compose，请先安装 Docker Compose"
    exit 1
fi

echo "1. 检查 Docker 版本..."
docker --version
docker-compose --version
echo ""

echo "2. 停止并删除现有容器..."
docker-compose down -v 2>/dev/null || true
echo ""

echo "3. 构建并启动所有服务..."
docker-compose up -d --build
echo ""

echo "4. 等待服务启动..."
sleep 10

echo "5. 检查服务状态..."
docker-compose ps
echo ""

echo "6. 查看服务日志..."
echo ""
echo "=== 数据库日志 ==="
docker-compose logs --tail=20 db
echo ""
echo "=== 后端日志 ==="
docker-compose logs --tail=20 backend
echo ""
echo "=== 前端日志 ==="
docker-compose logs --tail=20 frontend
echo ""

echo "========================================="
echo "   部署完成！"
echo "========================================="
echo ""
echo "访问地址："
echo "  前端: http://10.211.55.11:8080"
echo "  后端: http://10.211.55.11:8081"
echo ""
echo "测试账号："
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo "常用命令："
echo "  查看日志: docker-compose logs -f"
echo "  停止服务: docker-compose down"
echo "  重启服务: docker-compose restart"
echo ""














