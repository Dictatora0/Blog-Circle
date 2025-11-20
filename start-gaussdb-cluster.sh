#!/bin/bash

# GaussDB 集群启动脚本

set -e

echo "=========================================="
echo "启动 GaussDB 主备集群"
echo "=========================================="

# 清理旧容器和数据卷
echo "[1/5] 清理旧环境..."
docker compose -f docker-compose-gaussdb-pseudo.yml down -v 2>/dev/null || true

# 启动主库
echo "[2/5] 启动 GaussDB 主库..."
docker compose -f docker-compose-gaussdb-pseudo.yml up -d gaussdb-primary

# 等待主库就绪
echo "[3/5] 等待主库启动..."
echo "提示：GaussDB 初始化需要约60秒..."
sleep 30  # 先等待30秒让初始化完成

for i in {1..30}; do
    # 检查容器是否在运行
    if ! docker compose -f docker-compose-gaussdb-pseudo.yml ps gaussdb-primary | grep -q "Up"; then
        echo "✗ 主库容器未运行"
        docker compose -f docker-compose-gaussdb-pseudo.yml logs gaussdb-primary | tail -50
        exit 1
    fi
    
    # 尝试连接数据库
    if docker compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-primary \
        gsql -d blog_db -U bloguser -W OpenGauss@123 -c "SELECT 1" &>/dev/null; then
        echo "✓ 主库启动成功并可以连接"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "⚠ 主库启动超时，但容器正在运行"
        echo "提示：主库可能仍在初始化中，请稍后手动验证"
        docker compose -f docker-compose-gaussdb-pseudo.yml logs gaussdb-primary | tail -30
        # 不退出，继续尝试启动备库
        break
    fi
    echo "等待主库响应... ($i/30)"
    sleep 3
done

# 启动备库
echo "[4/5] 启动 GaussDB 备库..."
docker compose -f docker-compose-gaussdb-pseudo.yml up -d gaussdb-standby1 gaussdb-standby2

# 等待备库就绪
echo "[5/5] 等待备库启动..."
sleep 20

for i in {1..20}; do
    STANDBY1_OK=false
    STANDBY2_OK=false
    
    if docker compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-standby1 \
        gsql -d blog_db -U bloguser -W OpenGauss@123 -c "SELECT 1" &>/dev/null; then
        STANDBY1_OK=true
    fi
    
    if docker compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-standby2 \
        gsql -d blog_db -U bloguser -W OpenGauss@123 -c "SELECT 1" &>/dev/null; then
        STANDBY2_OK=true
    fi
    
    if [ "$STANDBY1_OK" = true ] && [ "$STANDBY2_OK" = true ]; then
        echo "✓ 所有备库启动成功"
        break
    fi
    
    if [ $i -eq 20 ]; then
        echo "⚠ 备库启动超时，但主库已就绪"
        break
    fi
    
    echo "等待备库... ($i/20)"
    sleep 3
done

echo ""
echo "=========================================="
echo "GaussDB 集群状态"
echo "=========================================="
docker compose -f docker-compose-gaussdb-pseudo.yml ps

echo ""
echo "=========================================="
echo "验证主库连接"
echo "=========================================="
docker compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-primary \
    gsql -d blog_db -U bloguser -W OpenGauss@123 -c "SELECT version();"

echo ""
echo "=========================================="
echo "查看复制状态"
echo "=========================================="
docker compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-primary \
    gsql -d blog_db -U bloguser -W OpenGauss@123 -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;" || \
    echo "⚠ 复制状态查询失败（可能备库尚未完全就绪）"

echo ""
echo "=========================================="
echo "✓ GaussDB 集群启动完成"
echo "=========================================="
echo "主库: localhost:5432"
echo "备库1: localhost:5433"
echo "备库2: localhost:5434"
echo "用户: bloguser"
echo "密码: OpenGauss@123"
echo "数据库: blog_db"
echo "=========================================="
