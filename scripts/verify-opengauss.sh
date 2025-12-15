#!/bin/bash

# 验证 openGauss 集群状态
# 使用方法：在虚拟机上执行 ./verify-opengauss.sh

set -e

echo "=========================================="
echo "  openGauss 集群状态验证"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 检查容器状态
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. 检查容器运行状态"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker ps --filter "name=opengauss" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 2. 检查主库连接
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. 检查主库 (opengauss-primary) 连接"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker exec opengauss-primary bash -c 'su - omm -c "gsql -d blog_db -c \"SELECT version();\" "' 2>/dev/null | grep -q "openGauss"; then
    echo -e "${GREEN}✓ 主库连接正常${NC}"
    docker exec opengauss-primary bash -c 'su - omm -c "gsql -d blog_db -c \"SELECT version();\" "' | head -3
else
    echo -e "${RED}✗ 主库连接失败${NC}"
fi
echo ""

# 3. 检查主库复制状态
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. 检查主库复制槽位"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
REPLICATION_STATUS=$(docker exec opengauss-primary bash -c 'su - omm -c "gsql -d blog_db -t -c \"SELECT application_name, state, sync_state FROM pg_stat_replication;\" "' 2>/dev/null || echo "")
if [ -z "$REPLICATION_STATUS" ] || [ "$REPLICATION_STATUS" == "(0 rows)" ]; then
    echo -e "${YELLOW}⚠ 主库没有配置复制关系${NC}"
    echo "说明：当前三个容器是独立的 openGauss 实例，不是主备复制集群"
else
    echo -e "${GREEN}✓ 主库复制状态：${NC}"
    echo "$REPLICATION_STATUS"
fi
echo ""

# 4. 检查备库1
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. 检查备库1 (opengauss-standby1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker exec opengauss-standby1 bash -c 'su - omm -c "gsql -d blog_db -c \"SELECT version();\" "' 2>/dev/null | grep -q "openGauss"; then
    echo -e "${GREEN}✓ 备库1连接正常${NC}"
    # 检查是否在恢复模式
    IS_RECOVERY=$(docker exec opengauss-standby1 bash -c 'su - omm -c "gsql -d blog_db -t -c \"SELECT pg_is_in_recovery();\" "' 2>/dev/null | tr -d ' ')
    if [ "$IS_RECOVERY" == "t" ]; then
        echo -e "${GREEN}✓ 备库1处于恢复模式（从库）${NC}"
    else
        echo -e "${YELLOW}⚠ 备库1不在恢复模式（独立实例）${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 备库1连接失败或未正确初始化${NC}"
fi
echo ""

# 5. 检查备库2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. 检查备库2 (opengauss-standby2)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker exec opengauss-standby2 bash -c 'su - omm -c "gsql -d blog_db -c \"SELECT version();\" "' 2>/dev/null | grep -q "openGauss"; then
    echo -e "${GREEN}✓ 备库2连接正常${NC}"
    # 检查是否在恢复模式
    IS_RECOVERY=$(docker exec opengauss-standby2 bash -c 'su - omm -c "gsql -d blog_db -t -c \"SELECT pg_is_in_recovery();\" "' 2>/dev/null | tr -d ' ')
    if [ "$IS_RECOVERY" == "t" ]; then
        echo -e "${GREEN}✓ 备库2处于恢复模式（从库）${NC}"
    else
        echo -e "${YELLOW}⚠ 备库2不在恢复模式（独立实例）${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 备库2连接失败或未正确初始化${NC}"
fi
echo ""

# 6. 检查数据库和表
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. 检查数据库表结构"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "主库中的表："
docker exec opengauss-primary bash -c 'su - omm -c "gsql -d blog_db -c \"\\dt\" "' 2>/dev/null | grep -E "users|posts|comments" || echo "  未找到应用表（可能尚未初始化）"
echo ""

# 7. 检查用户权限
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. 检查 bloguser 用户"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
USER_EXISTS=$(docker exec opengauss-primary bash -c 'su - omm -c "gsql -d blog_db -t -c \"SELECT 1 FROM pg_user WHERE usename='\''bloguser'\'';\" "' 2>/dev/null | tr -d ' ')
if [ "$USER_EXISTS" == "1" ]; then
    echo -e "${GREEN}✓ bloguser 用户存在${NC}"
else
    echo -e "${YELLOW}⚠ bloguser 用户不存在${NC}"
fi
echo ""

# 8. 总结
echo "=========================================="
echo "  验证总结"
echo "=========================================="
echo ""
echo -e "${YELLOW}当前配置说明：${NC}"
echo "• 三个 openGauss 容器正在运行"
echo "• 但它们是独立的数据库实例，不是主备复制集群"
echo "• 应用目前只连接到 opengauss-primary (主库)"
echo "• 如需配置真正的主备复制，需要额外的初始化脚本"
echo ""
echo -e "${GREEN}建议操作：${NC}"
echo "• 使用 opengauss-primary 作为主数据库"
echo "• 备库可以暂时不使用，或配置为独立的测试/开发环境"
echo ""
