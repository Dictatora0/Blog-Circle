# Docker 快速参考

本文档汇总所有 Docker 相关的构建、运行和部署命令。

## 镜像清单

| 组件   | Dockerfile             | 基础镜像                                                    | 用途                  |
| ------ | ---------------------- | ----------------------------------------------------------- | --------------------- |
| 后端   | `backend/Dockerfile`   | `maven:3.8.7-eclipse-temurin-17` + `eclipse-temurin:17-jre` | Spring Boot 应用      |
| 前端   | `frontend/Dockerfile`  | `node:18-alpine` + `nginx:alpine`                           | Vue 3 + Nginx         |
| 数据库 | 官方镜像               | `postgres:15-alpine` 或 `enmotech/opengauss:latest`         | PostgreSQL 或 GaussDB |
| Spark  | `analytics/Dockerfile` | `bitnami/spark:3.5.0`                                       | Spark 分析任务        |

---

## 单个镜像构建

### 后端镜像

```bash
# 构建
cd backend
docker build -t blog-backend:latest .

# 运行
docker run -d \
  --name blog-backend \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/blog_db \
  -e SPRING_DATASOURCE_USERNAME=bloguser \
  -e SPRING_DATASOURCE_PASSWORD=blogpass \
  -p 8080:8080 \
  blog-backend:latest

# 推送到仓库
docker tag blog-backend:latest myregistry/blog-backend:latest
docker push myregistry/blog-backend:latest
```

### 前端镜像

```bash
# 构建
cd frontend
docker build -t blog-frontend:latest .

# 运行
docker run -d \
  --name blog-frontend \
  -p 8080:80 \
  blog-frontend:latest

# 推送到仓库
docker tag blog-frontend:latest myregistry/blog-frontend:latest
docker push myregistry/blog-frontend:latest
```

### Spark 镜像

```bash
# 构建
cd analytics
docker build -t blog-analytics:latest .

# 运行（本地模式）
docker run \
  --network blogcircle-network \
  blog-analytics:latest \
  jdbc:opengauss://gaussdb:5432/blog_db \
  bloguser \
  blogpass

# 推送到仓库
docker tag blog-analytics:latest myregistry/blog-analytics:latest
docker push myregistry/blog-analytics:latest
```

---

## Docker Compose 部署

### PostgreSQL 栈（标准部署）

```bash
# 文件：docker-compose.yml
# 服务：db (PostgreSQL), backend, frontend

# 启动
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 停止
docker-compose down

# 完全清理
docker-compose down -v
```

**服务访问**

- 前端: http://localhost:8080
- 后端: http://localhost:8081
- 数据库: localhost:5432

### GaussDB + Spark 栈（完整部署）

```bash
# 文件：docker-compose-gaussdb.yml
# 服务：gaussdb, backend, frontend, spark-master, spark-worker

# 启动
docker-compose -f docker-compose-gaussdb.yml up -d

# 查看状态
docker-compose -f docker-compose-gaussdb.yml ps

# 查看日志
docker-compose -f docker-compose-gaussdb.yml logs -f

# 停止
docker-compose -f docker-compose-gaussdb.yml down

# 完全清理
docker-compose -f docker-compose-gaussdb.yml down -v
```

**服务访问**

- 前端: http://localhost:8080
- 后端: http://localhost:8081
- GaussDB: localhost:5432
- Spark Master UI: http://localhost:8888

---

## 多容器网络

### 创建自定义网络

```bash
docker network create blogcircle-network
```

### 在网络中运行容器

```bash
# 后端连接数据库
docker run -d \
  --name blog-backend \
  --network blogcircle-network \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/blog_db \
  blog-backend:latest

# 前端连接后端
docker run -d \
  --name blog-frontend \
  --network blogcircle-network \
  -p 8080:80 \
  blog-frontend:latest
```

### 查看网络

```bash
# 列出所有网络
docker network ls

# 查看网络详情
docker network inspect blogcircle-network

# 删除网络
docker network rm blogcircle-network
```

---

## 数据卷管理

### 创建卷

```bash
docker volume create db_data
docker volume create gaussdb_data
```

### 挂载卷

```bash
# 在 docker-compose.yml 中
volumes:
  db_data:
    driver: local
  gaussdb_data:
    driver: local

services:
  db:
    volumes:
      - db_data:/var/lib/postgresql/data
```

### 查看卷

