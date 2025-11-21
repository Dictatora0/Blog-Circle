#!/bin/bash

###############################################################
# 修复主库复制配置
# 确保主库允许备库连接进行复制
###############################################################

set -e

PRIMARY_DATA="/usr/local/opengauss/data_primary"
DB_PASSWORD="747599qw@"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   修复主库复制配置"
echo "========================================="
echo ""

# 1. 检查主库状态
echo "=== 1. 检查主库状态 ==="
if ! su - omm -c "gs_ctl status -D $PRIMARY_DATA" | grep -q "server is running"; then
    echo -e "${RED}✗ 主库未运行${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 主库运行正常${NC}"
echo ""

# 2. 检查复制用户
echo "=== 2. 检查复制用户 ==="
REPL_USER=$(su - omm -c "gsql -d postgres -p 5432 -t -c \"SELECT rolname FROM pg_roles WHERE rolname='replicator';\"" 2>/dev/null | tr -d ' ')
if [ "$REPL_USER" == "replicator" ]; then
    echo -e "${GREEN}✓ replicator 用户存在${NC}"
else
    echo -e "${YELLOW}⚠ replicator 用户不存在，正在创建...${NC}"
    su - omm -c "gsql -d postgres -p 5432 -c \"CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '$DB_PASSWORD';\"" 2>&1
    echo -e "${GREEN}✓ replicator 用户已创建${NC}"
fi
echo ""

# 3. 检查复制槽
echo "=== 3. 检查复制槽 ==="
echo "现有复制槽:"
su - omm -c "gsql -d postgres -p 5432 -c \"SELECT slot_name, slot_type, active FROM pg_replication_slots;\"" 2>/dev/null || echo "无法查询复制槽"

# 创建缺失的复制槽 (GaussDB 可能不支持，跳过)
echo -e "${YELLOW}⚠ GaussDB 可能不需要预创建复制槽，跳过${NC}"
echo ""

# 4. 检查 pg_hba.conf
echo "=== 4. 检查 pg_hba.conf ==="
if grep -q "host.*replication.*replicator" "$PRIMARY_DATA/pg_hba.conf"; then
    echo -e "${GREEN}✓ pg_hba.conf 包含复制规则${NC}"
else
    echo -e "${YELLOW}⚠ 添加复制规则到 pg_hba.conf...${NC}"
    
    # 备份
    cp "$PRIMARY_DATA/pg_hba.conf" "$PRIMARY_DATA/pg_hba.conf.bak.$(date +%s)"
    
    # 添加复制规则
    cat >> "$PRIMARY_DATA/pg_hba.conf" << 'EOF'

# Replication connections
host    replication     replicator     127.0.0.1/32          md5
host    replication     replicator     ::1/128               md5
host    replication     all            0.0.0.0/0             md5
EOF
    
    echo -e "${GREEN}✓ 复制规则已添加${NC}"
    
    # 重新加载配置
    echo "重新加载配置..."
    su - omm -c "gs_ctl reload -D $PRIMARY_DATA"
    sleep 2
fi
echo ""

# 5. 检查主库复制参数
echo "=== 5. 检查主库复制参数 ==="
su - omm -c "gsql -d postgres -p 5432 -c \"SHOW wal_level; SHOW max_wal_senders; SHOW max_replication_slots;\"" 2>/dev/null || echo "无法查询参数"
echo ""

# 6. 重置 replicator 密码（确保正确）
echo "=== 6. 重置 replicator 密码 ==="
echo "重置 replicator 用户密码..."
su - omm -c "gsql -d postgres -p 5432 -c \"ALTER USER replicator WITH PASSWORD '$DB_PASSWORD';\"" 2>&1
echo -e "${GREEN}✓ 密码已重置${NC}"
echo ""

# 7. 显示当前复制状态
echo "=== 7. 当前复制状态 ==="
su - omm -c "gsql -d postgres -p 5432 -c \"SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;\"" 2>/dev/null || echo "暂无备库连接"
echo ""

echo "========================================="
echo -e "${GREEN}   主库配置检查完成${NC}"
echo "========================================="
echo ""
echo "下一步:"
echo "1. 如果所有检查都通过，重建备库2:"
echo "   ./scripts/rebuild-standby2.sh"
echo ""
echo "2. 如果有错误，请根据提示修复后重试"
echo ""
