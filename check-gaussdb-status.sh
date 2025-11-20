#!/bin/bash

# GaussDB 状态检查脚本

echo "=========================================="
echo "GaussDB 集群状态检查"
echo "=========================================="

# 检查容器状态
echo ""
echo "[1/4] 检查容器状态..."
docker compose -f docker-compose-gaussdb-pseudo.yml ps

# 检查主库日志
echo ""
echo "[2/4] 检查主库最新日志..."
echo "查找关键信息：'ready for start up' 或 'database system is ready'"
docker compose -f docker-compose-gaussdb-pseudo.yml logs gaussdb-primary | grep -E "ready|started|listening" | tail -10

# 尝试连接主库
echo ""
echo "[3/4] 尝试连接主库..."
if docker compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-primary \
    gsql -d blog_db -U bloguser -W OpenGauss@123 -c "SELECT version();" 2>/dev/null; then
    echo "✓ 主库连接成功"
else
    echo "⚠ 主库连接失败（可能还在初始化中）"
fi

# 检查数据
echo ""
echo "[4/4] 检查测试数据..."
if docker compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-primary \
    gsql -d blog_db -U bloguser -W OpenGauss@123 -c "SELECT username FROM users;" 2>/dev/null; then
    echo "✓ 测试数据查询成功"
else
    echo "⚠ 测试数据查询失败"
fi

echo ""
echo "=========================================="
echo "状态检查完成"
echo "=========================================="
echo ""
echo "如果主库显示 'Up' 但连接失败，请等待1-2分钟后重试"
echo "GaussDB 初始化通常需要60-90秒"
echo ""
echo "手动连接命令："
echo "docker compose -f docker-compose-gaussdb-pseudo.yml exec -it gaussdb-primary \\"
echo "    gsql -d blog_db -U bloguser -W OpenGauss@123"
echo "=========================================="
