#!/bin/bash

###############################################################
# GaussDB 端口完全重置脚本
# 清理所有可能的端口配置源
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
echo "   GaussDB 端口完全重置"
echo "========================================="
echo ""

# 1. 强制停止所有进程
echo "=== 1. 强制停止所有 GaussDB 进程 ==="
ps aux | grep -E "gaussdb.*(data_primary|data_standby)" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null || echo "没有运行的进程"
sleep 3
echo -e "${GREEN}[OK] 所有进程已终止${NC}"
echo ""

# 2. 清理所有配置文件
echo "=== 2. 清理所有端口配置 ==="

clean_port_config() {
    local data_dir=$1
    local port=$2
    local name=$3
    
    echo "清理 $name..."
    
    # 清理 postgresql.conf
    if [ -f "$data_dir/postgresql.conf" ]; then
        # 备份
        cp "$data_dir/postgresql.conf" "$data_dir/postgresql.conf.bak.$(date +%s)"
        # 删除所有端口相关配置
        sed -i '/^port/d' "$data_dir/postgresql.conf"
        sed -i '/^port /d' "$data_dir/postgresql.conf"
        sed -i '/^#port/d' "$data_dir/postgresql.conf"
        # 添加新配置
        echo "" >> "$data_dir/postgresql.conf"
        echo "# Port Configuration - Reset $(date)" >> "$data_dir/postgresql.conf"
        echo "port = $port" >> "$data_dir/postgresql.conf"
    fi
    
    # 清理 postgresql.auto.conf
    if [ -f "$data_dir/postgresql.auto.conf" ]; then
        cp "$data_dir/postgresql.auto.conf" "$data_dir/postgresql.auto.conf.bak.$(date +%s)"
        sed -i '/port/d' "$data_dir/postgresql.auto.conf"
        echo "# Auto configuration - Port reset" >> "$data_dir/postgresql.auto.conf"
    fi
    
    # 清理 PID 和 socket 文件
    rm -f "$data_dir/postmaster.pid"
    rm -f "$data_dir/postmaster.opts"
    rm -f "/tmp/.s.PGSQL.$port"
    rm -f "/tmp/.s.PGSQL.$port.lock"
    
    echo -e "${GREEN}[OK] $name 配置已清理 (端口 $port)${NC}"
}

clean_port_config "$PRIMARY_DATA" 5432 "主库"
clean_port_config "$STANDBY1_DATA" 5433 "备库1"
clean_port_config "$STANDBY2_DATA" 5434 "备库2"
echo ""

# 3. 清理所有 socket 文件
echo "=== 3. 清理 socket 文件 ==="
rm -f /tmp/.s.PGSQL.*
echo -e "${GREEN}[OK] Socket 文件已清理${NC}"
echo ""

# 4. 验证配置
echo "=== 4. 验证配置文件 ==="
echo "主库 postgresql.conf:"
grep "^port" "$PRIMARY_DATA/postgresql.conf"
echo ""
echo "备库1 postgresql.conf:"
grep "^port" "$STANDBY1_DATA/postgresql.conf"
echo ""
echo "备库2 postgresql.conf:"
grep "^port" "$STANDBY2_DATA/postgresql.conf"
echo ""

# 5. 检查 auto.conf
echo "=== 5. 检查 auto.conf 文件 ==="
if grep -q "port" "$PRIMARY_DATA/postgresql.auto.conf" 2>/dev/null; then
    echo -e "${YELLOW}[WARN] 主库 auto.conf 包含端口配置${NC}"
    grep "port" "$PRIMARY_DATA/postgresql.auto.conf"
fi
if grep -q "port" "$STANDBY1_DATA/postgresql.auto.conf" 2>/dev/null; then
    echo -e "${YELLOW}[WARN] 备库1 auto.conf 包含端口配置${NC}"
    grep "port" "$STANDBY1_DATA/postgresql.auto.conf"
fi
if grep -q "port" "$STANDBY2_DATA/postgresql.auto.conf" 2>/dev/null; then
    echo -e "${YELLOW}[WARN] 备库2 auto.conf 包含端口配置${NC}"
    grep "port" "$STANDBY2_DATA/postgresql.auto.conf"
fi
echo ""

# 6. 启动主库
echo "=== 6. 启动主库 (端口 5432) ==="
su - omm -c "gs_ctl start -D $PRIMARY_DATA -o '-c port=5432'" 2>&1 | grep -E "started|failed|error" || true
sleep 5

PRIMARY_PID=$(ps aux | grep "gaussdb.*data_primary" | grep -v grep | awk '{print $2}')
if [ -n "$PRIMARY_PID" ]; then
    echo -e "${GREEN}[OK] 主库已启动 (PID: $PRIMARY_PID)${NC}"
    echo "主库监听端口:"
    lsof -p $PRIMARY_PID 2>/dev/null | grep LISTEN
else
    echo -e "${RED}[FAIL] 主库启动失败${NC}"
    exit 1
fi
echo ""

# 7. 启动备库1
echo "=== 7. 启动备库1 (端口 5433) ==="
su - omm -c "gs_ctl start -D $STANDBY1_DATA -o '-c port=5433'" 2>&1 | grep -E "started|failed|error" || true
sleep 5

STANDBY1_PID=$(ps aux | grep "gaussdb.*data_standby1" | grep -v grep | awk '{print $2}')
if [ -n "$STANDBY1_PID" ]; then
    echo -e "${GREEN}[OK] 备库1已启动 (PID: $STANDBY1_PID)${NC}"
    echo "备库1监听端口:"
    lsof -p $STANDBY1_PID 2>/dev/null | grep LISTEN
else
    echo -e "${RED}[FAIL] 备库1启动失败${NC}"
fi
echo ""

# 8. 启动备库2
echo "=== 8. 启动备库2 (端口 5434) ==="
su - omm -c "gs_ctl start -D $STANDBY2_DATA -o '-c port=5434'" 2>&1 | grep -E "started|failed|error" || true
sleep 5

STANDBY2_PID=$(ps aux | grep "gaussdb.*data_standby2" | grep -v grep | awk '{print $2}')
if [ -n "$STANDBY2_PID" ]; then
    echo -e "${GREEN}[OK] 备库2已启动 (PID: $STANDBY2_PID)${NC}"
    echo "备库2监听端口:"
    lsof -p $STANDBY2_PID 2>/dev/null | grep LISTEN
else
    echo -e "${RED}[FAIL] 备库2启动失败${NC}"
fi
echo ""

# 9. 最终验证
echo "=== 9. 最终端口验证 ==="
echo "端口 5432 (主库):"
lsof -i:5432 2>/dev/null | grep LISTEN || echo "  未监听"
echo ""
echo "端口 5433 (备库1):"
lsof -i:5433 2>/dev/null | grep LISTEN || echo "  未监听"
echo ""
echo "端口 5434 (备库2):"
lsof -i:5434 2>/dev/null | grep LISTEN || echo "  未监听"
echo ""

echo "========================================="
echo -e "${GREEN}   重置完成${NC}"
echo "========================================="
echo ""
echo "下一步:"
echo "  ./scripts/verify-gaussdb-cluster.sh"
echo ""
