# Blog Circle - 朋友圈风格博客系统

一个基于 Spring Boot 3 + Vue 3 的前后端分离博客系统，采用朋友圈式时间线展示，支持好友关系、评论互动和数据统计。

## 技术栈

**后端**

- Spring Boot 3.1.5 + MyBatis 3.0.3
- PostgreSQL 42.6.0 / openGauss 3.0.0
- JWT 0.11.5 (身份认证)
- Apache Spark 3.5.0 (可选数据分析)
- JDK 17

**前端**

- Vue 3.3.4 + Vite 4.5.0
- Element Plus 2.4.1 (UI 组件)
- Pinia 2.1.7 (状态管理)
- Axios 1.5.0 (HTTP 客户端)
- Playwright (E2E 测试)

**数据库**

- PostgreSQL 15 (开发/生产)
- openGauss/GaussDB (可选，支持主备集群)

## 核心功能

### 用户系统

- 注册/登录 (JWT 认证)
- 个人资料管理 (昵称、头像、封面图)
- 密码加密存储 (BCrypt)

### 文章系统

- 发布文章 (支持多图上传，最多 9 张)
- 编辑/删除文章
- 文章列表与详情
- 浏览量统计
- 好友时间线 (仅显示自己和好友的文章)

### 社交功能

- 好友搜索 (用户名/邮箱/昵称)
- 好友请求 (发送/接受/拒绝)
- 好友列表管理
- 文章评论
- 文章点赞

### 数据统计

- 实时统计 (文章数、浏览量、点赞数、评论数)
- 用户活跃度分析
- 文章热度排行
- Spark 大数据分析 (可选)

## 项目结构

```
CloudCom/
├── backend/              # Spring Boot 后端
│   │   │   ├── mapper/          # MyBatis 数据访问层
│   │   │   ├── entity/          # 实体类
│   │   │   ├── dto/             # 数据传输对象
│   │   │   ├── config/          # 配置类
│   │   │   └── util/            # 工具类
│   │   └── resources/
│   │       ├── application.yml  # 主配置文件
│   │       ├── db/01_init.sql   # 数据库初始化脚本
│   │       └── mapper/*.xml     # MyBatis SQL 映射
│   └── pom.xml
├── frontend/                     # Vue 3 前端
│   ├── src/
│   │   ├── views/               # 页面组件
│   │   ├── components/          # 可复用组件
│   │   ├── api/                 # API 接口封装
│   │   ├── stores/              # Pinia 状态管理
│   │   ├── router/              # 路由配置
│   │   └── utils/               # 工具函数
│   ├── tests/                   # 测试文件
│   └── package.json
├── docker-compose.yml            # Docker 编排配置
├── start.sh                      # 本地开发启动脚本
└── stop.sh                       # 本地开发停止脚本
```

## 数据库表结构

| 表名          | 说明       | 主要字段                                                          |
| ------------- | ---------- | ----------------------------------------------------------------- |
| `users`       | 用户表     | id, username, password, email, nickname, avatar, cover_image      |
| `posts`       | 文章表     | id, title, content, author_id, view_count, images                 |
| `comments`    | 评论表     | id, post_id, user_id, content                                     |
| `likes`       | 点赞表     | id, post_id, user_id (联合唯一索引)                               |
| `friendship`  | 好友关系表 | id, requester_id, receiver_id, status (PENDING/ACCEPTED/REJECTED) |
| `access_logs` | 访问日志表 | id, user_id, post_id, action                                      |
| `statistics`  | 统计结果表 | id, stat_type, stat_key, stat_value                               |

## API 接口

### 认证接口 (`/api/auth`)

- `POST /register` - 用户注册
- `POST /login` - 用户登录

### 用户接口 (`/api/users`)

- `GET /me` - 获取当前用户信息
- `PUT /me` - 更新个人资料
- `GET /{id}` - 获取用户信息

### 文章接口 (`/api/posts`)

- `GET /list` - 获取文章列表
- `GET /{id}/detail` - 获取文章详情
- `GET /timeline` - 获取好友时间线
- `POST /` - 创建文章 (需认证)
- `PUT /{id}` - 更新文章 (需认证)
- `DELETE /{id}` - 删除文章 (需认证)

