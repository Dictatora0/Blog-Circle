#!/bin/bash

# 在单个 VM (10.211.55.11) 上部署 GaussDB 一主二备集群
# 使用不同端口运行三个实例

set -e

VM_IP="10.211.55.11"
VM_USER="root"

# 三个实例的配置
PRIMARY_PORT=5432
STANDBY1_PORT=5433
STANDBY2_PORT=5434

PRIMARY_DATA="/usr/local/opengauss/data_primary"
STANDBY1_DATA="/usr/local/opengauss/data_standby1"
STANDBY2_DATA="/usr/local/opengauss/data_standby2"

DB_PASSWORD="747599qw@"
REPL_PASSWORD="747599qw@"

cat << 'EOF'
========================================
GaussDB 单机一主二备集群部署脚本
========================================

架构说明:
- VM: 10.211.55.11
- 主库端口: 5432 (数据目录: /usr/local/opengauss/data_primary)
- 备库1端口: 5433 (数据目录: /usr/local/opengauss/data_standby1)
- 备库2端口: 5434 (数据目录: /usr/local/opengauss/data_standby2)

请在 VM (10.211.55.11) 上以 root 用户执行以下命令:
========================================

EOF

cat << 'VMEOF'
#!/bin/bash
# 在 VM 10.211.55.11 上执行此脚本

set -e

PRIMARY_PORT=5432
STANDBY1_PORT=5433
STANDBY2_PORT=5434

PRIMARY_DATA="/usr/local/opengauss/data_primary"
STANDBY1_DATA="/usr/local/opengauss/data_standby1"
STANDBY2_DATA="/usr/local/opengauss/data_standby2"

DB_PASSWORD="747599qw@"

echo "========================================="
echo "步骤 1: 停止现有数据库实例"
echo "========================================="

su - omm -c "gs_ctl stop -D /usr/local/opengauss/data" || true

echo "========================================="
echo "步骤 2: 备份现有数据"
echo "========================================="

if [ -d "/usr/local/opengauss/data" ]; then
    mv /usr/local/opengauss/data /usr/local/opengauss/data.backup.$(date +%Y%m%d_%H%M%S)
    echo "已备份现有数据到 data.backup.*"
fi

echo "========================================="
echo "步骤 3: 初始化主库"
echo "========================================="

# 创建主库数据目录
mkdir -p $PRIMARY_DATA
chown omm:dbgrp $PRIMARY_DATA
chmod 700 $PRIMARY_DATA

# 初始化主库
su - omm -c "gs_initdb -D $PRIMARY_DATA --nodename=primary -w $DB_PASSWORD"

# 配置主库 postgresql.conf
cat >> $PRIMARY_DATA/postgresql.conf << PGCONF

# 主库配置
port = $PRIMARY_PORT
listen_addresses = '*'
max_connections = 200

# 复制配置
wal_level = replica
max_wal_senders = 10
wal_keep_size = 1024
max_replication_slots = 10
hot_standby = on
PGCONF

# 配置 pg_hba.conf
cat >> $PRIMARY_DATA/pg_hba.conf << HBACONF

# 允许本地复制连接
host    replication     replicator     127.0.0.1/32          md5
host    replication     replicator     10.211.55.11/32       md5

# 允许应用连接
host    all             all            0.0.0.0/0             md5
HBACONF

# 启动主库
su - omm -c "gs_ctl start -D $PRIMARY_DATA"

echo "等待主库启动..."
sleep 5

echo "========================================="
echo "步骤 4: 创建复制用户和数据库"
echo "========================================="

# 创建复制用户
su - omm -c "gsql -d postgres -p $PRIMARY_PORT -c \"CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '$DB_PASSWORD';\""

# 创建业务数据库
su - omm -c "gsql -d postgres -p $PRIMARY_PORT -c \"CREATE DATABASE blog_db;\""

# 创建业务用户
su - omm -c "gsql -d postgres -p $PRIMARY_PORT -c \"CREATE USER bloguser WITH PASSWORD '$DB_PASSWORD';\""
su - omm -c "gsql -d postgres -p $PRIMARY_PORT -c \"GRANT ALL PRIVILEGES ON DATABASE blog_db TO bloguser;\""

# 创建复制槽
su - omm -c "gsql -d postgres -p $PRIMARY_PORT -c \"SELECT pg_create_physical_replication_slot('standby1_slot');\""
su - omm -c "gsql -d postgres -p $PRIMARY_PORT -c \"SELECT pg_create_physical_replication_slot('standby2_slot');\""

