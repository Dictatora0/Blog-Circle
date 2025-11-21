#!/bin/bash

set -e

echo "========================================="
echo "   PostgreSQL 伪分布式集群启动脚本"
echo "========================================="

# 检查 Docker 服务是否运行
if ! docker info &> /dev/null; then
    log_error "Docker 服务未运行，请启动 Docker"
    exit 1
fi

# 启动 compose
echo "启动容器集群..."
docker-compose -f docker-compose-gaussdb-pseudo.yml up -d gaussdb-primary

# 等待 primary 启动
echo "等待 primary 启动..."
sleep 10
while ! docker-compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-primary pg_isready -U bloguser; do
    echo "等待 primary..."
    sleep 2
done

# 启动 standby
echo "启动 standby 容器..."
docker-compose -f docker-compose-gaussdb-pseudo.yml up -d gaussdb-standby1 gaussdb-standby2

# 等待所有数据库启动
echo "等待所有数据库启动..."
sleep 10
for service in gaussdb-primary gaussdb-standby1 gaussdb-standby2; do
    while ! docker-compose -f docker-compose-gaussdb-pseudo.yml exec -T $service pg_isready -U bloguser; do
        echo "等待 $service..."
        sleep 2
    done
done

# 验证复制状态
echo "验证复制状态..."
docker-compose -f docker-compose-gaussdb-pseudo.yml exec -T gaussdb-primary psql -U bloguser -d blog_db -c "SELECT * FROM pg_stat_replication;"

# 启动应用服务
echo "启动应用服务..."
docker-compose -f docker-compose-gaussdb-pseudo.yml up -d backend frontend spark-master spark-worker

echo "========================================="
echo "   集群启动完成"
echo "========================================="
echo ""
echo "服务状态："
echo "  Primary: localhost:5432"
echo "  Standby1: localhost:5433"
echo "  Standby2: localhost:5434"
echo "  Backend: http://localhost:8081"
echo "  Frontend: http://localhost:8082"
echo "  Spark Master: http://localhost:8090"
echo ""
echo "测试连接："
echo "  psql -h localhost -p 5432 -d blog_db -U bloguser"
