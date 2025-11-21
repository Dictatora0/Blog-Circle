#!/bin/bash

###############################################################
# GaussDB 端口自动修复脚本
# 修复端口配置并重启服务
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
echo "   GaussDB 端口自动修复"
echo "========================================="
echo ""

# 1. 停止所有实例
echo "=== 1. 停止所有 GaussDB 实例 ==="
echo "停止主库..."
su - omm -c "gs_ctl stop -D $PRIMARY_DATA" 2>/dev/null || echo "  主库已停止或未运行"

echo "停止备库1..."
su - omm -c "gs_ctl stop -D $STANDBY1_DATA" 2>/dev/null || echo "  备库1已停止或未运行"

echo "停止备库2..."
su - omm -c "gs_ctl stop -D $STANDBY2_DATA" 2>/dev/null || echo "  备库2已停止或未运行"

sleep 3
echo -e "${GREEN}✓ 所有实例已停止${NC}"
echo ""

# 2. 修复端口配置
echo "=== 2. 修复端口配置 ==="

# 修复主库端口
if [ -f "$PRIMARY_DATA/postgresql.conf" ]; then
    echo "修复主库端口为 5432..."
    # 先删除旧的端口配置
    sed -i '/^port/d' "$PRIMARY_DATA/postgresql.conf"
    # 添加新的端口配置
    echo "port = 5432" >> "$PRIMARY_DATA/postgresql.conf"
    echo -e "${GREEN}✓ 主库端口已设置为 5432${NC}"
fi

# 修复备库1端口
if [ -f "$STANDBY1_DATA/postgresql.conf" ]; then
    echo "修复备库1端口为 5433..."
    sed -i '/^port/d' "$STANDBY1_DATA/postgresql.conf"
    echo "port = 5433" >> "$STANDBY1_DATA/postgresql.conf"
    echo -e "${GREEN}✓ 备库1端口已设置为 5433${NC}"
fi

# 修复备库2端口
if [ -f "$STANDBY2_DATA/postgresql.conf" ]; then
    echo "修复备库2端口为 5434..."
    sed -i '/^port/d' "$STANDBY2_DATA/postgresql.conf"
    echo "port = 5434" >> "$STANDBY2_DATA/postgresql.conf"
    echo -e "${GREEN}✓ 备库2端口已设置为 5434${NC}"
fi
echo ""

# 3. 启动主库
echo "=== 3. 启动主库 ==="
if su - omm -c "gs_ctl start -D $PRIMARY_DATA" 2>&1 | tee /tmp/primary_start.log; then
    echo -e "${GREEN}✓ 主库启动成功${NC}"
else
    echo -e "${RED}✗ 主库启动失败${NC}"
    cat /tmp/primary_start.log
    exit 1
fi
sleep 3
echo ""

# 4. 验证主库
echo "=== 4. 验证主库 ==="
if su - omm -c "gsql -d postgres -p 5432 -c 'SELECT version();'" 2>/dev/null | grep -q "openGauss"; then
    echo -e "${GREEN}✓ 主库验证成功${NC}"
else
    echo -e "${RED}✗ 主库验证失败${NC}"
    exit 1
fi
echo ""

# 5. 启动备库1
echo "=== 5. 启动备库1 ==="
if su - omm -c "gs_ctl start -D $STANDBY1_DATA" 2>&1 | tee /tmp/standby1_start.log; then
    echo -e "${GREEN}✓ 备库1启动成功${NC}"
else
    echo -e "${RED}✗ 备库1启动失败${NC}"
    cat /tmp/standby1_start.log
fi
sleep 3
echo ""

# 6. 启动备库2
echo "=== 6. 启动备库2 ==="
if su - omm -c "gs_ctl start -D $STANDBY2_DATA" 2>&1 | tee /tmp/standby2_start.log; then
    echo -e "${GREEN}✓ 备库2启动成功${NC}"
else
    echo -e "${RED}✗ 备库2启动失败${NC}"
    cat /tmp/standby2_start.log
fi
sleep 3
echo ""

# 7. 验证端口
echo "=== 7. 验证端口占用 ==="
echo "端口 5432 (主库):"
lsof -i:5432 | grep LISTEN || echo "  未监听"
echo ""
echo "端口 5433 (备库1):"
lsof -i:5433 | grep LISTEN || echo "  未监听"
echo ""
echo "端口 5434 (备库2):"
lsof -i:5434 | grep LISTEN || echo "  未监听"
echo ""

# 8. 检查服务状态
echo "=== 8. 检查服务状态 ==="
echo "主库状态:"
su - omm -c "gs_ctl status -D $PRIMARY_DATA" 2>/dev/null || echo "  主库未运行"
echo ""
echo "备库1状态:"
su - omm -c "gs_ctl status -D $STANDBY1_DATA" 2>/dev/null || echo "  备库1未运行"
echo ""
echo "备库2状态:"
su - omm -c "gs_ctl status -D $STANDBY2_DATA" 2>/dev/null || echo "  备库2未运行"
echo ""

echo "========================================="
echo -e "${GREEN}   修复完成${NC}"
echo "========================================="
echo ""
echo "下一步:"
echo "1. 运行验证脚本: ./scripts/verify-gaussdb-cluster.sh"
echo "2. 如果备库未处于恢复模式，需要重新配置主备复制"
echo ""
