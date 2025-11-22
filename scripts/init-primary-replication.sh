#!/bin/bash
set -e

###############################################################
# 主库复制配置初始化脚本
# 在数据库初始化时执行
###############################################################

echo "配置主库流复制..."

# 配置 pg_hba.conf
cat >> "$PGDATA/pg_hba.conf" << EOF

# 流复制配置
host    replication     all             0.0.0.0/0               trust
host    all             all             0.0.0.0/0               trust
EOF

echo "✓ pg_hba.conf 配置完成"
