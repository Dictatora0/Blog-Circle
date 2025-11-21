#!/bin/bash

###############################################################
# 虚拟机集群性能测试脚本
# 测试并发性能、响应时间、连接池使用
###############################################################

set -e

BASE_URL="${1:-http://10.211.55.11:8080}"
CONCURRENT_USERS="${2:-50}"
REQUESTS_PER_USER="${3:-20}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "   虚拟机集群性能测试"
echo "========================================="
echo ""
echo "测试配置:"
echo "  目标地址: $BASE_URL"
echo "  并发用户: $CONCURRENT_USERS"
echo "  每用户请求数: $REQUESTS_PER_USER"
echo "  总请求数: $((CONCURRENT_USERS * REQUESTS_PER_USER))"
echo ""

# 检查必要工具
command -v curl >/dev/null 2>&1 || { echo "需要安装 curl"; exit 1; }

# 1. 响应时间测试
echo "=== 1. API 响应时间测试 ==="
echo "测试接口: GET /api/posts/list"

RESPONSE_TIMES=()
for i in $(seq 1 100); do
    START=$(date +%s%3N)
    curl -s -o /dev/null "$BASE_URL/api/posts/list"
    END=$(date +%s%3N)
    ELAPSED=$((END - START))
    RESPONSE_TIMES+=($ELAPSED)
    [ $((i % 20)) -eq 0 ] && echo -n "."
done
echo ""

# 计算统计值
IFS=$'\n' SORTED=($(sort -n <<<"${RESPONSE_TIMES[*]}"))
unset IFS

SUM=0
for TIME in "${RESPONSE_TIMES[@]}"; do
    SUM=$((SUM + TIME))
done
AVG=$((SUM / 100))

P50=${SORTED[49]}
P90=${SORTED[89]}
P95=${SORTED[94]}
P99=${SORTED[98]}
MIN=${SORTED[0]}
MAX=${SORTED[99]}

echo ""
echo -e "${BLUE}响应时间统计 (100次请求):${NC}"
echo "  平均值: ${AVG}ms"
echo "  中位数 (P50): ${P50}ms"
echo "  P90: ${P90}ms"
echo "  P95: ${P95}ms"
echo "  P99: ${P99}ms"
echo "  最小值: ${MIN}ms"
echo "  最大值: ${MAX}ms"

if [ $AVG -lt 200 ] && [ $P95 -lt 300 ]; then
    echo -e "${GREEN}[OK] 响应时间符合要求${NC}"
else
    echo -e "${YELLOW}[WARN] 响应时间较高${NC}"
fi
echo ""

# 2. 并发测试
echo "=== 2. 并发性能测试 ==="
echo "使用 curl 模拟并发请求..."

TEMP_DIR=$(mktemp -d)
SUCCESS_COUNT=0
FAILED_COUNT=0
START_TIME=$(date +%s)

# 并发执行请求
for i in $(seq 1 $CONCURRENT_USERS); do
    {
        for j in $(seq 1 $REQUESTS_PER_USER); do
            if curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/posts/list" | grep -q "200"; then
                echo "1" >> "$TEMP_DIR/success_${i}.txt"
            else
                echo "1" >> "$TEMP_DIR/failed_${i}.txt"
            fi
        done
    } &
done

# 等待所有并发任务完成
wait

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