### 评论接口 (`/api/comments`)

- `GET /post/{postId}` - 获取文章评论
- `POST /` - 发表评论 (需认证)
- `PUT /{id}` - 更新评论 (需认证)
- `DELETE /{id}` - 删除评论 (需认证)

### 点赞接口 (`/api/likes`)

- `POST /post/{postId}` - 点赞文章 (需认证)
- `DELETE /post/{postId}` - 取消点赞 (需认证)
- `GET /post/{postId}/check` - 检查是否已点赞

### 好友接口 (`/api/friends`)

- `POST /request/{receiverId}` - 发送好友请求 (需认证)
- `POST /accept/{requestId}` - 接受好友请求 (需认证)
- `POST /reject/{requestId}` - 拒绝好友请求 (需认证)
- `DELETE /user/{friendUserId}` - 删除好友 (需认证)
- `GET /list` - 获取好友列表 (需认证)
- `GET /requests` - 获取待处理请求 (需认证)
- `GET /search?keyword=xxx` - 搜索用户 (需认证)
- `GET /status/{userId}` - 检查好友状态 (需认证)

### 统计接口 (`/api/stats`)

- `POST /analyze` - 运行数据分析 (需认证)
- `GET /` - 获取所有统计数据 (需认证)
- `GET /{type}` - 获取指定类型统计 (需认证)

### 上传接口 (`/api/upload`)

- `POST /avatar` - 上传头像 (需认证)
- `POST /cover` - 上传封面图 (需认证)
- `POST /image` - 上传文章图片 (需认证)

> **认证方式**：需认证的接口需在请求头中携带 `Authorization: Bearer {token}`

## 部署场景

本系统支持多种部署场景，适用于不同的实验和生产需求：

| 场景               | 说明         | 数据库          | 特性             | 适用场景        |
| ------------------ | ------------ | --------------- | ---------------- | --------------- |
| **本地开发**       | 直接运行源码 | PostgreSQL      | 快速调试         | 日常开发        |
| **Docker Compose** | 标准容器化   | PostgreSQL      | 一键部署         | 演示/测试       |
| **GaussDB 集群**   | 一主二备集群 | openGauss       | 读写分离、高可用 | **实验要求** ⭐ |
| **Spark 分析**     | 大数据分析   | GaussDB + Spark | 分布式计算       | **实验要求** ⭐ |
| **虚拟机部署**     | 远程服务器   | GaussDB         | 生产环境模拟     | **实验要求** ⭐ |

> ⭐ 标记的场景为课程实验重点内容

## 快速开始

### 前置要求

- Java 17+
- Maven 3.6+
- Node.js 18+
- PostgreSQL 14+ (或使用 Docker)
- Docker 20+ (实验环境必需)

### 方式一：本地开发环境

1. **配置数据库**

编辑 `backend/src/main/resources/application.yml`：

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/blog_db
    username: your_username # 修改为你的数据库用户名
    password: your_password # 修改为你的数据库密码
```

2. **一键启动**

```bash
./start.sh
```

脚本会自动：

- 检查并启动 PostgreSQL
- 创建数据库 `blog_db` (如不存在)
- 执行初始化脚本
- 启动后端服务 (端口 8080)
- 安装前端依赖 (首次运行)
- 启动前端服务 (端口 5173)

3. **访问应用**

- 前端：http://localhost:5173
- 后端：http://localhost:8080
- 日志：`logs/backend.log`, `logs/frontend.log`

4. **停止服务**

```bash
./stop.sh
```

### 方式二：Docker Compose

```bash
# 启动所有服务 (PostgreSQL + 后端 + 前端)
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

访问地址：

- 前端：http://localhost:8080
- 后端：http://localhost:8081
- 数据库：localhost:5432

### 方式三：GaussDB 集群 + Spark (实验环境)

#### 3.1 本地 GaussDB 一主二备集群

使用 Docker Compose 启动完整的 GaussDB 集群环境（1 个主库 + 2 个备库 + Spark 集群）：

