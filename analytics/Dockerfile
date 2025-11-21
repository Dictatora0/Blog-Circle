FROM maven:3.8.7-eclipse-temurin-11 AS builder

WORKDIR /app

# 复制 pom.xml 并下载依赖
COPY pom.xml .
RUN mvn dependency:go-offline -B

# 复制源代码并构建
COPY src ./src
RUN mvn clean package -DskipTests -B

FROM bitnami/spark:3.5.0

USER root

# 安装 PostgreSQL 客户端用于测试连接
RUN apt-get update && \
    apt-get install -y postgresql-client netcat && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 从 builder 复制 JAR
COPY --from=builder /app/target/blog-analytics-*-jar-with-dependencies.jar /app/blog-analytics.jar

# 设置环境变量
ENV GAUSSDB_PRIMARY_HOST=10.211.55.11
ENV GAUSSDB_STANDBY1_HOST=10.211.55.14
ENV GAUSSDB_STANDBY2_HOST=10.211.55.13
ENV GAUSSDB_PORT=5432
ENV GAUSSDB_DATABASE=blog_db
ENV GAUSSDB_USERNAME=bloguser
ENV GAUSSDB_PRIMARY_PASSWORD=747599qw@
ENV GAUSSDB_STANDBY_PASSWORD=747599qw@1

# 切换回 spark 用户
USER 1001

ENTRYPOINT ["spark-submit", \
    "--class", "com.cloudcom.analytics.BlogAnalyticsClusterJob", \
    "--master", "local[*]", \
    "--driver-memory", "1g", \
    "/app/blog-analytics.jar"]
