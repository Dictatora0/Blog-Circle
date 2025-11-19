#!/bin/bash

# GaussDB/PostgreSQL 流复制配置脚本
# 此脚本生成配置命令，需要在 VM 上执行

set -e

PRIMARY_IP="10.211.55.11"
STANDBY1_IP="10.211.55.14"
STANDBY2_IP="10.211.55.13"
DB_PORT="5432"
REPL_USER="replicator"
REPL_PASSWORD="747599qw@"

DOCKER_CMD="/usr/local/bin/docker"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }

header() {
    echo ""
    echo "========================================="
    echo "   $1"
    echo "========================================="
    echo ""
}

# 执行 SQL
run_sql() {
    local host="$1"
    local sql="$2"
    local user="${3:-bloguser}"
    local password="${4:-747599qw@}"
    
    $DOCKER_CMD run --rm -e PGPASSWORD="${password}" postgres:15-alpine \
        psql -h "${host}" -p "${DB_PORT}" -U "${user}" -d postgres \
        -c "${sql}" 2>&1
}

header "GaussDB/PostgreSQL 流复制配置"

# 步骤 1: 在主库创建复制用户
log "步骤 1: 在主库创建复制用户..."
CREATE_USER=$(run_sql "${PRIMARY_IP}" "CREATE USER ${REPL_USER} WITH REPLICATION ENCRYPTED PASSWORD '${REPL_PASSWORD}';" 2>&1)

if echo "$CREATE_USER" | grep -q "already exists"; then
    ok "复制用户已存在"
elif echo "$CREATE_USER" | grep -q "CREATE ROLE"; then
    ok "复制用户创建成功"
else
    warn "创建用户结果: $CREATE_USER"
fi

# 步骤 2: 检查主库配置
log "步骤 2: 检查主库配置..."
echo ""
run_sql "${PRIMARY_IP}" "SELECT name, setting FROM pg_settings WHERE name IN ('wal_level', 'max_wal_senders', 'wal_keep_size', 'hot_standby', 'max_replication_slots');"
echo ""

# 步骤 3: 检查 pg_hba.conf 是否允许复制连接
log "步骤 3: 需要在主库的 pg_hba.conf 添加以下配置:"
echo ""
echo "# 允许复制连接"
echo "host    replication     ${REPL_USER}     ${STANDBY1_IP}/32       md5"
echo "host    replication     ${REPL_USER}     ${STANDBY2_IP}/32       md5"
echo ""

# 步骤 4: 生成备库配置
header "备库配置"

log "需要在备库上创建/修改以下文件:"
echo ""
echo "=== 备库1 (${STANDBY1_IP}) ==="
echo "文件: /var/lib/postgresql/data/postgresql.auto.conf 或 postgresql.conf"
echo ""
cat << 'EOF'
# 流复制配置
primary_conninfo = 'host=10.211.55.11 port=5432 user=replicator password=747599qw@ application_name=standby1'
primary_slot_name = 'standby1_slot'  # 可选
hot_standby = on
EOF

echo ""
echo "文件: /var/lib/postgresql/data/standby.signal"
echo "(创建空文件即可，表示这是备库)"
echo ""

echo "=== 备库2 (${STANDBY2_IP}) ==="
echo "文件: /var/lib/postgresql/data/postgresql.auto.conf 或 postgresql.conf"
echo ""
cat << 'EOF'
# 流复制配置
primary_conninfo = 'host=10.211.55.11 port=5432 user=replicator password=747599qw@ application_name=standby2'
primary_slot_name = 'standby2_slot'  # 可选
hot_standby = on
EOF

echo ""
echo "文件: /var/lib/postgresql/data/standby.signal"
echo "(创建空文件即可，表示这是备库)"
echo ""

# 步骤 5: 生成 VM 上的执行命令
header "在 VM 上执行以下命令"

cat << 'VMEOF'
# ===== 在主库 VM (10.211.55.11) 上执行 =====

# 1. 编辑 pg_hba.conf
sudo -u postgres vi /var/lib/postgresql/data/pg_hba.conf
# 添加以下两行:
# host    replication     replicator     10.211.55.14/32       md5
# host    replication     replicator     10.211.55.13/32       md5

# 2. 重新加载配置
sudo -u postgres psql -c "SELECT pg_reload_conf();"

# 3. 创建复制槽（可选但推荐）
sudo -u postgres psql -c "SELECT pg_create_physical_replication_slot('standby1_slot');"
sudo -u postgres psql -c "SELECT pg_create_physical_replication_slot('standby2_slot');"


# ===== 在备库1 VM (10.211.55.14) 上执行 =====

# 1. 停止 PostgreSQL
sudo systemctl stop postgresql

# 2. 备份现有数据（可选）
sudo mv /var/lib/postgresql/data /var/lib/postgresql/data.backup

# 3. 从主库同步数据
sudo -u postgres pg_basebackup -h 10.211.55.11 -p 5432 -U replicator -D /var/lib/postgresql/data -Fp -Xs -P -R

# 4. 创建 standby.signal
sudo -u postgres touch /var/lib/postgresql/data/standby.signal

# 5. 配置 primary_conninfo（pg_basebackup -R 会自动创建）
# 如果没有自动创建，手动添加到 postgresql.auto.conf:
# primary_conninfo = 'host=10.211.55.11 port=5432 user=replicator password=747599qw@ application_name=standby1'

# 6. 启动 PostgreSQL
sudo systemctl start postgresql


# ===== 在备库2 VM (10.211.55.13) 上执行 =====

# 1. 停止 PostgreSQL
sudo systemctl stop postgresql

# 2. 备份现有数据（可选）
sudo mv /var/lib/postgresql/data /var/lib/postgresql/data.backup

# 3. 从主库同步数据
sudo -u postgres pg_basebackup -h 10.211.55.11 -p 5432 -U replicator -D /var/lib/postgresql/data -Fp -Xs -P -R

# 4. 创建 standby.signal
sudo -u postgres touch /var/lib/postgresql/data/standby.signal

# 5. 配置 primary_conninfo（pg_basebackup -R 会自动创建）
# 如果没有自动创建，手动添加到 postgresql.auto.conf:
# primary_conninfo = 'host=10.211.55.11 port=5432 user=replicator password=747599qw@ application_name=standby2'

# 6. 启动 PostgreSQL
sudo systemctl start postgresql

VMEOF

echo ""
warn "注意: 以上命令需要在各个 VM 上手动执行"
warn "如果 VM 使用 Docker 容器运行 PostgreSQL，命令会有所不同"
echo ""

# 步骤 6: 提供验证命令
header "验证复制配置"

echo "执行以下命令验证复制是否成功:"
echo ""
echo "# 在本地 Mac 上运行:"
echo "./test-gaussdb-cluster.sh"
echo ""
echo "# 或手动检查:"
echo "docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \\"
echo "  psql -h 10.211.55.11 -p 5432 -U bloguser -d postgres \\"
echo "  -c 'SELECT * FROM pg_stat_replication;'"
echo ""