```bash
# 启动 GaussDB 集群 + Spark + 后端 + 前端
docker-compose -f docker-compose-gaussdb-pseudo.yml up -d

# 查看集群状态
docker-compose -f docker-compose-gaussdb-pseudo.yml ps

# 查看日志
docker-compose -f docker-compose-gaussdb-pseudo.yml logs -f

# 停止集群
docker-compose -f docker-compose-gaussdb-pseudo.yml down -v
```

**集群架构**：

- **gaussdb-primary** (主库): 端口 5432（HA 端口 5433），负责写操作
- **gaussdb-standby1** (备库 1): 端口 5434（HA 端口 5435），负责读操作
- **gaussdb-standby2** (备库 2): 端口 5436（HA 端口 5437），负责读操作
- **backend**: 端口 8081，自动实现读写分离
- **frontend**: 端口 8082
- **spark-master**: 端口 8090 (Web UI)
- **spark-worker**: 端口 8091

> **注意**：GaussDB 每个实例需要 2 个连续端口（主端口+HA 端口），使用间隔端口避免冲突。

**读写分离配置**：

- 写操作（INSERT/UPDATE/DELETE）→ 主库 (5432)
- 读操作（SELECT）→ 备库 (5434, 5436) 负载均衡

**验证集群状态**：

```bash
# 连接主库
docker exec -it gaussdb-primary gsql -U bloguser -d blog_db -c "SELECT * FROM pg_stat_replication;"

# 连接备库1（端口 5434）
docker exec -it gaussdb-standby1 gsql -U bloguser -d blog_db -c "SELECT pg_is_in_recovery();"

# 连接备库2（端口 5436）
docker exec -it gaussdb-standby2 gsql -U bloguser -d blog_db -c "SELECT pg_is_in_recovery();"
```

**Spark 分析任务**：

```bash
# 访问 Spark Master Web UI
open http://localhost:8090

# 触发数据分析 (通过后端 API)
curl -X POST http://localhost:8081/api/stats/analyze \
  -H "Authorization: Bearer YOUR_TOKEN"

# 查看统计结果
curl http://localhost:8081/api/stats \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### 3.2 虚拟机部署 (10.211.55.11)

**环境说明**：

- VM IP: 10.211.55.11
- 用户: root / 747599qw@
- 系统: openEuler 22.03 LTS
- GaussDB 版本: openGauss 5.0.0 / 9.2.4
- GaussDB 安装路径: /usr/local/opengauss
- 数据目录:
  - 主库: `/usr/local/opengauss/data_primary` (端口 5432)
  - 备库 1: `/usr/local/opengauss/data_standby1` (端口 5434)
  - 备库 2: `/usr/local/opengauss/data_standby2` (端口 5436)
- 数据库: blog_db
- 用户: bloguser / 747599qw@
- 管理用户: omm

**部署步骤**：

**方案 A：快速部署（推荐）**

```bash
# 1. 同步脚本到虚拟机（在本地 Mac 上）
./sync-scripts-to-vm.sh

# 2. SSH 登录虚拟机
ssh root@10.211.55.11

# 3. 重构端口配置
cd CloudCom
./scripts/refactor-ports.sh

# 4. 验证集群
./scripts/verify-gaussdb-cluster.sh
```

**方案 B：完整部署**

1. **使用自动化脚本部署**：

```bash
# 一键部署到虚拟机
./docker-compose-start.sh vm
```

脚本会自动：

- 通过 SSH 连接虚拟机
- 同步代码到虚拟机
- 在虚拟机上执行 docker-compose up
- 配置网络和防火墙

2. **手动部署**：

```bash
# 1. 同步代码到虚拟机
sshpass -p "747599qw@" rsync -avz \
  --exclude='node_modules' --exclude='target' --exclude='.git' \
  ./ root@10.211.55.11:~/CloudCom/

# 2. SSH 登录虚拟机
ssh root@10.211.55.11

# 3. 初始化 GaussDB 集群
cd ~/CloudCom
./setup-gaussdb-single-vm-cluster.sh

# 4. 重构端口配置（避免端口冲突）
./scripts/refactor-ports.sh

