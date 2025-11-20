#!/bin/bash

###############################################################
# 后端服务启动脚本
# 支持本地开发和生产环境
###############################################################

set -e

MODE="${1:-dev}"
PORT="${2:-8080}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   启动后端服务"
echo "========================================="
echo ""
echo "模式: $MODE"
echo "端口: $PORT"
echo ""

cd backend

# 1. 检查 Maven
if ! command -v mvn &> /dev/null; then
    echo -e "${RED}✗ 未找到 Maven，请先安装${NC}"
    exit 1
fi

# 2. 编译项目
echo "=== 编译项目 ==="
if mvn clean package -Dmaven.test.skip=true > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 编译成功${NC}"
else
    echo -e "${RED}✗ 编译失败${NC}"
    exit 1
fi
echo ""

# 3. 查找 JAR 文件
JAR_FILE=$(find target -name "*.jar" -not -name "*-sources.jar" | head -1)
if [ -z "$JAR_FILE" ]; then
    echo -e "${RED}✗ 未找到编译后的 JAR 文件${NC}"
    exit 1
fi

echo "JAR 文件: $JAR_FILE"
echo ""

# 4. 设置环境变量
export SERVER_PORT=$PORT

if [ "$MODE" == "prod" ] || [ "$MODE" == "gaussdb-cluster" ]; then
    export SPRING_PROFILES_ACTIVE=gaussdb-cluster
    echo "使用配置: application-gaussdb-cluster.yml"
else
    export SPRING_PROFILES_ACTIVE=dev
    echo "使用配置: application.yml"
fi
echo ""

# 5. 启动服务
echo "=== 启动服务 ==="
echo "访问地址: http://localhost:$PORT"
echo "健康检查: http://localhost:$PORT/actuator/health"
echo ""
echo "按 Ctrl+C 停止服务"
echo ""

java -jar \
    -Dserver.port=$PORT \
    -Dspring.profiles.active=$SPRING_PROFILES_ACTIVE \
    $JAR_FILE
