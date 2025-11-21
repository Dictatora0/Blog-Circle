#!/bin/bash

###############################################################
# GaussDB 端口诊断脚本
# 检查并修复端口配置问题
###############################################################

set -e

PRIMARY_DATA="/usr/local/opengauss/data_primary"
STANDBY1_DATA="/usr/local/opengauss/data_standby1"
STANDBY2_DATA="/usr/local/opengauss/data_standby2"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "   GaussDB 端口诊断"
echo "========================================="
echo ""

# 1. 检查当前运行的 GaussDB 进程及其端口
echo "=== 1. 当前运行的 GaussDB 进程 ==="
ps aux | grep gaussdb | grep -v grep || echo "无 GaussDB 进程"
echo ""

# 2. 检查端口占用情况
echo "=== 2. 端口占用情况 ==="
echo "端口 5432 (应为主库):"
lsof -i:5432 | grep LISTEN || echo "  未占用"
echo ""
echo "端口 5433 (应为备库1):"
lsof -i:5433 | grep LISTEN || echo "  未占用"
echo ""
echo "端口 5434 (应为备库2):"
lsof -i:5434 | grep LISTEN || echo "  未占用"
echo ""

# 3. 检查配置文件中的端口设置
echo "=== 3. 配置文件端口设置 ==="
if [ -f "$PRIMARY_DATA/postgresql.conf" ]; then
    PRIMARY_PORT=$(grep "^port" "$PRIMARY_DATA/postgresql.conf" | awk '{print $3}' || echo "未设置")
    echo "主库配置端口: $PRIMARY_PORT"
else
    echo "主库配置文件不存在"
fi

if [ -f "$STANDBY1_DATA/postgresql.conf" ]; then
    STANDBY1_PORT=$(grep "^port" "$STANDBY1_DATA/postgresql.conf" | awk '{print $3}' || echo "未设置")
    echo "备库1配置端口: $STANDBY1_PORT"
else
    echo "备库1配置文件不存在"
fi

if [ -f "$STANDBY2_DATA/postgresql.conf" ]; then
    STANDBY2_PORT=$(grep "^port" "$STANDBY2_DATA/postgresql.conf" | awk '{print $3}' || echo "未设置")
    echo "备库2配置端口: $STANDBY2_PORT"
else
    echo "备库2配置文件不存在"
fi
echo ""

# 4. 分析问题
echo "=== 4. 问题诊断 ==="
ISSUES=0

# 检查主库端口
if [ -f "$PRIMARY_DATA/postgresql.conf" ]; then
    if [ "$PRIMARY_PORT" != "5432" ]; then
        echo -e "${RED}[FAIL] 主库端口配置错误: $PRIMARY_PORT (应为 5432)${NC}"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}[OK] 主库端口配置正确: $PRIMARY_PORT${NC}"
    fi
fi

# 检查备库1端口
if [ -f "$STANDBY1_DATA/postgresql.conf" ]; then
    if [ "$STANDBY1_PORT" != "5433" ]; then
        echo -e "${RED}[FAIL] 备库1端口配置错误: $STANDBY1_PORT (应为 5433)${NC}"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}[OK] 备库1端口配置正确: $STANDBY1_PORT${NC}"
    fi
fi

# 检查备库2端口
if [ -f "$STANDBY2_DATA/postgresql.conf" ]; then
    if [ "$STANDBY2_PORT" != "5434" ]; then
        echo -e "${RED}[FAIL] 备库2端口配置错误: $STANDBY2_PORT (应为 5434)${NC}"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${GREEN}[OK] 备库2端口配置正确: $STANDBY2_PORT${NC}"
    fi
fi
echo ""

# 5. 提供修复建议
if [ $ISSUES -gt 0 ]; then
    echo "=== 5. 修复建议 ==="
    echo ""
    echo "步骤1: 停止所有 GaussDB 实例"
    echo "  su - omm -c 'gs_ctl stop -D $PRIMARY_DATA'"
    echo "  su - omm -c 'gs_ctl stop -D $STANDBY1_DATA'"
    echo "  su - omm -c 'gs_ctl stop -D $STANDBY2_DATA'"
    echo ""
    echo "步骤2: 修复端口配置"
    
    if [ "$PRIMARY_PORT" != "5432" ]; then
        echo "  修复主库: sed -i 's/^port = .*/port = 5432/' $PRIMARY_DATA/postgresql.conf"
    fi
    
    if [ "$STANDBY1_PORT" != "5433" ]; then
        echo "  修复备库1: sed -i 's/^port = .*/port = 5433/' $STANDBY1_DATA/postgresql.conf"
    fi
    
    if [ "$STANDBY2_PORT" != "5434" ]; then
        echo "  修复备库2: sed -i 's/^port = .*/port = 5434/' $STANDBY2_DATA/postgresql.conf"
    fi
    
    echo ""
    echo "步骤3: 重新启动实例"
    echo "  su - omm -c 'gs_ctl start -D $PRIMARY_DATA'"
    echo "  su - omm -c 'gs_ctl start -D $STANDBY1_DATA'"
    echo "  su - omm -c 'gs_ctl start -D $STANDBY2_DATA'"
    echo ""
    echo "或执行自动修复脚本:"
    echo "  ./scripts/fix-gaussdb-ports.sh"
else
    echo -e "${GREEN}=== 端口配置正确 ===${NC}"
    echo ""
    echo "如果仍有问题，请检查："
    echo "1. 主备复制配置 (postgresql.auto.conf, standby.signal)"
    echo "2. 复制用户权限"
    echo "3. pg_hba.conf 配置"
fi
echo ""

echo "========================================="
echo "   诊断完成"
echo "========================================="
