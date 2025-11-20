#!/bin/bash

echo "========================================="
echo "   验证 PostgreSQL 主备集群"
echo "========================================="

# 添加 Docker 路径
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

# 启动集群
echo "启动集群..."
docker compose -f docker-compose-gaussdb-pseudo.yml up -d gaussdb-primary gaussdb-standby1 gaussdb-standby2

# 等待启动
echo "等待数据库启动（约 40 秒）..."
sleep 40

# 检查容器状态
echo ""
echo "容器状态："
docker ps --filter "name=gaussdb" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 检查复制状态
echo ""
echo "检查主库复制状态："
docker exec gaussdb-primary psql -U bloguser -d blog_db -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"

echo ""
echo "检查 standby1 复制状态："
docker exec gaussdb-standby1 psql -U bloguser -d blog_db -c "SELECT pg_is_in_recovery();"

echo ""
echo "检查 standby2 复制状态："
docker exec gaussdb-standby2 psql -U bloguser -d blog_db -c "SELECT pg_is_in_recovery();"

echo ""
echo "========================================="
echo "   验证完成"
echo "========================================="
echo ""
echo "如需停止集群，运行："
echo "  docker compose -f docker-compose-gaussdb-pseudo.yml down"
