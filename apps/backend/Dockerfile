FROM maven:3.8.7-eclipse-temurin-17 AS builder

# 配置 Maven 使用阿里云镜像（加速依赖下载）
COPY .m2/settings.xml /root/.m2/settings.xml

WORKDIR /app

# 复制 pom.xml 并下载依赖（添加重试机制）
COPY pom.xml .
RUN mvn dependency:go-offline -B -Dmaven.test.skip=true || \
    (echo "首次下载失败，重试..." && sleep 5 && mvn dependency:go-offline -B -Dmaven.test.skip=true) || \
    (echo "第二次下载失败，再次重试..." && sleep 10 && mvn dependency:go-offline -B -Dmaven.test.skip=true)

# 复制源代码并构建
COPY src ./src
RUN mvn clean package -Dmaven.test.skip=true -B || \
    (echo "构建失败，重试..." && sleep 5 && mvn clean package -Dmaven.test.skip=true -B)

FROM eclipse-temurin:17-jre

WORKDIR /app

# 安装 curl 用于 healthcheck
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/*.jar app.jar

RUN mkdir -p /app/uploads

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]