# 5. 验证集群状态
./scripts/verify-gaussdb-cluster.sh
```

**访问地址**：

- 前端：http://10.211.55.11:8080
- 后端：http://10.211.55.11:8081
- GaussDB 主库：10.211.55.11:5432
- GaussDB 备库 1：10.211.55.11:5434
- GaussDB 备库 2：10.211.55.11:5436

**集群管理脚本**：

系统提供完整的管理和故障排查脚本（位于 `scripts/` 目录）：

| 脚本名称                     | 功能说明                     | 使用场景     |
| ---------------------------- | ---------------------------- | ------------ |
| `refactor-ports.sh`          | 重构端口配置（推荐首次运行） | 解决端口冲突 |
| `verify-gaussdb-cluster.sh`  | 验证集群状态                 | 健康检查     |
| `test-gaussdb-readwrite.sh`  | 测试读写功能                 | 功能验证     |
| `diagnose-gaussdb-ports.sh`  | 诊断端口问题                 | 故障排查     |
| `fix-primary-replication.sh` | 修复主库复制配置             | 复制问题修复 |
| `rebuild-standby2.sh`        | 重建备库 2                   | 备库重建     |
| `check-standby2-logs.sh`     | 检查备库 2 日志              | 日志分析     |
| `fix-backup-permissions.sh`  | 修复备份文件权限             | 权限问题     |
| `start-vm-services.sh`       | 启动所有服务                 | 服务启动     |
| `stop-vm-services.sh`        | 停止所有服务                 | 服务停止     |
| `restart-vm-services.sh`     | 重启所有服务                 | 服务重启     |
| `check-vm-status.sh`         | 检查虚拟机状态               | 完整状态检查 |

详细说明请查看：[scripts/README.md](scripts/README.md)

**验证 GaussDB 集群**：

```bash
# 使用验证脚本（推荐）
./scripts/verify-gaussdb-cluster.sh

# 或手动验证
# 检查 GaussDB 进程
ps aux | grep gaussdb

# 连接主库（端口 5432）
su - omm -c "gsql -d blog_db -p 5432 -c 'SELECT version();'"

# 查看复制状态
su - omm -c "gsql -d postgres -p 5432 -c 'SELECT * FROM pg_stat_replication;'"

# 检查备库1状态（端口 5434）
su - omm -c "gsql -d blog_db -p 5434 -c 'SELECT pg_is_in_recovery();'"

# 检查备库2状态（端口 5436）
su - omm -c "gsql -d blog_db -p 5436 -c 'SELECT pg_is_in_recovery();'"
```

**常用运维命令**：

```bash
# 启动主库
su - omm -c "gs_ctl start -D /usr/local/opengauss/data_primary"

# 启动备库1
su - omm -c "gs_ctl start -D /usr/local/opengauss/data_standby1"

# 启动备库2
su - omm -c "gs_ctl start -D /usr/local/opengauss/data_standby2"

# 停止实例
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_primary -m fast"

# 查看实例状态
su - omm -c "gs_ctl status -D /usr/local/opengauss/data_primary"

# 查看端口监听
lsof -i :5432
lsof -i :5434
lsof -i :5436
```

## 配置说明

### 后端配置 (`application.yml`)

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/blog_db
    username: lying
    password: 456789
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5

jwt:
  secret: cloudcom-blog-system-secret-key-2025
  expiration: 86400000 # 24小时

spark:
  enabled: false # 是否启用 Spark 分析 (默认使用 SQL)

file:
  upload:
    path: ./uploads
    url-prefix: /uploads

server:
  port: 8080
```

### 后端配置 (`application-gaussdb-cluster.yml`)

用于 GaussDB 一主二备集群环境，实现读写分离：

