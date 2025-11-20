# Blog Circle 完整部署指南

本指南涵盖 Blog Circle 系统的完整部署，包括 PostgreSQL/GaussDB、后端、前端、Spark 分析等组件。

## 目录

1. [快速开始](#快速开始)
2. [本地开发环境](#本地开发环境)
3. [GaussDB 部署](#gaussdb-部署)
4. [Docker Compose 部署](#docker-compose-部署)
5. [Spark 分析模块](#spark-分析模块)
6. [故障排查](#故障排查)

---

## 快速开始

### 最简单的方式：本地开发

```bash
# 1. 启动本地开发环境（PostgreSQL + Spring Boot + Vite）
./docker-compose-start.sh dev

# 2. 访问应用
# 前端: http://localhost:5173
# 后端: http://localhost:8080

# 3. 停止服务
./docker-compose-stop.sh dev
```

### 完整容器化部署（PostgreSQL）

```bash
# 启动所有服务（前端、后端、PostgreSQL）
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 完整容器化部署（GaussDB + Spark）

```bash
# 启动所有服务（前端、后端、GaussDB、Spark）
docker-compose -f docker-compose-gaussdb.yml up -d

# 查看日志
docker-compose -f docker-compose-gaussdb.yml logs -f

# 停止服务
docker-compose -f docker-compose-gaussdb.yml down

# 或使用一键脚本（推荐）
./start-gaussdb-cluster.sh        # 清理旧卷 + 启动 1 主 2 备集群
./start-standby-and-verify.sh     # 快速验证容器、Spark、复制状态
```

---

## 本地开发环境

### 前置条件

- Java 17+
- Maven 3.6+
- Node.js 18+
- PostgreSQL 14+ 或 GaussDB

### 安装步骤

#### 1. 安装依赖

**macOS**

```bash
# 安装 Java 17
brew install openjdk@17

# 安装 Maven
brew install maven

# 安装 Node.js
brew install node

# 安装 PostgreSQL
brew install postgresql@14
brew services start postgresql@14
```

**Linux (Ubuntu/Debian)**

```bash
# 安装 Java 17
sudo apt-get install openjdk-17-jdk

# 安装 Maven
sudo apt-get install maven

# 安装 Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 安装 PostgreSQL
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql
```

#### 2. 初始化数据库

```bash
# 创建数据库
createdb blog_db

# 初始化表结构
psql -U your_username -d blog_db -f backend/src/main/resources/db/01_init.sql
```

#### 3. 配置后端

编辑 `backend/src/main/resources/application.yml`：

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/blog_db
    username: your_username
    password: your_password
```

#### 4. 启动后端

```bash
cd backend
mvn spring-boot:run
```

后端将在 `http://localhost:8080` 启动。

#### 5. 启动前端

```bash
cd frontend
npm install
npm run dev
```

前端将在 `http://localhost:5173` 启动。

---

## GaussDB 部署

### 前置条件

- Docker Desktop / Docker Compose 2.x（本地集群）
- 或 openEuler + openGauss 9.2.4（远程 VM 10.211.55.11）
- 至少 4GB 内存 + 10GB 磁盘

### 使用 Docker 部署 GaussDB（本地一主二备）

```bash
# 直接使用脚本，内部会调用 docker-compose-gaussdb-pseudo.yml
./start-gaussdb-cluster.sh

# 查看状态
docker compose -f docker-compose-gaussdb-pseudo.yml ps

# 手动方式（不推荐，仅供排障参考）
docker compose -f docker-compose-gaussdb-pseudo.yml up -d gaussdb-primary gaussdb-standby1 gaussdb-standby2
```

### 远程 VM（10.211.55.11）部署

```bash
# 初始化脚本
scp setup-gaussdb-single-vm-cluster.sh root@10.211.55.11:/tmp/
ssh root@10.211.55.11 "bash /tmp/setup-gaussdb-single-vm-cluster.sh"

# 启动/停止
su - omm -c "gs_ctl start -D /usr/local/opengauss/data_primary -M primary"
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_primary"
```

### 连接 GaussDB

#### 使用 gsql 客户端

```bash
gsql -h localhost -p 5432 -U bloguser -d blog_db
```

#### 使用 Java 应用

配置 `application-gaussdb.yml`：

```yaml
spring:
  profiles:
    active: gaussdb
  datasource:
    driver-class-name: org.opengauss.Driver
    url: jdbc:opengauss://localhost:5432/blog_db
    username: bloguser
    password: blogpass
```

启动后端：

```bash
cd backend
mvn spring-boot:run --spring.profiles.active=gaussdb
```

或通过环境变量：

```bash
export SPRING_PROFILES_ACTIVE=gaussdb
export GAUSSDB_JDBC_URL=jdbc:opengauss://localhost:5432/blog_db
export GAUSSDB_USERNAME=bloguser
export GAUSSDB_PASSWORD=blogpass

mvn spring-boot:run
```

---

## Docker Compose 部署

### 标准部署（PostgreSQL）

```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f backend
docker-compose logs -f frontend

# 停止服务
docker-compose down

# 完全清理（包括数据卷）
docker-compose down -v
```

**访问地址**

- 前端: http://localhost:8080
- 后端: http://localhost:8081
- 数据库: localhost:5432

### GaussDB + Spark 部署

```bash
# 启动所有服务
docker-compose -f docker-compose-gaussdb.yml up -d

# 或者使用 start-gaussdb-cluster.sh + run-spark-job.sh

# 查看服务状态
docker-compose -f docker-compose-gaussdb.yml ps

# 查看日志（包含 Spark）
docker-compose -f docker-compose-gaussdb.yml logs -f backend
docker-compose -f docker-compose-gaussdb.yml logs -f spark-master

# 停止服务
docker-compose -f docker-compose-gaussdb.yml down
```

**Spark 镜像拉取问题**：

如果遇到 `failed to resolve reference "docker.io/apache/spark:3.5.0"` 错误，请参考 [SPARK_SETUP_GUIDE.md](./SPARK_SETUP_GUIDE.md) 中的解决方案。

快速解决方案：

```bash
# 方案 1：配置 Docker 镜像源（推荐）
# 编辑 /etc/docker/daemon.json，添加国内镜像源

# 方案 2：手动拉取镜像
docker pull apache/spark:3.5.0

# 方案 3：使用轻量级配置（不含 Spark）
docker-compose -f docker-compose-gaussdb-lite.yml up -d

# 方案 4：本地运行 Spark
cd analytics
mvn clean package
spark-submit --class com.cloudcom.analytics.BlogAnalyticsJob ...
```

### 连接现有 GaussDB 集群（不含 Spark）

若宿主环境已有 GaussDB 主库（如 VM 10.211.55.11 的 1 主 2 备集群），可以跳过容器化数据库：

```bash
export GAUSSDB_HOST=10.211.55.11
export GAUSSDB_PORT=5432
export GAUSSDB_USERNAME=bloguser
export GAUSSDB_PASSWORD=747599qw@

docker compose -f docker-compose-gaussdb-lite.yml up -d

# 查看服务状态
docker compose -f docker-compose-gaussdb-lite.yml ps

# 停止服务
docker compose -f docker-compose-gaussdb-lite.yml down
```

此模式仅启动前端与后端，直接连接已有 GaussDB 主节点，适合生产环境或 VM 集群已就绪的场景。

**访问地址**

- 前端: http://localhost:8080
- 后端: http://localhost:8081
- GaussDB: localhost:5432
- Spark Master UI: http://localhost:8888

### 环境变量配置

创建 `.env` 文件自定义配置：

```bash
# 数据库
DB_USER=bloguser
DB_PASSWORD=blogpass
DB_NAME=blog_db

# 后端
BACKEND_PORT=8081
JAVA_OPTS=-Xms128m -Xmx256m

# 前端
FRONTEND_PORT=8080

# Spark
SPARK_MASTER_CORES=2
SPARK_WORKER_MEMORY=1G
```

---

### Spark 分析模块

### 构建 Spark 任务

```bash
cd analytics
mvn clean package -DskipTests
```

生成 JAR：`target/blog-analytics-1.0.0-jar-with-dependencies.jar`

### 运行 Spark 任务

#### 方式 1：本地运行（连接本地 GaussDB 容器）

```bash
spark-submit \
  --class com.cloudcom.analytics.BlogAnalyticsJob \
  --master local[*] \
  analytics/target/blog-analytics-1.0.0-jar-with-dependencies.jar \
  jdbc:postgresql://localhost:5432/blog_db \
  bloguser \
  OpenGauss@123
```

#### 方式 2：Spark Cluster 模式（docker-compose-gaussdb-pseudo.yml）

```bash
spark-submit \
  --class com.cloudcom.analytics.BlogAnalyticsClusterJob \
  --master spark://spark-master:7077 \
  --driver-memory 1g \
  --executor-memory 1g \
  --conf spark.driver.extraJavaOptions="-DGAUSSDB_PRIMARY_PASSWORD=OpenGauss@123" \
  analytics/target/blog-analytics-1.0.0-jar-with-dependencies.jar
```

#### 方式 3：Docker 容器运行

```bash
./run-spark-job.sh   # 自动构建 JAR 并提交到 spark-master 容器
```

#### 方式 4：通过后端 API 触发

```bash
TOKEN=$(curl -s -X POST http://localhost:8081/api/auth/login -d '{"username":"admin","password":"admin123"}' | grep -o '"token":"[^" ]*"' | cut -d'"' -f4)

curl -X POST http://localhost:8081/api/stats/analyze \
  -H "Authorization: Bearer $TOKEN"
```

### 查看 Spark 结果

```bash
# 查看统计数据
curl http://localhost:8080/api/stats \
  -H "Authorization: Bearer <token>"

# 查看聚合统计
curl http://localhost:8080/api/stats/aggregated \
  -H "Authorization: Bearer <token>"

# 查看明细列表
curl http://localhost:8080/api/stats/list \
  -H "Authorization: Bearer <token>"
```

---

## 故障排查

### 数据库连接失败

**症状**：后端启动时报 `Connection refused` 或 `FATAL: Ident authentication failed`

**解决方案**

```bash
# 检查数据库是否运行
docker-compose ps db

# 检查数据库日志
docker-compose logs db

# 验证连接
psql -h localhost -U bloguser -d blog_db

# 重启数据库
docker-compose restart db
```

### 前端无法连接后端

**症状**：浏览器控制台显示 CORS 错误或 `Failed to fetch`

**解决方案**

```bash
# 检查后端是否运行
curl http://localhost:8080/api/posts/list

# 检查后端日志
docker-compose logs backend

# 重启后端
docker-compose restart backend
```

### Spark 任务失败

**症状**：Spark 任务报错或无输出

**解决方案**

```bash
# 检查 Spark Master 状态
curl http://localhost:8888

# 查看 Spark 日志
docker-compose -f docker-compose-gaussdb.yml logs spark-master

# 检查 GaussDB 连接
docker exec blogcircle-gaussdb gsql -U omm -d postgres -c "SELECT 1"

# 重新运行任务并查看详细日志
spark-submit \
  --verbose \
  --class com.cloudcom.analytics.BlogAnalyticsJob \
  ...
```

### 内存不足

**症状**：容器被 OOM Kill 或应用崩溃

**解决方案**

```bash
# 增加 Docker 内存限制
docker update --memory 2g blogcircle-backend

# 或在 docker-compose.yml 中配置
services:
  backend:
    mem_limit: 2g
    memswap_limit: 2g

# 减少 Spark 内存使用
export SPARK_DRIVER_MEMORY=512m
export SPARK_EXECUTOR_MEMORY=512m
```

### 端口冲突

**症状**：启动时报 `Address already in use`

**解决方案**

```bash
# 查找占用端口的进程
lsof -i :8080
lsof -i :5432

# 杀死进程
kill -9 <PID>

# 或更改 docker-compose.yml 中的端口映射
ports:
  - "8082:8080"  # 改为 8082
```

---

## 性能优化

### 后端优化

```yaml
# application.yml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
  jpa:
    properties:
      hibernate:
        jdbc:
          batch_size: 20
        order_inserts: true
        order_updates: true
```

### 前端优化

```bash
# 构建优化
cd frontend
npm run build

# 启用 Gzip 压缩（Nginx）
# 在 nginx.conf 中配置
gzip on;
gzip_types text/plain text/css application/json application/javascript;
```

### Spark 优化

```bash
spark-submit \
  --driver-memory 2g \
  --executor-memory 2g \
  --num-executors 4 \
  --executor-cores 2 \
  ...
```

---

## 监控和日志

### 查看日志

```bash
# 后端日志
docker-compose logs -f backend

# 前端日志
docker-compose logs -f frontend

# 数据库日志
docker-compose logs -f db

# 所有日志
docker-compose logs -f
```

### 性能监控

```bash
# 查看容器资源使用
docker stats

# 查看数据库连接
psql -U bloguser -d blog_db -c "SELECT * FROM pg_stat_activity;"

# Spark UI
# 访问 http://localhost:8888
```

---

## 生产部署建议

1. **使用专业数据库**：在生产环境中使用托管 GaussDB 或 PostgreSQL 服务
2. **启用 HTTPS**：配置 SSL/TLS 证书
3. **配置备份**：定期备份数据库
4. **监控告警**：集成 Prometheus、Grafana 等监控工具
5. **日志收集**：使用 ELK Stack 或类似工具收集日志
6. **负载均衡**：使用 Nginx 或 HAProxy 进行负载均衡
7. **容器编排**：使用 Kubernetes 进行容器编排和自动扩展

---

## 常用命令速查

```bash
# 启动
./docker-compose-start.sh dev        # 本地开发
docker-compose up -d                 # PostgreSQL 容器
docker-compose -f docker-compose-gaussdb.yml up -d  # GaussDB 容器

# 停止
./docker-compose-stop.sh dev         # 本地开发
docker-compose down                  # PostgreSQL 容器
docker-compose -f docker-compose-gaussdb.yml down   # GaussDB 容器

# 日志
docker-compose logs -f backend
docker-compose logs -f frontend

# 数据库操作
psql -h localhost -U bloguser -d blog_db
docker exec blogcircle-db psql -U bloguser -d blog_db -c "SELECT * FROM users;"

# Spark 任务
spark-submit --class com.cloudcom.analytics.BlogAnalyticsJob ...
curl http://localhost:8080/api/stats/analyze -X POST

# 清理
docker-compose down -v               # 删除所有数据卷
docker system prune -a               # 清理所有未使用的镜像和容器
```

---

## 更多帮助

- 查看 README.md 了解项目概述
- 查看 analytics/README.md 了解 Spark 模块
- 查看 QUICK_FIX_GUIDE.md 了解常见问题
- 查看 TESTING_COMPLETE_GUIDE.md 了解测试方法
