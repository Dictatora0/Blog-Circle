#!/bin/bash

###############################################################
# 检查备库2启动失败的详细原因
###############################################################

set -e

STANDBY2_DATA="/usr/local/opengauss/data_standby2"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   备库2诊断"
echo "========================================="
echo ""

# 1. 检查数据目录
echo "=== 1. 检查数据目录 ==="
if [ -d "$STANDBY2_DATA" ]; then
    echo -e "${GREEN}✓ 数据目录存在${NC}"
    ls -lh "$STANDBY2_DATA" | head -20
else
    echo -e "${RED}✗ 数据目录不存在${NC}"
    exit 1
fi
echo ""

# 2. 检查关键文件
echo "=== 2. 检查关键文件 ==="
echo "检查 standby.signal:"
if [ -f "$STANDBY2_DATA/standby.signal" ]; then
    echo -e "${GREEN}✓ standby.signal 存在${NC}"
else
    echo -e "${RED}✗ standby.signal 不存在 (备库必需)${NC}"
fi

echo ""
echo "检查 postgresql.auto.conf:"
if [ -f "$STANDBY2_DATA/postgresql.auto.conf" ]; then
    echo -e "${GREEN}✓ postgresql.auto.conf 存在${NC}"
    cat "$STANDBY2_DATA/postgresql.auto.conf"
else
    echo -e "${YELLOW}⚠ postgresql.auto.conf 不存在${NC}"
fi

echo ""
echo "检查 recovery.conf (旧版):"
if [ -f "$STANDBY2_DATA/recovery.conf" ]; then
    echo -e "${YELLOW}⚠ 发现 recovery.conf (旧版配置)${NC}"
    cat "$STANDBY2_DATA/recovery.conf"
fi
echo ""

# 3. 查看最新的错误日志
echo "=== 3. 最新错误日志 (最后50行) ==="
LOG_DIR="$STANDBY2_DATA/pg_log"
if [ -d "$LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "日志文件: $LATEST_LOG"
        echo "----------------------------------------"
        tail -50 "$LATEST_LOG"
    else
        echo "没有找到日志文件"
    fi
else
    echo "日志目录不存在"
fi
echo ""

# 4. 检查端口配置
echo "=== 4. 端口配置 ==="
if [ -f "$STANDBY2_DATA/postgresql.conf" ]; then
    echo "postgresql.conf 中的端口:"
    grep "^port" "$STANDBY2_DATA/postgresql.conf"
else
    echo "postgresql.conf 不存在"
fi
echo ""

# 5. 检查权限
echo "=== 5. 文件权限 ==="
ls -ld "$STANDBY2_DATA"
ls -l "$STANDBY2_DATA" | grep -E "(postgresql.conf|standby.signal|postmaster)"
echo ""

# 6. 检查磁盘空间
echo "=== 6. 磁盘空间 ==="
df -h "$STANDBY2_DATA"
echo ""

echo "========================================="
echo "   诊断完成"
echo "========================================="