```yaml
spring:
  datasource:
    primary: # 主库配置 (写操作)
      driver-class-name: org.postgresql.Driver
      jdbc-url: ${GAUSSDB_PRIMARY_URL:jdbc:postgresql://10.211.55.11:5432/blog_db}
      username: ${GAUSSDB_USERNAME:bloguser}
      password: ${GAUSSDB_PASSWORD:747599qw@}
      maximum-pool-size: 10
      minimum-idle: 3
      connection-test-query: SELECT 1
      pool-name: GaussDB-Primary-HikariCP

    replica: # 备库配置 (读操作，负载均衡)
      driver-class-name: org.postgresql.Driver
      jdbc-url: ${GAUSSDB_REPLICA_URL:jdbc:postgresql://10.211.55.11:5432/blog_db}
      username: ${GAUSSDB_USERNAME:bloguser}
      password: ${GAUSSDB_PASSWORD:747599qw@}
      maximum-pool-size: 10
      minimum-idle: 3
      connection-test-query: SELECT 1
      pool-name: GaussDB-Replica-HikariCP

jwt:
  secret: cloudcom-blog-system-secret-key-2025
  expiration: 86400000

file:
  upload:
    path: /app/uploads
    url-prefix: /uploads

server:
  port: 8080

logging:
  level:
    com.cloudcom.blog: INFO
    org.opengauss: WARN
    com.zaxxer.hikari: DEBUG
```

**读写分离实现**：

系统通过 AOP 切面自动路由数据库请求：

- `@ReadOnly` 注解的方法 → 备库 (replica)
- 其他方法（INSERT/UPDATE/DELETE）→ 主库 (primary)

示例代码 (`DataSourceAspect.java`)：

```java
@Around("execution(* com.cloudcom.blog.service.*.*(..))")
public Object routeDataSource(ProceedingJoinPoint point) {
    MethodSignature signature = (MethodSignature) point.getSignature();
    Method method = signature.getMethod();

    if (method.isAnnotationPresent(ReadOnly.class)) {
        DataSourceContextHolder.setDataSource("replica");
    } else {
        DataSourceContextHolder.setDataSource("primary");
    }

    return point.proceed();
}
```

### 前端配置

**开发环境** (`vite.config.js`)：

```javascript
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:8080',
      changeOrigin: true
    }
  }
}
```

**生产环境** (`nginx.conf`)：

```nginx
location /api {
    proxy_pass http://backend:8080;
}
```

## Spark 数据分析

### Spark 架构

系统集成了 Apache Spark 3.5.0 用于大规模数据分析：

**组件**：

- **Spark Master**: 集群管理节点，端口 7077 (内部) / 8090 (Web UI)
- **Spark Worker**: 计算节点，1G 内存，2 核 CPU
- **后端集成**: 通过 Spark SQL 读取 GaussDB 数据

### 启用 Spark 分析

1. **修改配置** (`application.yml`):

```yaml
spark:
  enabled: true # 启用 Spark (默认 false，使用 SQL)
```

2. **启动 Spark 集群**:

```bash
# 使用 GaussDB 集群配置启动 (包含 Spark)
docker-compose -f docker-compose-gaussdb-pseudo.yml up -d
```

3. **访问 Spark Web UI**:

```
http://localhost:8090
```

### 数据分析任务

**支持的统计类型**：

- `USER_POST_COUNT`: 用户发文数量统计
- `POST_VIEW_COUNT`: 文章浏览量统计
- `COMMENT_COUNT`: 评论数量统计

**触发分析**：

```bash
# 1. 登录获取 Token
TOKEN=$(curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
  | jq -r '.data.token')

# 2. 触发 Spark 分析
curl -X POST http://localhost:8081/api/stats/analyze \
  -H "Authorization: Bearer $TOKEN"

# 3. 查看统计结果
curl http://localhost:8081/api/stats \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Spark 执行流程**：

1. 从 GaussDB 备库读取 `access_logs` 表数据
2. 使用 Spark SQL 进行聚合计算
3. 将统计结果写入 `statistics` 表
4. 前端通过 API 查询统计数据并可视化展示

### Spark vs SQL 分析对比

| 特性     | Spark 分析            | SQL 分析       |
| -------- | --------------------- | -------------- |
| 适用场景 | 大数据量 (百万级+)    | 中小数据量     |
| 性能     | 分布式并行计算        | 单机数据库查询 |
| 资源消耗 | 需要额外内存 (1G+)    | 仅数据库资源   |
| 复杂度   | 较高                  | 较低           |
| 默认配置 | 禁用 (Java 17 兼容性) | 启用           |

**注意**：默认使用 SQL 分析以保证兼容性，Spark 分析需手动启用。

## 实验验证

### 验证 GaussDB 集群

#### 1. 验证主备复制

```bash
# 连接主库查看复制状态
docker exec -it gaussdb-primary gsql -U bloguser -d blog_db \
  -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"

