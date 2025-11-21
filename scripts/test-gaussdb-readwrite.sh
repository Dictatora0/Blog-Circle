#!/bin/bash

###############################################################
# GaussDB 读写功能测试脚本
# 测试主库写入、备库读取、数据一致性
###############################################################

set -e

PRIMARY_HOST="${1:-127.0.0.1}"
PRIMARY_PORT="${2:-5432}"
REPLICA_PORT="${3:-5434}"
DB_NAME="blog_db"
DB_USER="bloguser"
DB_PASS="747599qw@"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   GaussDB 读写功能测试"
echo "========================================="
echo ""
echo "测试配置:"
echo "  主库: $PRIMARY_HOST:$PRIMARY_PORT"
echo "  备库: $PRIMARY_HOST:$REPLICA_PORT"
echo "  数据库: $DB_NAME"
echo ""

# 1. 测试主库连接
echo "=== 1. 测试主库连接 ==="
if PGPASSWORD=$DB_PASS psql -h $PRIMARY_HOST -p $PRIMARY_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 主库连接成功${NC}"
else
    echo -e "${RED}✗ 主库连接失败${NC}"
    exit 1
fi
echo ""

# 2. 测试备库连接
echo "=== 2. 测试备库连接 ==="
if PGPASSWORD=$DB_PASS psql -h $PRIMARY_HOST -p $REPLICA_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 备库连接成功${NC}"
else
    echo -e "${RED}✗ 备库连接失败${NC}"
    exit 1
fi
echo ""

# 3. 测试主库写入（创建测试表）
echo "=== 3. 测试主库写入 ==="
TEST_TABLE="test_readwrite_$(date +%s)"
if PGPASSWORD=$DB_PASS psql -h $PRIMARY_HOST -p $PRIMARY_PORT -U $DB_USER -d $DB_NAME << EOF > /dev/null 2>&1
CREATE TABLE IF NOT EXISTS $TEST_TABLE (
    id SERIAL PRIMARY KEY,
    data VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO $TEST_TABLE (data) VALUES ('test_data_1'), ('test_data_2'), ('test_data_3');
EOF
then
    echo -e "${GREEN}✓ 主库写入成功${NC}"
else
    echo -e "${RED}✗ 主库写入失败${NC}"
    exit 1
fi
echo ""

# 4. 等待复制同步
echo "=== 4. 等待数据同步 ==="
sleep 3
echo -e "${GREEN}✓ 等待完成${NC}"
echo ""

# 5. 测试备库读取
echo "=== 5. 测试备库读取 ==="
REPLICA_COUNT=$(PGPASSWORD=$DB_PASS psql -h $PRIMARY_HOST -p $REPLICA_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM $TEST_TABLE;" 2>/dev/null | tr -d ' ')
if [ "$REPLICA_COUNT" == "3" ]; then
    echo -e "${GREEN}✓ 备库读取成功，数据已同步 (记录数: $REPLICA_COUNT)${NC}"
else
    echo -e "${YELLOW}⚠ 备库数据未完全同步 (记录数: $REPLICA_COUNT, 期望: 3)${NC}"
fi
echo ""

# 6. 测试数据一致性
echo "=== 6. 测试数据一致性 ==="
PRIMARY_DATA=$(PGPASSWORD=$DB_PASS psql -h $PRIMARY_HOST -p $PRIMARY_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT data FROM $TEST_TABLE ORDER BY id;" 2>/dev/null)
REPLICA_DATA=$(PGPASSWORD=$DB_PASS psql -h $PRIMARY_HOST -p $REPLICA_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT data FROM $TEST_TABLE ORDER BY id;" 2>/dev/null)

if [ "$PRIMARY_DATA" == "$REPLICA_DATA" ]; then
    echo -e "${GREEN}✓ 主备数据一致${NC}"
else
    echo -e "${RED}✗ 主备数据不一致${NC}"
    echo "主库数据: $PRIMARY_DATA"
    echo "备库数据: $REPLICA_DATA"
fi
echo ""

# 7. 测试业务表读写
echo "=== 7. 测试业务表读写 ==="
TEST_USER="test_user_$(date +%s)"
if PGPASSWORD=$DB_PASS psql -h $PRIMARY_HOST -p $PRIMARY_PORT -U $DB_USER -d $DB_NAME << EOF > /dev/null 2>&1
INSERT INTO users (username, password, nickname, email) 
VALUES ('$TEST_USER', '\$2a\$10\$test', 'Test User', 'test@example.com')
ON CONFLICT (username) DO NOTHING;
EOF
then
    echo -e "${GREEN}✓ 业务表写入成功${NC}"
    
    sleep 2
    
    USER_COUNT=$(PGPASSWORD=$DB_PASS psql -h $PRIMARY_HOST -p $REPLICA_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM users WHERE username='$TEST_USER';" 2>/dev/null | tr -d ' ')
    if [ "$USER_COUNT" == "1" ]; then
        echo -e "${GREEN}✓ 业务表数据已同步到备库${NC}"
    else
        echo -e "${YELLOW}⚠ 业务表数据未同步${NC}"
    fi
else
    echo -e "${RED}✗ 业务表写入失败${NC}"
fi
echo ""

# 8. 清理测试数据
echo "=== 8. 清理测试数据 ==="
PGPASSWORD=$DB_PASS psql -h $PRIMARY_HOST -p $PRIMARY_PORT -U $DB_USER -d $DB_NAME -c "DROP TABLE IF EXISTS $TEST_TABLE;" > /dev/null 2>&1
echo -e "${GREEN}✓ 测试数据已清理${NC}"
echo ""

echo "========================================="
echo -e "${GREEN}   读写测试完成${NC}"
echo "========================================="
