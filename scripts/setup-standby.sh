#!/bin/bash

# 配置 openGauss 备库脚本
# 参数: $1 = standby容器名, $2 = 端口, $3 = application_name

STANDBY_CONTAINER=$1
STANDBY_PORT=$2
APP_NAME=$3

echo "=== 配置备库: $STANDBY_CONTAINER (端口: $STANDBY_PORT) ==="

# 1. 停止备库进程
echo "停止备库进程..."
docker exec $STANDBY_CONTAINER bash -c "pkill -9 gaussdb || true"
sleep 3

# 2. 清空并重新初始化
echo "重新初始化数据目录..."
docker exec $STANDBY_CONTAINER su - omm -c "
rm -rf /var/lib/opengauss/data/*
/usr/local/opengauss/bin/gs_initdb -D /var/lib/opengauss/data --nodename=${APP_NAME} -w Blog@2025
"

# 2.5 修改端口配置
echo "修改端口配置为 ${STANDBY_PORT}..."
docker exec $STANDBY_CONTAINER su - omm -c "
sed -i 's/^#*port = .*/port = ${STANDBY_PORT}/' /var/lib/opengauss/data/postgresql.conf
"

# 3. 配置 recovery.conf
echo "配置 recovery.conf..."
docker exec $STANDBY_CONTAINER su - omm -c "cat > /var/lib/opengauss/data/recovery.conf << 'EOF'
standby_mode = 'on'
primary_conninfo = 'host=opengauss-primary port=5432 user=replicator password=Blog@2025 application_name=${APP_NAME}'
recovery_target_timeline = 'latest'
EOF"

# 4. 创建 standby.signal
docker exec $STANDBY_CONTAINER su - omm -c "touch /var/lib/opengauss/data/standby.signal"

# 5. 启动备库
echo "启动备库..."
docker exec $STANDBY_CONTAINER su - omm -c "/usr/local/opengauss/bin/gs_ctl start -D /var/lib/opengauss/data -M standby"

sleep 5

# 6. 验证
echo "验证备库状态..."
docker exec $STANDBY_CONTAINER su - omm -c "PGPORT=${STANDBY_PORT} /usr/local/opengauss/bin/gsql -d postgres -p ${STANDBY_PORT} -c 'SELECT pg_is_in_recovery();'"

echo "=== 备库配置完成 ==="
