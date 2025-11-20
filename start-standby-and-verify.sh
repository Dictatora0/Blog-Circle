#!/bin/bash

# 启动备库并验证脚本

# 检测 Docker 路径
if [ -f "/Applications/Docker.app/Contents/Resources/bin/docker" ]; then
    DOCKER="/Applications/Docker.app/Contents/Resources/bin/docker"
elif command -v docker &> /dev/null; then
    DOCKER="docker"
else
    echo "错误：找不到 Docker 命令"
    exit 1
fi

echo "使用 Docker: $DOCKER"

echo "=========================================="
echo "启动 GaussDB 备库并验证"
echo "=========================================="
echo ""

# 启动备库1
echo "[1/4] 启动备库1 (gaussdb-standby1)..."
$DOCKER compose -f docker-compose-gaussdb-pseudo.yml up -d gaussdb-standby1

# 启动备库2
echo "[2/4] 启动备库2 (gaussdb-standby2)..."
$DOCKER compose -f docker-compose-gaussdb-pseudo.yml up -d gaussdb-standby2

# 等待备库启动
echo "[3/4] 等待备库启动..."
echo "提示：备库初始化需要从主库复制数据，可能需要30-60秒"
sleep 30

# 检查容器状态
echo "[4/4] 检查集群状态..."
echo ""
$DOCKER compose -f docker-compose-gaussdb-pseudo.yml ps

echo ""
echo "=========================================="
echo "验证 1主2备 集群"
echo "=========================================="

# 统计运行中的容器
RUNNING_COUNT=$($DOCKER compose -f docker-compose-gaussdb-pseudo.yml ps | grep "gaussdb" | grep "Up" | wc -l | tr -d ' ')

echo ""
echo "运行中的 GaussDB 节点: $RUNNING_COUNT/3"

# 检查每个节点
if $DOCKER compose -f docker-compose-gaussdb-pseudo.yml ps | grep -q "gaussdb-primary.*Up"; then
    echo "✓ 主库 (gaussdb-primary) - 运行中"
else
    echo "✗ 主库 (gaussdb-primary) - 未运行"
fi

if $DOCKER compose -f docker-compose-gaussdb-pseudo.yml ps | grep -q "gaussdb-standby1.*Up"; then
    echo "✓ 备库1 (gaussdb-standby1) - 运行中"
else
    echo "✗ 备库1 (gaussdb-standby1) - 未运行"
fi

if $DOCKER compose -f docker-compose-gaussdb-pseudo.yml ps | grep -q "gaussdb-standby2.*Up"; then
    echo "✓ 备库2 (gaussdb-standby2) - 运行中"
else
    echo "✗ 备库2 (gaussdb-standby2) - 未运行"
fi

echo ""
echo "=========================================="
if [ "$RUNNING_COUNT" -eq 3 ]; then
    echo "✓ GaussDB 1主2备集群启动成功！"
else
    echo "⚠ 集群未完全启动 ($RUNNING_COUNT/3)"
    echo "提示：备库可能还在初始化中，请等待1-2分钟后再次检查"
fi
echo "=========================================="

echo ""
echo "查看备库日志："
echo "  docker compose -f docker-compose-gaussdb-pseudo.yml logs gaussdb-standby1"
echo "  docker compose -f docker-compose-gaussdb-pseudo.yml logs gaussdb-standby2"
echo ""
echo "重新验证集群："
echo "  ./verify-gaussdb-cluster.sh"
echo ""
