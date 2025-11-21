#!/bin/bash

###############################################################
# GaussDB 一主二备集群状态验证脚本
# 验证主备复制状态、读写功能
###############################################################

set -e

PRIMARY_PORT=5432
STANDBY1_PORT=5434
STANDBY2_PORT=5436
DB_NAME="blog_db"
DB_USER="bloguser"
DB_PASS="747599qw@"

# 数据目录（自动检测）
PRIMARY_DATA="/usr/local/opengauss/data_primary"
STANDBY1_DATA="/usr/local/opengauss/data_standby1"
STANDBY2_DATA="/usr/local/opengauss/data_standby2"

# 如果集群目录不存在，使用单实例路径
if [ ! -d "$PRIMARY_DATA" ]; then
    PRIMARY_DATA="/usr/local/opengauss/data"
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   GaussDB 集群状态验证"
echo "========================================="
echo ""

# 1. 检查主库状态
echo "=== 1. 检查主库状态 (端口 $PRIMARY_PORT) ==="
if su - omm -c "gsql -d postgres -p $PRIMARY_PORT -c 'SELECT version();'" 2>/dev/null; then
    echo -e "${GREEN}✓ 主库运行正常${NC}"
else
    echo -e "${RED}✗ 主库无法连接${NC}"
    exit 1
fi
echo ""

# 2. 检查备库1状态
echo "=== 2. 检查备库1状态 (端口 $STANDBY1_PORT) ==="
if [ -d "$STANDBY1_DATA" ]; then
    # 先检查备库是否运行
    if su - omm -c "gs_ctl status -D $STANDBY1_DATA" 2>/dev/null | grep -q "server is running"; then
        # 再检查是否处于恢复模式
        if su - omm -c "gsql -d postgres -p $STANDBY1_PORT -c 'SELECT pg_is_in_recovery();'" 2>/dev/null | grep -q "t"; then
            echo -e "${GREEN}✓ 备库1运行正常（处于恢复模式）${NC}"
        else
            echo -e "${YELLOW}⚠ 备库1运行中但未处于恢复模式${NC}"
        fi
    else
        echo -e "${RED}✗ 备库1未运行${NC}"
        echo "  启动命令: su - omm -c 'gs_ctl start -D $STANDBY1_DATA'"
    fi
else
    echo -e "${YELLOW}⚠ 备库1未配置（单实例模式）${NC}"
fi
echo ""

# 3. 检查备库2状态
echo "=== 3. 检查备库2状态 (端口 $STANDBY2_PORT) ==="
if [ -d "$STANDBY2_DATA" ]; then
    # 先检查备库是否运行
    if su - omm -c "gs_ctl status -D $STANDBY2_DATA" 2>/dev/null | grep -q "server is running"; then
        # 再检查是否处于恢复模式
        if su - omm -c "gsql -d postgres -p $STANDBY2_PORT -c 'SELECT pg_is_in_recovery();'" 2>/dev/null | grep -q "t"; then
            echo -e "${GREEN}✓ 备库2运行正常（处于恢复模式）${NC}"
        else
            echo -e "${YELLOW}⚠ 备库2运行中但未处于恢复模式${NC}"
        fi
    else
        echo -e "${RED}✗ 备库2未运行${NC}"
        echo "  启动命令: su - omm -c 'gs_ctl start -D $STANDBY2_DATA'"
    fi
else
    echo -e "${YELLOW}⚠ 备库2未配置（单实例模式）${NC}"
fi
echo ""

# 4. 检查主库复制状态
echo "=== 4. 检查主库复制状态 ==="
REPL_STATUS=$(su - omm -c "gsql -d postgres -p $PRIMARY_PORT -t -c \"SELECT application_name, state, sync_state FROM pg_stat_replication;\"" 2>/dev/null)
if echo "$REPL_STATUS" | grep -q "standby1"; then
    echo -e "${GREEN}✓ 备库1已连接到主库${NC}"
else
    echo -e "${YELLOW}⚠ 备库1未连接到主库${NC}"
fi

if echo "$REPL_STATUS" | grep -q "standby2"; then
    echo -e "${GREEN}✓ 备库2已连接到主库${NC}"
else
    echo -e "${YELLOW}⚠ 备库2未连接到主库${NC}"
fi
echo ""

# 5. 测试主库写入
echo "=== 5. 测试主库写入 ==="
TEST_TIME=$(date +%s)
if su - omm -c "gsql -d $DB_NAME -p $PRIMARY_PORT -c \"INSERT INTO users (username, password, nickname, email) VALUES ('test_$TEST_TIME', 'test', 'Test User', 'test@test.com') ON CONFLICT (username) DO NOTHING;\"" 2>/dev/null; then
    echo -e "${GREEN}✓ 主库写入成功${NC}"
else
    echo -e "${RED}✗ 主库写入失败${NC}"
    exit 1
fi
echo ""

# 6. 等待复制同步
echo "=== 6. 等待数据同步到备库 ==="
sleep 2
echo -e "${GREEN}✓ 等待完成${NC}"
echo ""

# 7. 测试备库1读取
echo "=== 7. 测试备库1读取 ==="
if su - omm -c "gsql -d $DB_NAME -p $STANDBY1_PORT -c \"SELECT COUNT(*) FROM users WHERE username='test_$TEST_TIME';\"" 2>/dev/null | grep -q "1"; then
    echo -e "${GREEN}✓ 备库1读取成功，数据已同步${NC}"
else
    echo -e "${YELLOW}⚠ 备库1数据未同步或读取失败${NC}"
fi
echo ""

# 8. 测试备库2读取
echo "=== 8. 测试备库2读取 ==="
if su - omm -c "gsql -d $DB_NAME -p $STANDBY2_PORT -c \"SELECT COUNT(*) FROM users WHERE username='test_$TEST_TIME';\"" 2>/dev/null | grep -q "1"; then
    echo -e "${GREEN}✓ 备库2读取成功，数据已同步${NC}"
else
    echo -e "${YELLOW}⚠ 备库2数据未同步或读取失败${NC}"
fi
echo ""

# 9. 显示复制延迟
echo "=== 9. 复制延迟统计 ==="
su - omm -c "gsql -d postgres -p $PRIMARY_PORT -c \"SELECT application_name, client_addr, state, sync_state, write_lag, flush_lag, replay_lag FROM pg_stat_replication;\"" 2>/dev/null || echo "无法获取复制延迟信息"
echo ""

echo "========================================="
echo -e "${GREEN}   集群验证完成${NC}"
echo "========================================="
echo ""
echo "集群信息："
echo "  主库: 127.0.0.1:$PRIMARY_PORT"
echo "  备库1: 127.0.0.1:$STANDBY1_PORT"
echo "  备库2: 127.0.0.1:$STANDBY2_PORT"
echo "  数据库: $DB_NAME"
echo ""
