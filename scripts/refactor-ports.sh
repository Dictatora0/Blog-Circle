#!/bin/bash

###############################################################
# GaussDB 端口重构脚本
# 使用间隔更大的端口避免 HA 端口冲突
# 主库: 5432, 备库1: 5434, 备库2: 5436
###############################################################

set -e

PRIMARY_DATA="/usr/local/opengauss/data_primary"
STANDBY1_DATA="/usr/local/opengauss/data_standby1"
STANDBY2_DATA="/usr/local/opengauss/data_standby2"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   GaussDB 端口重构"
echo "========================================="
echo ""

# 1. 停止所有实例
echo "=== 1. 停止所有实例 ==="
pkill -9 gaussdb 2>/dev/null || echo "没有运行的进程"
sleep 3
rm -f /tmp/.s.PGSQL.*
rm -f "$PRIMARY_DATA/postmaster.pid"
rm -f "$STANDBY1_DATA/postmaster.pid"
rm -f "$STANDBY2_DATA/postmaster.pid"
echo -e "${GREEN}✓ 所有实例已停止${NC}"
echo ""

# 2. 修改端口配置
echo "=== 2. 修改端口配置 ==="

configure_port() {
    local data_dir=$1
    local port=$2
    local name=$3
    
    if [ ! -f "$data_dir/postgresql.conf" ]; then
        echo "$name 配置文件不存在"
        return
    fi
    
    # 删除所有端口行
    sed -i '/^port/d' "$data_dir/postgresql.conf"
    sed -i '/^#port/d' "$data_dir/postgresql.conf"
    
    # 添加新端口
    echo "port = $port" >> "$data_dir/postgresql.conf"
    
    # 清理 auto.conf
    if [ -f "$data_dir/postgresql.auto.conf" ]; then
        sed -i '/^port/d' "$data_dir/postgresql.auto.conf"
    fi
    
    echo -e "${GREEN}✓ $name 端口设置为 $port${NC}"
}

configure_port "$PRIMARY_DATA" 5432 "主库"
configure_port "$STANDBY1_DATA" 5434 "备库1"
configure_port "$STANDBY2_DATA" 5436 "备库2"
echo ""

# 3. 启动主库
echo "=== 3. 启动主库 (5432) ==="
if su - omm -c "gs_ctl start -D $PRIMARY_DATA -Z single_node -o '-p 5432'"; then
    echo -e "${GREEN}✓ 主库启动成功${NC}"
else
    echo -e "${RED}✗ 主库启动失败${NC}"
    exit 1
fi
sleep 5

# 4. 启动备库1
echo "=== 4. 启动备库1 (5434) ==="
if su - omm -c "gs_ctl start -D $STANDBY1_DATA -Z single_node -o '-p 5434'"; then
    echo -e "${GREEN}✓ 备库1启动成功${NC}"
else
    echo -e "${RED}✗ 备库1启动失败${NC}"
fi
sleep 5

# 5. 启动备库2
echo "=== 5. 启动备库2 (5436) ==="
if su - omm -c "gs_ctl start -D $STANDBY2_DATA -Z single_node -o '-p 5436'"; then
    echo -e "${GREEN}✓ 备库2启动成功${NC}"
else
    echo -e "${RED}✗ 备库2启动失败${NC}"
fi
sleep 5

# 6. 验证端口
echo "=== 6. 验证端口 ==="
lsof -i:5432 2>/dev/null | grep LISTEN && echo "主库 OK"
lsof -i:5434 2>/dev/null | grep LISTEN && echo "备库1 OK"
lsof -i:5436 2>/dev/null | grep LISTEN && echo "备库2 OK"
echo ""

echo "========================================="
echo -e "${GREEN}   重构完成${NC}"
echo "========================================="
