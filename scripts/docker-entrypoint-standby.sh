#!/bin/sh
set -e

###############################################################
# PostgreSQL 备库启动脚本
# 使用流复制从主库同步数据
###############################################################

PRIMARY_HOST="${POSTGRES_PRIMARY_HOST:-gaussdb-primary}"
PRIMARY_PORT="${POSTGRES_PRIMARY_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-bloguser}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-Blog@2025}"
PGDATA="${PGDATA:-/var/lib/postgresql/data/pgdata}"

echo "========================================="
echo "启动 PostgreSQL 备库"
echo "========================================="
echo "主库: ${PRIMARY_HOST}:${PRIMARY_PORT}"
echo "数据目录: ${PGDATA}"
echo ""

# 等待主库就绪
echo "等待主库就绪..."
for i in $(seq 1 60); do
    if pg_isready -h ${PRIMARY_HOST} -p ${PRIMARY_PORT} -U ${POSTGRES_USER} > /dev/null 2>&1; then
        echo "✓ 主库已就绪"
        break
    fi
    
    if [ $i -eq 60 ]; then
        echo "✗ 主库连接超时"
        exit 1
    fi
    
    echo "  等待主库... ($i/60)"
    sleep 2
done

# 如果数据目录为空，从主库进行基础备份
if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    echo "数据目录为空，从主库同步数据..."
    
    # 确保目录存在且权限正确
    mkdir -p ${PGDATA}
    chmod 700 ${PGDATA}
    
    # 使用 pg_basebackup 从主库克隆数据
    PGPASSWORD=${POSTGRES_PASSWORD} pg_basebackup \
        -h ${PRIMARY_HOST} \
        -p ${PRIMARY_PORT} \
        -U ${POSTGRES_USER} \
        -D ${PGDATA} \
        -Fp \
        -Xs \
        -P \
        -R \
        -v
    
    echo "✓ 基础备份完成"
    
    # 配置备库参数
    cat >> ${PGDATA}/postgresql.conf << EOF

# Standby configuration
hot_standby = on
max_standby_streaming_delay = 30s
wal_receiver_status_interval = 1s
hot_standby_feedback = on
EOF

    # 创建 standby.signal 文件（PostgreSQL 12+）
    touch ${PGDATA}/standby.signal
    
    # 配置主库连接信息
    cat > ${PGDATA}/postgresql.auto.conf << EOF
# Primary server connection
primary_conninfo = 'host=${PRIMARY_HOST} port=${PRIMARY_PORT} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD} application_name=$(hostname)'
primary_slot_name = '$(hostname | tr '-' '_')'
restore_command = 'cp /var/lib/postgresql/data/pg_wal/%f %p'
EOF
    
    echo "✓ 备库配置完成"
else
    echo "数据目录已存在，使用现有数据"
fi

# 确保权限正确
chown -R postgres:postgres ${PGDATA}

# 启动 PostgreSQL（以 postgres 用户运行）
echo "启动 PostgreSQL..."
exec su-exec postgres postgres \
    -c hot_standby=on \
    -c max_standby_streaming_delay=30s \
    -c wal_receiver_status_interval=1s \
    -c hot_standby_feedback=on \
    -c listen_addresses='*'
