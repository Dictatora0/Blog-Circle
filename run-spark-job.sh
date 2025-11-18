#!/bin/bash

# Spark 作业提交脚本
# 用法: ./run-spark-job.sh [local|cluster]

set -e

MODE=${1:-local}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JAR_FILE="${SCRIPT_DIR}/analytics/target/blog-analytics-1.0.0-jar-with-dependencies.jar"

# GaussDB 集群配置
export GAUSSDB_PRIMARY_HOST="10.211.55.11"
export GAUSSDB_STANDBY1_HOST="10.211.55.14"
export GAUSSDB_STANDBY2_HOST="10.211.55.13"
export GAUSSDB_PORT="5432"
export GAUSSDB_DATABASE="blog_db"
export GAUSSDB_USERNAME="bloguser"
export GAUSSDB_PRIMARY_PASSWORD="747599qw@"
export GAUSSDB_STANDBY_PASSWORD="747599qw@1"

echo "========================================="
echo "   Spark 作业提交"
echo "========================================="
echo ""

# 检查 JAR 文件
if [ ! -f "$JAR_FILE" ]; then
    echo "错误: 未找到 JAR 文件: $JAR_FILE"
    echo "请先构建项目: cd analytics && mvn clean package"
    exit 1
fi

if [ "$MODE" = "local" ]; then
    echo "模式: 本地运行"
    echo ""
    
    spark-submit \
        --class com.cloudcom.analytics.BlogAnalyticsClusterJob \
        --master local[*] \
        --driver-memory 1g \
        --executor-memory 1g \
        --conf spark.sql.adaptive.enabled=true \
        --conf spark.driver.extraJavaOptions="-Dlog4j.configuration=file:${SCRIPT_DIR}/analytics/src/main/resources/log4j.properties" \
        "$JAR_FILE"
        
elif [ "$MODE" = "cluster" ]; then
    echo "模式: 集群运行"
    echo "Spark Master: spark://spark-master:7077"
    echo ""
    
    # 复制 JAR 到容器
    echo "复制 JAR 文件到 Spark Master..."
    docker cp "${JAR_FILE}" blogcircle-spark-master:/tmp/blog-analytics.jar
    
    docker exec blogcircle-spark-master /opt/spark/bin/spark-submit \
        --class com.cloudcom.analytics.BlogAnalyticsClusterJob \
        --master spark://spark-master:7077 \
        --driver-memory 1g \
        --executor-memory 1g \
        --total-executor-cores 2 \
        --conf spark.sql.adaptive.enabled=true \
        --conf spark.driver.extraJavaOptions="-DGAUSSDB_PRIMARY_HOST=${GAUSSDB_PRIMARY_HOST} -DGAUSSDB_STANDBY1_HOST=${GAUSSDB_STANDBY1_HOST} -DGAUSSDB_STANDBY2_HOST=${GAUSSDB_STANDBY2_HOST} -DGAUSSDB_PRIMARY_PASSWORD=${GAUSSDB_PRIMARY_PASSWORD} -DGAUSSDB_STANDBY_PASSWORD=${GAUSSDB_STANDBY_PASSWORD}" \
        --conf spark.executor.extraJavaOptions="-DGAUSSDB_PRIMARY_HOST=${GAUSSDB_PRIMARY_HOST} -DGAUSSDB_STANDBY1_HOST=${GAUSSDB_STANDBY1_HOST} -DGAUSSDB_STANDBY2_HOST=${GAUSSDB_STANDBY2_HOST} -DGAUSSDB_PRIMARY_PASSWORD=${GAUSSDB_PRIMARY_PASSWORD} -DGAUSSDB_STANDBY_PASSWORD=${GAUSSDB_STANDBY_PASSWORD}" \
        /tmp/blog-analytics.jar
else
    echo "错误: 未知模式 '$MODE'"
    echo "用法: $0 [local|cluster]"
    exit 1
fi

echo ""
echo "========================================="
echo "   作业提交完成"
echo "========================================="