# 统计结果
SUCCESS_COUNT=$(find "$TEMP_DIR" -name "success_*.txt" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
FAILED_COUNT=$(find "$TEMP_DIR" -name "failed_*.txt" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
[ -z "$SUCCESS_COUNT" ] && SUCCESS_COUNT=0
[ -z "$FAILED_COUNT" ] && FAILED_COUNT=0

TOTAL_REQUESTS=$((SUCCESS_COUNT + FAILED_COUNT))
QPS=$((TOTAL_REQUESTS / TOTAL_TIME))
SUCCESS_RATE=$(echo "scale=2; $SUCCESS_COUNT * 100 / $TOTAL_REQUESTS" | bc)

rm -rf "$TEMP_DIR"

echo ""
echo -e "${BLUE}并发测试结果:${NC}"
echo "  总请求数: $TOTAL_REQUESTS"
echo "  成功请求: $SUCCESS_COUNT"
echo "  失败请求: $FAILED_COUNT"
echo "  成功率: ${SUCCESS_RATE}%"
echo "  总耗时: ${TOTAL_TIME}s"
echo "  平均 QPS: ${QPS}"

if [ $FAILED_COUNT -eq 0 ] && [ $QPS -gt 50 ]; then
    echo -e "${GREEN}[OK] 并发测试通过${NC}"
else
    echo -e "${YELLOW}[WARN] 并发性能需要优化${NC}"
fi
echo ""

# 3. 数据库连接池监控
echo "=== 3. 数据库连接池监控 ==="
echo "检查虚拟机数据库连接数..."

if command -v sshpass >/dev/null 2>&1 || [ -f "/opt/homebrew/bin/sshpass" ]; then
    SSHPASS_CMD="sshpass"
    [ -f "/opt/homebrew/bin/sshpass" ] && SSHPASS_CMD="/opt/homebrew/bin/sshpass"
    
    PRIMARY_CONN=$($SSHPASS_CMD -p "747599qw@" ssh -o StrictHostKeyChecking=no root@10.211.55.11 \
        "su - omm -c \"gsql -d blog_db -p 5432 -t -c 'SELECT count(*) FROM pg_stat_activity WHERE datname='\''blog_db'\'';'\" 2>/dev/null" | tr -d ' ')
    
    REPLICA_CONN=$($SSHPASS_CMD -p "747599qw@" ssh -o StrictHostKeyChecking=no root@10.211.55.11 \
        "su - omm -c \"gsql -d blog_db -p 5434 -t -c 'SELECT count(*) FROM pg_stat_activity WHERE datname='\''blog_db'\'';'\" 2>/dev/null" | tr -d ' ')
    
    echo "  主库连接数: ${PRIMARY_CONN:-N/A}"
    echo "  备库连接数: ${REPLICA_CONN:-N/A}"
    
    if [ -n "$PRIMARY_CONN" ] && [ -n "$REPLICA_CONN" ]; then
        if [ $REPLICA_CONN -gt $PRIMARY_CONN ]; then
            echo -e "${GREEN}[OK] 读操作正确路由到备库${NC}"
        else
            echo -e "${YELLOW}[WARN] 读写分离路由可能未生效${NC}"
        fi
    fi
else
    echo -e "${YELLOW}[SKIP] 未安装 sshpass，跳过连接池检查${NC}"
fi
echo ""

# 4. 系统资源监控
echo "=== 4. 系统资源使用 ==="
if command -v sshpass >/dev/null 2>&1 || [ -f "/opt/homebrew/bin/sshpass" ]; then
    echo "检查虚拟机资源使用..."
    
    CPU_USAGE=$($SSHPASS_CMD -p "747599qw@" ssh -o StrictHostKeyChecking=no root@10.211.55.11 \
        "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1" 2>/dev/null)
    
    MEM_USAGE=$($SSHPASS_CMD -p "747599qw@" ssh -o StrictHostKeyChecking=no root@10.211.55.11 \
        "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100}'" 2>/dev/null)
    
    echo "  CPU 使用率: ${CPU_USAGE:-N/A}%"
    echo "  内存使用率: ${MEM_USAGE:-N/A}%"
    
    if [ -n "$CPU_USAGE" ]; then
        CPU_INT=${CPU_USAGE%.*}
        if [ "$CPU_INT" -lt 80 ]; then
            echo -e "${GREEN}[OK] CPU 使用率正常${NC}"
        else
            echo -e "${YELLOW}[WARN] CPU 使用率较高${NC}"
        fi
    fi
else
    echo -e "${YELLOW}[SKIP] 跳过资源监控${NC}"
fi
echo ""

echo "========================================="
echo -e "${GREEN}   性能测试完成${NC}"
echo "========================================="
echo ""
echo "性能总结:"
echo "  ✓ 平均响应时间: ${AVG}ms"
echo "  ✓ P95 响应时间: ${P95}ms"
echo "  ✓ 并发 QPS: ${QPS}"
echo "  ✓ 成功率: ${SUCCESS_RATE}%"
echo ""