echo "========================================="
echo "步骤 5: 初始化备库1"
echo "========================================="

# 创建备库1数据目录
mkdir -p $STANDBY1_DATA
chown omm:dbgrp $STANDBY1_DATA
chmod 700 $STANDBY1_DATA

# 从主库同步数据
su - omm -c "gs_basebackup -h 127.0.0.1 -p $PRIMARY_PORT -U replicator -D $STANDBY1_DATA -Fp -Xs -P -R" << PASSWD
$DB_PASSWORD
PASSWD

# 配置备库1端口
cat >> $STANDBY1_DATA/postgresql.conf << PGCONF

# 备库1配置
port = $STANDBY1_PORT
PGCONF

# 配置复制连接
cat > $STANDBY1_DATA/postgresql.auto.conf << AUTOCONF
primary_conninfo = 'host=127.0.0.1 port=$PRIMARY_PORT user=replicator password=$DB_PASSWORD application_name=standby1'
primary_slot_name = 'standby1_slot'
hot_standby = on
AUTOCONF

# 创建 standby.signal
touch $STANDBY1_DATA/standby.signal

# 启动备库1
su - omm -c "gs_ctl start -D $STANDBY1_DATA"

echo "等待备库1启动..."
sleep 5

echo "========================================="
echo "步骤 6: 初始化备库2"
echo "========================================="

# 创建备库2数据目录
mkdir -p $STANDBY2_DATA
chown omm:dbgrp $STANDBY2_DATA
chmod 700 $STANDBY2_DATA

# 从主库同步数据
su - omm -c "gs_basebackup -h 127.0.0.1 -p $PRIMARY_PORT -U replicator -D $STANDBY2_DATA -Fp -Xs -P -R" << PASSWD
$DB_PASSWORD
PASSWD

# 配置备库2端口
cat >> $STANDBY2_DATA/postgresql.conf << PGCONF

# 备库2配置
port = $STANDBY2_PORT
PGCONF

# 配置复制连接
cat > $STANDBY2_DATA/postgresql.auto.conf << AUTOCONF
primary_conninfo = 'host=127.0.0.1 port=$PRIMARY_PORT user=replicator password=$DB_PASSWORD application_name=standby2'
primary_slot_name = 'standby2_slot'
hot_standby = on
AUTOCONF

# 创建 standby.signal
touch $STANDBY2_DATA/standby.signal

# 启动备库2
su - omm -c "gs_ctl start -D $STANDBY2_DATA"

echo "等待备库2启动..."
sleep 5

echo "========================================="
echo "步骤 7: 验证集群状态"
echo "========================================="

echo "检查主库复制状态..."
su - omm -c "gsql -d postgres -p $PRIMARY_PORT -c 'SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;'"

echo ""
echo "检查备库1状态..."
su - omm -c "gsql -d postgres -p $STANDBY1_PORT -c 'SELECT pg_is_in_recovery();'"

echo ""
echo "检查备库2状态..."
su - omm -c "gsql -d postgres -p $STANDBY2_PORT -c 'SELECT pg_is_in_recovery();'"

echo ""
echo "========================================="
echo "集群部署完成！"
echo "========================================="
echo "主库端口: $PRIMARY_PORT"
echo "备库1端口: $STANDBY1_PORT"
echo "备库2端口: $STANDBY2_PORT"
echo ""
echo "数据库: blog_db"
echo "用户: bloguser"
echo "密码: $DB_PASSWORD"
echo ""
echo "请在本地 Mac 运行验证脚本:"
echo "  ./test-gaussdb-single-vm-cluster.sh"
echo "========================================="

VMEOF

echo ""
echo "========================================="
echo "使用说明"
echo "========================================="
echo ""
echo "1. 将上述脚本保存到 VM 上，例如:"
echo "   vi /tmp/setup_cluster.sh"
echo ""
echo "2. 赋予执行权限:"
echo "   chmod +x /tmp/setup_cluster.sh"
echo ""
echo "3. 以 root 用户执行:"
echo "   /tmp/setup_cluster.sh"
echo ""
echo "4. 配置完成后，在本地 Mac 运行验证:"
echo "   ./test-gaussdb-single-vm-cluster.sh"
echo ""
