#!/bin/bash

###############################################################
# GaussDB 配置彻底清理脚本
# 清理重复的端口配置，彻底解决端口冲突
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
echo "   GaussDB 配置彻底清理"
echo "========================================="
echo ""

# 1. 优雅停止所有 GaussDB 进程
echo "=== 1. 停止所有 GaussDB 实例 ==="
echo "停止主库..."
su - omm -c "gs_ctl stop -D $PRIMARY_DATA -m fast" 2>/dev/null || echo "  主库已停止"
echo "停止备库1..."
su - omm -c "gs_ctl stop -D $STANDBY1_DATA -m fast" 2>/dev/null || echo "  备库1已停止"
echo "停止备库2..."
su - omm -c "gs_ctl stop -D $STANDBY2_DATA -m fast" 2>/dev/null || echo "  备库2已停止"

sleep 3

# 检查是否还有残留进程
REMAINING=$(ps aux | grep -E "gaussdb.*(data_primary|data_standby)" | grep -v grep | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo "发现残留进程，强制终止..."
    ps aux | grep -E "gaussdb.*(data_primary|data_standby)" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null || true
    sleep 2
fi

echo -e "${GREEN}✓ 所有实例已停止${NC}"
echo ""

# 2. 清理配置文件
echo "=== 2. 清理配置文件 ==="

# 清理主库配置
if [ -f "$PRIMARY_DATA/postgresql.conf" ]; then
    echo "清理主库配置..."
    # 备份原文件
    cp "$PRIMARY_DATA/postgresql.conf" "$PRIMARY_DATA/postgresql.conf.bak.$(date +%s)"
    # 删除所有 port 行
    sed -i '/^port/d' "$PRIMARY_DATA/postgresql.conf"
    sed -i '/^port /d' "$PRIMARY_DATA/postgresql.conf"
    # 添加唯一的 port 配置
    echo "" >> "$PRIMARY_DATA/postgresql.conf"
    echo "# Port configuration" >> "$PRIMARY_DATA/postgresql.conf"
    echo "port = 5432" >> "$PRIMARY_DATA/postgresql.conf"
    echo -e "${GREEN}✓ 主库配置已清理（端口 5432）${NC}"
fi

# 清理备库1配置
if [ -f "$STANDBY1_DATA/postgresql.conf" ]; then
    echo "清理备库1配置..."
    cp "$STANDBY1_DATA/postgresql.conf" "$STANDBY1_DATA/postgresql.conf.bak.$(date +%s)"
    sed -i '/^port/d' "$STANDBY1_DATA/postgresql.conf"
    sed -i '/^port /d' "$STANDBY1_DATA/postgresql.conf"
    echo "" >> "$STANDBY1_DATA/postgresql.conf"
    echo "# Port configuration" >> "$STANDBY1_DATA/postgresql.conf"
    echo "port = 5433" >> "$STANDBY1_DATA/postgresql.conf"
    echo -e "${GREEN}✓ 备库1配置已清理（端口 5433）${NC}"
fi

# 清理备库2配置
if [ -f "$STANDBY2_DATA/postgresql.conf" ]; then
    echo "清理备库2配置..."
    cp "$STANDBY2_DATA/postgresql.conf" "$STANDBY2_DATA/postgresql.conf.bak.$(date +%s)"
    sed -i '/^port/d' "$STANDBY2_DATA/postgresql.conf"
    sed -i '/^port /d' "$STANDBY2_DATA/postgresql.conf"
    echo "" >> "$STANDBY2_DATA/postgresql.conf"
    echo "# Port configuration" >> "$STANDBY2_DATA/postgresql.conf"
    echo "port = 5434" >> "$STANDBY2_DATA/postgresql.conf"
    echo -e "${GREEN}✓ 备库2配置已清理（端口 5434）${NC}"
fi
echo ""

# 3. 验证配置文件
echo "=== 3. 验证配置文件 ==="
echo "主库端口配置:"
grep "^port" "$PRIMARY_DATA/postgresql.conf" || echo "  未找到端口配置"
echo ""
echo "备库1端口配置:"
grep "^port" "$STANDBY1_DATA/postgresql.conf" || echo "  未找到端口配置"
echo ""
echo "备库2端口配置:"
grep "^port" "$STANDBY2_DATA/postgresql.conf" || echo "  未找到端口配置"
echo ""

# 4. 清理 PID 文件和锁文件
echo "=== 4. 清理 PID 文件和锁文件 ==="
rm -f "$PRIMARY_DATA/postmaster.pid"
rm -f "$STANDBY1_DATA/postmaster.pid"
rm -f "$STANDBY2_DATA/postmaster.pid"
echo -e "${GREEN}✓ PID 文件已清理${NC}"
echo ""

# 5. 启动主库
echo "=== 5. 启动主库 ==="
if su - omm -c "gs_ctl start -D $PRIMARY_DATA" 2>&1 | grep -E "server started|already running"; then
    echo -e "${GREEN}✓ 主库启动成功${NC}"
else
    echo -e "${RED}✗ 主库启动失败${NC}"
    exit 1
fi
sleep 5
echo ""

# 6. 验证主库端口
echo "=== 6. 验证主库端口 ==="
PRIMARY_PID=$(ps aux | grep "gaussdb.*data_primary" | grep -v grep | awk '{print $2}')
if [ -n "$PRIMARY_PID" ]; then
    echo "主库进程 PID: $PRIMARY_PID"
    echo "监听端口:"
    lsof -p $PRIMARY_PID | grep LISTEN || echo "  无法获取端口信息"
else
    echo -e "${RED}✗ 主库进程未找到${NC}"
fi
echo ""

# 7. 启动备库1
echo "=== 7. 启动备库1 ==="
if su - omm -c "gs_ctl start -D $STANDBY1_DATA" 2>&1 | grep -E "server started|already running"; then
    echo -e "${GREEN}✓ 备库1启动成功${NC}"
else
    echo -e "${RED}✗ 备库1启动失败${NC}"
fi
sleep 5
echo ""

# 8. 验证备库1端口
echo "=== 8. 验证备库1端口 ==="
STANDBY1_PID=$(ps aux | grep "gaussdb.*data_standby1" | grep -v grep | awk '{print $2}')
if [ -n "$STANDBY1_PID" ]; then
    echo "备库1进程 PID: $STANDBY1_PID"
    echo "监听端口:"
    lsof -p $STANDBY1_PID | grep LISTEN || echo "  无法获取端口信息"
else
    echo -e "${RED}✗ 备库1进程未找到${NC}"
fi
echo ""

# 9. 启动备库2
echo "=== 9. 启动备库2 ==="
if su - omm -c "gs_ctl start -D $STANDBY2_DATA" 2>&1 | grep -E "server started|already running"; then
    echo -e "${GREEN}✓ 备库2启动成功${NC}"
else
    echo -e "${RED}✗ 备库2启动失败${NC}"
fi
sleep 5
echo ""

# 10. 验证备库2端口
echo "=== 10. 验证备库2端口 ==="
STANDBY2_PID=$(ps aux | grep "gaussdb.*data_standby2" | grep -v grep | awk '{print $2}')
if [ -n "$STANDBY2_PID" ]; then
    echo "备库2进程 PID: $STANDBY2_PID"
    echo "监听端口:"
    lsof -p $STANDBY2_PID | grep LISTEN || echo "  无法获取端口信息"
else
    echo -e "${RED}✗ 备库2进程未找到${NC}"
fi
echo ""

# 11. 最终端口检查
echo "=== 11. 最终端口检查 ==="
echo "端口 5432:"
lsof -i:5432 | grep LISTEN || echo "  未占用"
echo ""
echo "端口 5433:"
lsof -i:5433 | grep LISTEN || echo "  未占用"
echo ""
echo "端口 5434:"
lsof -i:5434 | grep LISTEN || echo "  未占用"
echo ""

echo "========================================="
echo -e "${GREEN}   清理完成${NC}"
echo "========================================="
echo ""
echo "现在运行验证脚本:"
echo "  ./scripts/verify-gaussdb-cluster.sh"
echo ""