# 预期输出：
#  application_name | state     | sync_state
# ------------------+-----------+------------
#  standby1         | streaming | async
#  standby2         | streaming | async
```

#### 2. 验证备库恢复模式

```bash
# 备库应返回 't' (true)
docker exec -it gaussdb-standby1 gsql -U bloguser -d blog_db \
  -c "SELECT pg_is_in_recovery();"

docker exec -it gaussdb-standby2 gsql -U bloguser -d blog_db \
  -c "SELECT pg_is_in_recovery();"
```

#### 3. 验证读写分离

```bash
# 在主库写入数据
docker exec -it gaussdb-primary gsql -U bloguser -d blog_db \
  -c "INSERT INTO users (username, password, email, nickname)
      VALUES ('test_user', 'password', 'test@example.com', 'Test');"

# 在备库查询数据 (应能查到)
docker exec -it gaussdb-standby1 gsql -U bloguser -d blog_db \
  -c "SELECT username FROM users WHERE username='test_user';"
```

#### 4. 验证负载均衡

查看后端日志，确认读操作分布到不同备库：

```bash
docker-compose -f docker-compose-gaussdb-pseudo.yml logs backend | grep "HikariCP"
```

### 验证 Spark 集群

#### 1. 检查 Spark 服务状态

```bash
# 查看 Spark Master
curl http://localhost:8090

# 查看 Worker 注册情况
docker-compose -f docker-compose-gaussdb-pseudo.yml logs spark-master | grep "Registering worker"
```

#### 2. 执行测试分析任务

```bash
# 1. 登录系统
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# 2. 创建测试文章
curl -X POST http://localhost:8081/api/posts \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Post","content":"Test content for Spark analysis"}'

# 3. 触发 Spark 分析
curl -X POST http://localhost:8081/api/stats/analyze \
  -H "Authorization: Bearer YOUR_TOKEN"

# 4. 查看 Spark 执行日志
docker-compose -f docker-compose-gaussdb-pseudo.yml logs backend | grep "Spark"
```

#### 3. 验证统计结果

```bash
# 查询所有统计数据
curl http://localhost:8081/api/stats \
  -H "Authorization: Bearer YOUR_TOKEN" | jq

# 查询特定类型统计
curl http://localhost:8081/api/stats/USER_POST_COUNT \
  -H "Authorization: Bearer YOUR_TOKEN" | jq
```

### 性能测试

#### 1. 数据库连接池测试

```bash
# 查看连接池状态
docker-compose -f docker-compose-gaussdb-pseudo.yml logs backend | grep "HikariPool"
```

#### 2. 并发请求测试

```bash
# 使用 Apache Bench 测试
ab -n 1000 -c 10 http://localhost:8081/api/posts/list

# 或使用 wrk
wrk -t4 -c100 -d30s http://localhost:8081/api/posts/list
```

#### 3. 复制延迟测试

```bash
# 在主库插入数据并记录时间
docker exec -it gaussdb-primary gsql -U bloguser -d blog_db \
  -c "INSERT INTO access_logs (user_id, action) VALUES (1, 'TEST'); SELECT NOW();"

# 立即在备库查询
docker exec -it gaussdb-standby1 gsql -U bloguser -d blog_db \
  -c "SELECT * FROM access_logs WHERE action='TEST'; SELECT NOW();"
```

## 测试

### 后端测试

```bash
cd backend
mvn test
```

### 前端测试

```bash
cd frontend

# 单元测试
npm run test

# E2E 测试
npm run test:e2e

