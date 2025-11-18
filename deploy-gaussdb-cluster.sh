#!/bin/bash

# GaussDB 集群完整部署脚本
# 用法: ./deploy-gaussdb-cluster.sh [init|deploy|test|all]

set -e

ACTION=${1:-all}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }

header() {
    echo ""
    echo "========================================="
    echo "   $1"
    echo "========================================="
    echo ""
}

# 初始化 GaussDB
init_gaussdb() {
    header "初始化 GaussDB 集群"
    
    log "将初始化脚本复制到主库..."
    scp "${SCRIPT_DIR}/init-gaussdb-cluster.sh" root@10.211.55.11:/tmp/
    
    log "在主库上执行初始化..."
    ssh root@10.211.55.11 "chmod +x /tmp/init-gaussdb-cluster.sh && /tmp/init-gaussdb-cluster.sh"
    
    ok "GaussDB 集群初始化完成"
}

# 测试连接
test_connection() {
    header "测试 GaussDB 连接"
    
    log "测试主库连接..."
    PGPASSWORD="747599qw@" psql -h 10.211.55.11 -p 5432 -U bloguser -d blog_db -c "SELECT 'PRIMARY OK' as status, version();" || err "主库连接失败"
    
    log "测试备库1连接..."
    PGPASSWORD="747599qw@1" psql -h 10.211.55.14 -p 5432 -U bloguser -d blog_db -c "SELECT 'STANDBY1 OK' as status;" || err "备库1连接失败"
    
    log "测试备库2连接..."
    PGPASSWORD="747599qw@2" psql -h 10.211.55.13 -p 5432 -U bloguser -d blog_db -c "SELECT 'STANDBY2 OK' as status;" || err "备库2连接失败"
    
    ok "所有数据库连接正常"
}

# 部署容器
deploy_containers() {
    header "部署容器服务"
    
    log "停止旧容器..."
    docker-compose -f docker-compose-gaussdb-cluster.yml down || true
    
    log "构建镜像..."
    docker-compose -f docker-compose-gaussdb-cluster.yml build --no-cache
    
    log "启动容器..."
    docker-compose -f docker-compose-gaussdb-cluster.yml up -d
    
    log "等待服务启动..."
    sleep 30
    
    log "检查容器状态..."
    docker-compose -f docker-compose-gaussdb-cluster.yml ps
    
    ok "容器部署完成"
}

# 测试 Spark 作业
test_spark() {
    header "测试 Spark 作业"
    
    log "构建 Spark 作业..."
    cd "${SCRIPT_DIR}/analytics"
    mvn clean package -DskipTests
    cd "${SCRIPT_DIR}"
    
    log "复制 JAR 到 Spark Master..."
    docker cp analytics/target/blog-analytics-1.0.0-jar-with-dependencies.jar \
        blogcircle-spark-master:/opt/bitnami/spark/jars/
    
    log "提交 Spark 作业..."
    docker exec blogcircle-spark-master spark-submit \
        --class com.cloudcom.analytics.BlogAnalyticsClusterJob \
        --master spark://spark-master:7077 \
        --driver-memory 1g \
        --executor-memory 1g \
        --conf spark.driver.extraJavaOptions="-DGAUSSDB_PRIMARY_PASSWORD=747599qw@ -DGAUSSDB_STANDBY_PASSWORD=747599qw@1" \
        --conf spark.executor.extraJavaOptions="-DGAUSSDB_PRIMARY_PASSWORD=747599qw@ -DGAUSSDB_STANDBY_PASSWORD=747599qw@1" \
        /opt/bitnami/spark/jars/blog-analytics-1.0.0-jar-with-dependencies.jar
    
    ok "Spark 作业执行完成"
}

# 显示状态
show_status() {
    header "系统状态"
    
    echo "容器状态:"
    docker-compose -f docker-compose-gaussdb-cluster.yml ps
    
    echo ""
    echo "访问地址:"
    echo "  前端: http://localhost:8082"
    echo "  后端: http://localhost:8081"
    echo "  Spark Master UI: http://localhost:8090"
    echo "  Spark Worker UI: http://localhost:8091"
    
    echo ""
    echo "GaussDB 集群:"
    echo "  主库: 10.211.55.11:5432 (密码: 747599qw@)"
    echo "  备库1: 10.211.55.14:5432 (密码: 747599qw@1)"
    echo "  备库2: 10.211.55.13:5432 (密码: 747599qw@2)"
    
    echo ""
    echo "测试账号:"
    echo "  用户名: admin"
    echo "  密码: admin123"
}

# 主流程
case "$ACTION" in
    init)
        init_gaussdb
        ;;
    test)
        test_connection
        ;;
    deploy)
        deploy_containers
        ;;
    spark)
        test_spark
        ;;
    all)
        init_gaussdb
        test_connection
        deploy_containers
        show_status
        ;;
    status)
        show_status
        ;;
    *)
        err "未知操作: $ACTION"
        echo "用法: $0 [init|test|deploy|spark|all|status]"
        exit 1
        ;;
esac

ok "操作完成"
