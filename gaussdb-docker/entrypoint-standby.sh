#!/bin/bash

set -e

echo "========================================="
echo "   PostgreSQL Standby 初始化"
echo "========================================="

PRIMARY_HOST=$1
STANDBY_PORT=${2:-5432}

# 等待 primary 启动
echo "等待 primary ($PRIMARY_HOST) 启动..."
while ! pg_isready -h $PRIMARY_HOST -p 5432; do
    echo "等待 primary..."
    sleep 2
done

# 如果数据目录不存在，从 primary 复制基础备份
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "从 primary 复制数据..."
    pg_basebackup -h $PRIMARY_HOST -p 5432 -U bloguser -D $PGDATA -Fp -Xs -P -R --wal-method=stream
fi

# 配置 standby 模式
echo "配置 standby 模式..."
cat >> $PGDATA/postgresql.conf << EOF

# Standby 配置
hot_standby = on
EOF

# 启动 PostgreSQL standby
echo "启动 PostgreSQL Standby..."
exec docker-entrypoint.sh postgres