# 测试覆盖率
npm run test:coverage
```

### 集成测试

```bash
# 运行完整测试套件 (包含 GaussDB 集群测试)
./tests/run-all-tests.sh
```

## 测试账号

| 用户名 | 密码     | 说明       |
| ------ | -------- | ---------- |
| admin  | admin123 | 管理员账号 |
| user1  | user123  | 普通用户   |

## 常见问题

### 1. GaussDB 端口冲突

**问题**：备库启动失败，提示 "port already in use" 或进程监听多个端口

**原因**：GaussDB 每个实例需要 2 个连续端口（主端口+HA 端口），端口间隔太小导致冲突

**解决方案**：

```bash
# 1. 诊断问题
./scripts/diagnose-gaussdb-ports.sh

# 2. 重构端口配置
./scripts/refactor-ports.sh

# 3. 验证结果
./scripts/verify-gaussdb-cluster.sh
```

### 2. 主备复制未建立

**问题**：备库无法连接到主库，复制状态显示为空

**解决方案**：

```bash
# 1. 修复主库复制配置
./scripts/fix-primary-replication.sh

# 2. 重建备库（如果必要）
./scripts/rebuild-standby2.sh

# 3. 验证复制状态
su - omm -c "gsql -d postgres -p 5432 -c 'SELECT * FROM pg_stat_replication;'"
```

### 3. 备库启动失败

**问题**：备库一直启动失败，日志显示连接错误

**解决方案**：

```bash
# 1. 检查日志
./scripts/check-standby2-logs.sh

# 2. 检查主库配置
./scripts/fix-primary-replication.sh

# 3. 重建备库
./scripts/rebuild-standby2.sh
```

### 4. 文件权限问题

**问题**：gs_basebackup 失败，提示 "Permission denied"

**解决方案**：

```bash
./scripts/fix-backup-permissions.sh
```

选择 `y` 删除备份文件

### 5. 后端启动失败

**问题**：数据库连接失败

**解决方案**：

- 确认 GaussDB 已启动：`ps aux | grep gaussdb`
- 检查数据库配置是否正确
- 确认数据库 `blog_db` 已创建
- 查看日志：`logs/backend.log`
- 验证连接：`su - omm -c "gsql -d blog_db -p 5432"`

### 6. 前端无法访问后端

**问题**：API 请求失败或跨域错误

**解决方案**：

- 确认后端运行在 8080 端口
- 检查 Vite 代理配置 (`vite.config.js`)
- 确认后端 CORS 配置 (`WebConfig.java`)

### 7. 文件上传失败

**问题**：上传图片时报错

**解决方案**：

- 确认 `uploads` 目录存在且有写权限
- 检查文件大小限制 (默认 10MB)
- 查看后端日志中的错误信息

### 8. Docker 容器启动失败

**问题**：容器无法启动或健康检查失败

**解决方案**：

- 查看容器日志：`docker-compose logs backend`
- 确认端口未被占用
- 等待数据库完全启动后再启动后端

---

**更多故障排查指南**：参见 [scripts/README.md](scripts/README.md)

## 开发指南

### 后端开发

1. 使用 IntelliJ IDEA 导入 Maven 项目
2. 配置 JDK 17
3. 运行 `BlogApplication.java`
4. 遵循 Controller → Service → Mapper 分层架构

### 前端开发

1. 使用 VS Code 打开项目
2. 安装推荐插件：Volar、ESLint
3. 组件开发遵循 Vue 3 Composition API
4. API 调用统一通过 `src/api/` 封装

### 代码规范

- **后端**：遵循 Spring Boot 官方规范，使用 Lombok 简化代码
- **前端**：遵循 Vue 3 官方风格指南，使用 ESLint 检查

## 生产部署

### 后端部署

```bash
cd backend
mvn clean package -DskipTests
java -jar target/blog-system-1.0.0.jar
```

### 前端部署

```bash
cd frontend
npm run build
# 将 dist/ 目录部署到 Nginx 或其他静态服务器
```

## License

本项目仅供学习和研究使用。

## 参考文档

- [Spring Boot 官方文档](https://spring.io/projects/spring-boot)
- [Vue 3 官方文档](https://cn.vuejs.org/)
- [Element Plus 文档](https://element-plus.org/)
- [MyBatis 文档](https://mybatis.org/mybatis-3/)
