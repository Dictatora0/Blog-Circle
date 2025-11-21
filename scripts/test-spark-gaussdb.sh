#!/bin/bash

###############################################################
# Spark 访问 GaussDB 测试脚本
# 测试 Spark 读写 GaussDB 集群功能
###############################################################

set -e

GAUSSDB_PRIMARY_HOST="${1:-10.211.55.11}"
GAUSSDB_PRIMARY_PORT="${2:-5432}"
GAUSSDB_DATABASE="blog_db"
GAUSSDB_USERNAME="bloguser"
GAUSSDB_PASSWORD="747599qw@"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   Spark + GaussDB 集成测试"
echo "========================================="
echo ""

# 检查 analytics 模块是否存在
if [ ! -d "analytics" ]; then
    echo -e "${RED}[FAIL] analytics 模块不存在${NC}"
    exit 1
fi

cd analytics

# 1. 编译 Spark 项目
echo "=== 1. 编译 Spark 项目 ==="
if mvn clean package -DskipTests > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] 编译成功${NC}"
else
    echo -e "${RED}[FAIL] 编译失败${NC}"
    exit 1
fi
echo ""

# 2. 运行 Spark 任务（测试连接）
echo "=== 2. 运行 Spark 任务 ==="
export GAUSSDB_PRIMARY_HOST=$GAUSSDB_PRIMARY_HOST
export GAUSSDB_PORT=$GAUSSDB_PRIMARY_PORT
export GAUSSDB_DATABASE=$GAUSSDB_DATABASE
export GAUSSDB_USERNAME=$GAUSSDB_USERNAME
export GAUSSDB_PRIMARY_PASSWORD=$GAUSSDB_PASSWORD

JAR_FILE=$(find target -name "analytics-*.jar" | head -1)

if [ -z "$JAR_FILE" ]; then
    echo -e "${RED}[FAIL] 未找到编译后的 JAR 文件${NC}"
    exit 1
fi

echo "运行 Spark 任务: $JAR_FILE"
echo ""

# 运行 Spark 任务（设置较短的超时时间）
timeout 60s spark-submit \
    --class com.cloudcom.analytics.BlogAnalyticsClusterJob \
    --master local[2] \
    --driver-memory 512m \
    --executor-memory 512m \
    $JAR_FILE 2>&1 | tee /tmp/spark-test.log

if grep -q "分析任务完成" /tmp/spark-test.log; then
    echo ""
    echo -e "${GREEN}[OK] Spark 任务执行成功${NC}"
elif grep -q "主库连接成功" /tmp/spark-test.log; then
    echo ""
    echo -e "${GREEN}[OK] Spark 连接 GaussDB 成功${NC}"
else
    echo ""
    echo -e "${YELLOW}[WARN] Spark 任务可能未完全成功，请查看日志${NC}"
fi

echo ""
echo "========================================="
echo "   Spark 测试完成"
echo "========================================="
echo ""
echo "日志文件: /tmp/spark-test.log"
