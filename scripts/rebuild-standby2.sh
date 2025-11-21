#!/bin/bash

###############################################################
# 重建备库2
# 从主库重新同步数据
###############################################################

set -e

PRIMARY_DATA="/usr/local/opengauss/data_primary"
STANDBY2_DATA="/usr/local/opengauss/data_standby2"
DB_PASSWORD="747599qw@"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   重建备库2"
echo "========================================="
echo ""
echo -e "${YELLOW}[WARN]️  警告: 这将删除备库2的所有数据并从主库重新同步${NC}"
echo ""
read -p "是否继续？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi
echo ""

# 1. 停止备库2
echo "=== 1. 停止备库2 ==="
su - omm -c "gs_ctl stop -D $STANDBY2_DATA -m fast" 2>/dev/null || echo "备库2已停止"
sleep 2
echo -e "${GREEN}[OK] 备库2已停止${NC}"
echo ""

# 2. 备份旧数据
echo "=== 2. 备份旧数据 ==="
if [ -d "$STANDBY2_DATA" ]; then
    BACKUP_DIR="${STANDBY2_DATA}.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$STANDBY2_DATA" "$BACKUP_DIR"
    echo -e "${GREEN}[OK] 旧数据已备份到: $BACKUP_DIR${NC}"
else
    echo "数据目录不存在，跳过备份"
fi
echo ""

# 3. 创建新数据目录
echo "=== 3. 创建数据目录 ==="
mkdir -p "$STANDBY2_DATA"
# 使用 omm:omm 而不是 omm:dbgrp
chown omm:omm "$STANDBY2_DATA"
chmod 700 "$STANDBY2_DATA"
echo -e "${GREEN}[OK] 数据目录已创建${NC}"
echo ""

# 4. 从主库同步数据
echo "=== 4. 从主库同步数据 (gs_basebackup) ==="
echo "这可能需要几分钟..."
if su - omm << EOSU
export PGPASSWORD='$DB_PASSWORD'
gs_basebackup -h 127.0.0.1 -p 5432 -U replicator -D $STANDBY2_DATA -Fp -Xs -P
EOSU
then
    echo -e "${GREEN}[OK] 数据同步完成${NC}"
else
    echo -e "${RED}[FAIL] 数据同步失败${NC}"
    echo ""
    echo "可能的原因:"
    echo "1. 主库未运行"
    echo "2. replicator 用户不存在或密码错误"
    echo "3. pg_hba.conf 未允许复制连接"
    echo ""
    echo "请检查主库配置后重试"
    exit 1
fi
echo ""

# 5. 配置端口
echo "=== 5. 配置备库2端口 ==="
echo "port = 5434" >> "$STANDBY2_DATA/postgresql.conf"
echo -e "${GREEN}[OK] 端口已设置为 5434${NC}"
echo ""

# 6. 配置复制连接
echo "=== 6. 配置复制连接 ==="
cat > "$STANDBY2_DATA/postgresql.auto.conf" << 'EOF'
# Standby configuration
primary_conninfo = 'host=127.0.0.1 port=5432 user=replicator password=747599qw@ application_name=standby2'
primary_slot_name = 'standby2_slot'
hot_standby = on
EOF
chown omm:omm "$STANDBY2_DATA/postgresql.auto.conf"
echo -e "${GREEN}[OK] 复制配置已设置${NC}"
echo ""

# 7. 创建 standby.signal
echo "=== 7. 创建 standby.signal ==="
touch "$STANDBY2_DATA/standby.signal"
chown omm:omm "$STANDBY2_DATA/standby.signal"
echo -e "${GREEN}[OK] standby.signal 已创建${NC}"
echo ""

# 8. 启动备库2
echo "=== 8. 启动备库2 ==="
if su - omm -c "gs_ctl start -D $STANDBY2_DATA -o '-c port=5434'"; then
    echo -e "${GREEN}[OK] 备库2启动成功${NC}"
else
    echo -e "${RED}[FAIL] 备库2启动失败${NC}"
    echo ""
    echo "查看错误日志:"
    echo "  tail -50 $STANDBY2_DATA/pg_log/*.log"
    exit 1
fi
sleep 5
echo ""

# 9. 验证备库2
echo "=== 9. 验证备库2状态 ==="
if su - omm -c "gs_ctl status -D $STANDBY2_DATA" | grep -q "server is running"; then
    echo -e "${GREEN}[OK] 备库2运行正常${NC}"
    
    # 检查是否处于恢复模式
    if su - omm -c "gsql -d postgres -p 5434 -c 'SELECT pg_is_in_recovery();'" 2>/dev/null | grep -q "t"; then
        echo -e "${GREEN}[OK] 备库2处于恢复模式${NC}"
    else
        echo -e "${YELLOW}[WARN] 备库2未处于恢复模式${NC}"
    fi
else
    echo -e "${RED}[FAIL] 备库2未运行${NC}"
fi
echo ""

# 10. 检查主库复制状态
echo "=== 10. 检查主库复制状态 ==="
su - omm -c "gsql -d postgres -p 5432 -c 'SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;'" 2>/dev/null || echo "无法获取复制状态"
echo ""

echo "========================================="
echo -e "${GREEN}   备库2重建完成${NC}"
echo "========================================="
echo ""
echo "下一步:"
echo "  ./scripts/verify-gaussdb-cluster.sh"
echo ""
