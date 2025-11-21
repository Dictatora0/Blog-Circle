#!/bin/bash
set -e

echo "配置 PostgreSQL 复制..."

# 添加复制连接到 pg_hba.conf
cat >> "$PGDATA/pg_hba.conf" << EOF

# 允许复制连接
host    replication     bloguser        0.0.0.0/0               md5
host    all             bloguser        0.0.0.0/0               md5
EOF

echo "复制配置完成"
