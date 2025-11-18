#!/bin/bash

# 测试容器到 GaussDB 的连接
# 用法: ./test-gaussdb-connection.sh

set -e

echo "========================================="
echo "   测试 GaussDB 集群连接"
echo "========================================="
echo ""

# GaussDB 配置
PRIMARY_HOST="10.211.55.11"
STANDBY1_HOST="10.211.55.14"
STANDBY2_HOST="10.211.55.13"
PORT="5432"
DATABASE="blog_db"
USERNAME="bloguser"
PRIMARY_PASSWORD="747599qw@"
STANDBY_PASSWORD="747599qw@1"

echo "1. 测试网络连通性..."
echo ""

echo "测试主库 ${PRIMARY_HOST}:${PORT}..."
nc -zv ${PRIMARY_HOST} ${PORT} 2>&1 || echo "✗ 主库网络不通"

echo ""
echo "测试备库1 ${STANDBY1_HOST}:${PORT}..."
nc -zv ${STANDBY1_HOST} ${PORT} 2>&1 || echo "✗ 备库1网络不通"

echo ""
echo "测试备库2 ${STANDBY2_HOST}:${PORT}..."
nc -zv ${STANDBY2_HOST} ${PORT} 2>&1 || echo "✗ 备库2网络不通"

echo ""
echo "2. 测试数据库连接（使用 psql）..."
echo ""

# 测试主库
echo "测试主库连接..."
PGPASSWORD="${PRIMARY_PASSWORD}" psql -h ${PRIMARY_HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "SELECT 'PRIMARY OK' as status, version();" 2>&1 || echo "✗ 主库连接失败"

echo ""
echo "测试备库1连接..."
PGPASSWORD="${STANDBY_PASSWORD}" psql -h ${STANDBY1_HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "SELECT 'STANDBY1 OK' as status, pg_is_in_recovery();" 2>&1 || echo "✗ 备库1连接失败"

echo ""
echo "测试备库2连接..."
PGPASSWORD="${STANDBY_PASSWORD}" psql -h ${STANDBY2_HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "SELECT 'STANDBY2 OK' as status, pg_is_in_recovery();" 2>&1 || echo "✗ 备库2连接失败"

echo ""
echo "3. 测试表访问..."
PGPASSWORD="${PRIMARY_PASSWORD}" psql -h ${PRIMARY_HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} << 'EOSQL'
SELECT 'users' as table_name, COUNT(*) as count FROM users;
SELECT 'posts' as table_name, COUNT(*) as count FROM posts;
SELECT 'comments' as table_name, COUNT(*) as count FROM comments;
SELECT 'statistics' as table_name, COUNT(*) as count FROM statistics;
EOSQL

echo ""
echo "========================================="
echo "   测试完成"
echo "========================================="
