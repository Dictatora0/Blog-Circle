#!/bin/bash

set -e

echo "========================================="
echo "   PostgreSQL Primary 初始化"
echo "========================================="

# 等待数据目录初始化完成（PostgreSQL 会在第一次运行时自动初始化）
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "等待 PostgreSQL 自动初始化数据目录..."
    # PostgreSQL 容器会在第一次启动时自动初始化
    # 我们只需要确保配置文件正确
    sleep 2
fi

# 创建必要的目录
mkdir -p $PGDATA

# 配置 postgresql.conf
echo "配置 postgresql.conf..."
cat >> $PGDATA/postgresql.conf << EOF

# 监听所有地址
listen_addresses = '*'

# 连接配置
max_connections = 200

# WAL 配置
wal_level = replica
max_wal_senders = 10
wal_keep_segments = 64

# 复制配置
hot_standby = on
wal_sender_timeout = 60s
wal_receiver_timeout = 60s

# 其他配置
shared_preload_libraries = 'pg_stat_statements'

# 本地访问
local   all    all    trust
host    all    all    127.0.0.1/32    trust
EOF

# 启动 PostgreSQL
echo "启动 PostgreSQL..."
exec docker-entrypoint.sh postgres