```bash
# 列出所有卷
docker volume ls

# 查看卷详情
docker volume inspect db_data

# 删除卷
docker volume rm db_data
```

### 备份和恢复

```bash
# 备份数据库
docker run --rm \
  -v db_data:/data \
  -v $(pwd):/backup \
  postgres:15-alpine \
  tar czf /backup/db_backup.tar.gz -C /data .

# 恢复数据库
docker run --rm \
  -v db_data:/data \
  -v $(pwd):/backup \
  postgres:15-alpine \
  tar xzf /backup/db_backup.tar.gz -C /data
```

---

## 环境变量和配置

### 通过环境变量配置

```bash
# 方式 1：命令行
docker run -e SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/blog_db ...

# 方式 2：.env 文件
# 创建 .env
DB_USER=bloguser
DB_PASSWORD=blogpass
DB_NAME=blog_db

# 使用
docker-compose --env-file .env up -d

# 方式 3：docker-compose.yml
environment:
  - SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/blog_db
  - SPRING_DATASOURCE_USERNAME=bloguser
```

### 查看容器环境变量

```bash
docker inspect blog-backend | grep -A 20 "Env"
```

---

## 日志管理

### 查看日志

```bash
# 实时日志
docker logs -f blog-backend

# 最后 100 行
docker logs --tail 100 blog-backend

# 带时间戳
docker logs -t blog-backend

# 从特定时间开始
docker logs --since 2025-11-17T20:00:00 blog-backend
```

### 日志驱动配置

```yaml
# docker-compose.yml
services:
  backend:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

## 镜像优化

### 减小镜像大小

```dockerfile
# 后端 Dockerfile 优化
FROM maven:3.8.7-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests

# 使用更小的基础镜像
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 多阶段构建

```bash
# 构建时使用大镜像，运行时使用小镜像
# 可减少最终镜像大小 50-70%

# 查看镜像大小
docker images | grep blog

# 清理未使用的镜像
docker image prune -a
```

---

## 容器健康检查

### 配置健康检查

```yaml
# docker-compose.yml
services:
  backend:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### 查看健康状态

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

---

## 常见问题

### 镜像构建失败

```bash
# 查看详细错误
docker build --progress=plain -t blog-backend:latest .

# 清理构建缓存
docker builder prune

# 强制重新构建（不使用缓存）
docker build --no-cache -t blog-backend:latest .
```

### 容器启动失败

```bash
# 查看启动日志
docker logs blog-backend

# 进入容器调试
docker exec -it blog-backend /bin/bash

# 查看容器详情
docker inspect blog-backend
```

### 网络连接问题

```bash
# 测试容器间通信
docker exec blog-backend ping db

# 查看网络配置
docker network inspect blogcircle-network

# 重启网络
docker network disconnect blogcircle-network blog-backend
docker network connect blogcircle-network blog-backend
```

### 资源限制

```bash
# 限制内存和 CPU
docker run -d \
  --memory 512m \
  --cpus 1.0 \
  blog-backend:latest

# 查看资源使用
docker stats blog-backend
```

---

## 生产部署最佳实践

1. **使用特定版本标签**

   ```bash
   docker tag blog-backend:latest myregistry/blog-backend:v1.0.0
   docker push myregistry/blog-backend:v1.0.0
   ```

2. **配置资源限制**

   ```yaml
   services:
     backend:
       mem_limit: 1g
       cpus: 1.0
   ```

3. **启用日志驱动**

   ```yaml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```

4. **使用健康检查**

   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
     interval: 30s
     timeout: 10s
     retries: 3
   ```

5. **配置重启策略**

   ```yaml
   restart_policy:
     condition: on-failure
     delay: 5s
     max_attempts: 3
   ```

6. **使用 Docker Secrets（Swarm）**

   ```bash
   docker secret create db_password -
   ```

7. **镜像扫描和签名**
   ```bash
   docker scan blog-backend:latest
   docker trust sign myregistry/blog-backend:v1.0.0
   ```

---

## 快速命令

```bash
# 构建所有镜像
docker-compose build

# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose stop

# 删除所有容器
docker-compose rm -f

# 查看所有容器
docker-compose ps

# 查看所有日志
docker-compose logs -f

# 进入后端容器
docker-compose exec backend /bin/bash

# 执行数据库命令
docker-compose exec db psql -U bloguser -d blog_db

# 清理所有资源
docker-compose down -v
docker system prune -a
```
