#!/bin/bash
set -e

###############################################################
# PostgreSQL 主库启动脚本
# 配置流复制和 pg_hba.conf
###############################################################

echo "========================================="
echo "配置 PostgreSQL 主库"
echo "========================================="

# 等待 PostgreSQL 初始化完成
if [ -s "$PGDATA/PG_VERSION" ]; then
    echo "数据目录已存在，配置复制..."
    
    # 配置 pg_hba.conf 允许复制连接
    if ! grep -q "replication" "$PGDATA/pg_hba.conf" 2>/dev/null; then
        echo "# 允许流复制连接" >> "$PGDATA/pg_hba.conf"
        echo "host    replication     all             0.0.0.0/0               trust" >> "$PGDATA/pg_hba.conf"
        echo "host    all             all             0.0.0.0/0               trust" >> "$PGDATA/pg_hba.conf"
        echo "✓ pg_hba.conf 已配置"
    fi
fi

# 使用标准的 docker-entrypoint.sh
exec docker-entrypoint.sh "$@"
