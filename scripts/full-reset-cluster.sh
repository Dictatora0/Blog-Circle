#!/bin/bash

###############################################################
# 完全重置并重启集群
# 确保所有端口配置正确
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
echo "   完全重置集群"
echo "========================================="
echo ""

# 1. 强制停止所有实例
echo "=== 1. 停止所有实例 ==="
pkill -9 gaussdb 2>/dev/null || echo "没有运行的进程"
sleep 3

# 清理所有 socket 和 pid 文件
rm -f /tmp/.s.PGSQL.*
rm -f "$PRIMARY_DATA/postmaster.pid"
rm -f "$STANDBY1_DATA/postmaster.pid"
rm -f "$STANDBY2_DATA/postmaster.pid"

echo -e "${GREEN}✓ 所有实例已停止${NC}"
echo ""

# 2. 确保端口配置正确（只保留一行）
echo "=== 2. 确保端口配置 ==="

fix_port() {
    local data_dir=$1
    local port=$2
    local name=$3
    
    if [ ! -f "$data_dir/postgresql.conf" ]; then
        echo "$name postgresql.conf 不存在"
        return
    fi
    
    # 删除所有端口行
    sed -i '/^port/d' "$data_dir/postgresql.conf"
    sed -i '/^#port/d' "$data_dir/postgresql.conf"
    
    # 添加唯一的端口行
    echo "port = $port" >> "$data_dir/postgresql.conf"
    
    # 清理 auto.conf 中的端口
    if [ -f "$data_dir/postgresql.auto.conf" ]; then
        sed -i '/^port/d' "$data_dir/postgresql.auto.conf"
    fi
    
    echo -e "${GREEN}✓ $name 端口设置为 $port${NC}"
}

fix_port "$PRIMARY_DATA" 5432 "主库"
fix_port "$STANDBY1_DATA" 5433 "备库1"
fix_port "$STANDBY2_DATA" 5434 "备库2"
echo ""

# 3. 启动主库
echo "=== 3. 启动主库 ==="
if su - omm -c "gs_ctl start -D $PRIMARY_DATA -Z single_node -o '-p 5432'"; then
    echo -e "${GREEN}✓ 主库启动成功${NC}"
else
    echo -e "${RED}✗ 主库启动失败${NC}"
    exit 1
fi
sleep 5

# 验证主库端口
PRIMARY_PID=$(ps aux | grep "gaussdb.*data_primary" | grep -v grep | awk '{print $2}')
echo "主库 PID: $PRIMARY_PID"
echo "监听端口:"
lsof -p $PRIMARY_PID 2>/dev/null | grep LISTEN | grep -E "(5432|5433|5434)" || echo "  无法获取端口信息"
echo ""

# 4. 启动备库1
echo "=== 4. 启动备库1 ==="
if su - omm -c "gs_ctl start -D $STANDBY1_DATA -Z single_node -o '-p 5433'"; then
    echo -e "${GREEN}✓ 备库1启动成功${NC}"
else
    echo -e "${RED}✗ 备库1启动失败${NC}"
fi
sleep 5

# 验证备库1端口
STANDBY1_PID=$(ps aux | grep "gaussdb.*data_standby1" | grep -v grep | awk '{print $2}')
echo "备库1 PID: $STANDBY1_PID"
echo "监听端口:"
lsof -p $STANDBY1_PID 2>/dev/null | grep LISTEN | grep -E "(5432|5433|5434)" || echo "  无法获取端口信息"
echo ""

# 5. 启动备库2
echo "=== 5. 启动备库2 ==="
if su - omm -c "gs_ctl start -D $STANDBY2_DATA -Z single_node -o '-p 5434'"; then
    echo -e "${GREEN}✓ 备库2启动成功${NC}"
else
    echo -e "${RED}✗ 备库2启动失败${NC}"
fi
sleep 5

# 验证备库2端口
STANDBY2_PID=$(ps aux | grep "gaussdb.*data_standby2" | grep -v grep | awk '{print $2}')
if [ -n "$STANDBY2_PID" ]; then
    echo "备库2 PID: $STANDBY2_PID"
    echo "监听端口:"
    lsof -p $STANDBY2_PID 2>/dev/null | grep LISTEN | grep -E "(5432|5433|5434)" || echo "  无法获取端口信息"
else
    echo -e "${RED}备库2未启动${NC}"
fi
echo ""

# 6. 最终端口检查
echo "=== 6. 最终端口检查 ==="
echo "端口 5432:"
lsof -i:5432 2>/dev/null | grep LISTEN | awk '{print $1, $2, $9}' || echo "  未占用"
echo ""
echo "端口 5433:"
lsof -i:5433 2>/dev/null | grep LISTEN | awk '{print $1, $2, $9}' || echo "  未占用"
echo ""
echo "端口 5434:"
lsof -i:5434 2>/dev/null | grep LISTEN | awk '{print $1, $2, $9}' || echo "  未占用"
echo ""

# 7. 进程状态
echo "=== 7. 进程状态 ==="
ps aux | grep "gaussdb.*data_" | grep -v grep
echo ""

echo "========================================="
echo -e "${GREEN}   重置完成${NC}"
echo "========================================="
echo ""
echo "运行验证:"
echo "  ./scripts/verify-gaussdb-cluster.sh"
echo ""
