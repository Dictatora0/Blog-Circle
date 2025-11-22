# Blog Circle - 朋友圈风格博客系统

一个基于 Spring Boot 3 + Vue 3 的前后端分离博客系统，采用朋友圈式时间线展示，支持好友关系、评论互动和数据统计。


## ✨ 项目特色

- ✅ **完整的虚拟机部署** - 已成功部署在虚拟机 (10.211.55.11)
- ✅ **openGauss 三实例集群** - 一主两备，高可用架构
- ✅ **读写分离** - 自动路由读写请求到不同节点
- ✅ **离线部署** - 支持无外网环境部署
- ✅ **Docker 版本兼容** - 兼容 Docker 18.09+
- ✅ **全面的 API 测试** - 18 个测试用例，100% 通过率
- ✅ **Spark 数据分析** - 支持大数据分析（openGauss 兼容）

## 技术栈

**后端**

- Spring Boot 3.1.5 + MyBatis 3.0.3
- PostgreSQL 42.6.0 / openGauss 3.0.0
- JWT 0.11.5 (身份认证)
- Apache Spark 3.5.0 (数据分析)
- JDK 17

**前端**

- Vue 3.3.4 + Vite 4.5.0
- Element Plus 2.4.1 (UI 组件)
- Pinia 2.1.7 (状态管理)
- Axios 1.5.0 (HTTP 客户端)
- Playwright (E2E 测试)

**数据库**

- PostgreSQL 15 (开发/生产)
- openGauss/GaussDB (支持主备集群)

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

## 📋 目录

- [快速开始](#快速开始)
  - [虚拟机部署（推荐）](#虚拟机部署推荐)
  - [本地开发](#本地开发)
- [虚拟机部署详情](#虚拟机部署详情)
- [API 测试](#api-测试)
- [架构设计](#架构设计)
- [常见问题](#常见问题)

---

## 🚀 快速开始

### 虚拟机部署（推荐）

系统已完整部署在虚拟机 **10.211.55.11** 上，可直接访问：

#### 访问地址

- **前端页面**: http://10.211.55.11:8080
- **后端 API**: http://10.211.55.11:8082
- **健康检查**: http://10.211.55.11:8082/actuator/health

#### 测试账号

| 用户名 | 密码     | 说明       |
| ------ | -------- | ---------- |
| admin  | admin123 | 管理员账号 |
| user1  | user123  | 普通用户   |

#### 一键部署/重启

```bash
# 从本地 Mac 一键部署到虚拟机
./start-vm.sh
```

**脚本功能**：

1. ✓ 检查虚拟机连接
2. ✓ 同步配置文件
3. ✓ 在本地构建应用镜像（后端 + 前端）
4. ✓ 传输镜像到虚拟机（~950MB）
5. ✓ 启动 openGauss 三实例集群
6. ✓ 启动后端和前端服务
7. ✓ 健康检查验证

**首次部署时间**: 15-20 分钟  
**后续重启时间**: 5-8 分钟（Docker 缓存加速）

#### 管理命令

```bash
# 查看服务状态
./status.sh vm

# 停止服务
./stop-vm.sh

# API 功能测试（18 个测试用例）
./test-vm-api.sh

# SSH 连接虚拟机
ssh root@10.211.55.11  # 密码: 747599qw@
```

---

### 本地开发

#### 前置要求

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

---

## 🖥️ 虚拟机部署详情

### 部署架构

```
虚拟机 (10.211.55.11)
│
├─ Docker Network: opengauss-network (172.26.0.0/16)
│   │
│   ├─ opengauss-primary (172.26.0.10:5432)
│   │   └─ 数据库: blog_db
│   │       └─ 用户: bloguser
│   │
│   ├─ opengauss-standby1 (172.26.0.11:15432 → 5434)
│   │
│   ├─ opengauss-standby2 (172.26.0.12:25432 → 5436)
│   │
│   ├─ blogcircle-backend (172.26.0.2:8080 → 8082)
│   │   ├─ Spring Boot 应用
│   │   ├─ JVM: 64-128MB, SerialGC
│   │   └─ 连接: opengauss-primary:5432
│   │
│   └─ blogcircle-frontend (8080)
│       ├─ Vue.js 应用
│       ├─ Nginx 反向代理
│       ├─ 上传限制: 50MB
│       └─ 代理至: blogcircle-backend:8080
```

### 虚拟机环境信息

| 项目           | 值                       |
| -------------- | ------------------------ |
| IP 地址        | 10.211.55.11             |
| 操作系统       | CentOS/openEuler         |
| Docker 版本    | 18.09.0                  |
| Docker Compose | 1.23.1 (legacy 兼容模式) |
| openGauss 版本 | 5.0.3                    |
| 数据库         | blog_db                  |
| 数据库用户     | bloguser / Blog@2025     |

### 部署配置

使用 `docker-compose-opengauss-cluster-legacy.yml` 兼容 Docker 18.09：

**主要优化**：

- 移除新版 Docker Compose 不支持的语法
- 后端添加 `privileged: true` 解决 JVM 线程创建问题
- JVM 优化：`-Xms64m -Xmx128m -XX:+UseSerialGC`
- 前端 Nginx 上传限制设置为 50MB
- 使用 MERGE 语句替代 ON CONFLICT（openGauss 兼容）

### 已解决的问题

<details>
<summary><b>1. Docker 版本兼容性</b></summary>

**问题**: 虚拟机 Docker 18.09 不支持新版语法  
**解决**: 创建 legacy 版本配置文件，移除 `healthcheck.start_period` 等

</details>

<details>
<summary><b>2. JVM 线程创建失败</b></summary>

**问题**: `pthread_create failed (EPERM)`  
**解决**: 添加 `privileged: true` 和 capabilities

</details>

<details>
<summary><b>3. 数据库权限</b></summary>

**问题**: `permission denied for schema public`  
**解决**: `GRANT ALL ON SCHEMA public TO bloguser`

</details>

<details>
<summary><b>4. 前端 502 错误</b></summary>

**问题**: Nginx 使用 127.0.0.1 无法访问后端  
**解决**: 改为 `blogcircle-backend:8080`

</details>

<details>
<summary><b>5. 文件上传 413 错误</b></summary>

**问题**: Nginx 默认 1MB 限制  
**解决**: 设置 `client_max_body_size 50M`

</details>

<details>
<summary><b>6. SQL 语法不兼容</b></summary>

**问题**: openGauss 不支持 `ON CONFLICT`  
**解决**: 使用 `MERGE INTO` 语句

</details>

### 离线部署说明

系统采用**完全离线部署策略**：

1. **在本地 Mac 构建镜像**（需要外网）

   - 后端镜像: ~500MB
   - 前端镜像: ~50MB
   - openGauss 镜像: ~400MB

2. **传输镜像到虚拟机**（无需外网）

   - 通过 SSH 传输 tar 文件
   - 虚拟机加载镜像

3. **启动服务**（无需外网）
   - 使用预构建镜像
   - 无需 build 步骤

**优势**：

- ✅ 虚拟机无需访问外网
- ✅ 版本完全一致
- ✅ 可重复部署
- ✅ 故障恢复快速

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

系统集成了 Apache Spark 3.5.0 用于数据分析：

**特点**：

- **内嵌模式**: Spark 引擎集成在 Spring Boot 后端服务中
- **local[*] 模式**: 本地多线程执行，无需独立集群
- **读取数据**: 通过 JDBC 从 openGauss 读取数据
- **备用方案**: Spark 失败时自动回退到 SQL 查询

### Spark 分析说明

**运行模式**：

- Spark 采用 **内嵌模式**，集成在 Spring Boot 后端服务中
- 使用 `local[*]` 本地多线程模式，无需独立集群
- 默认启用，失败时自动回退到 SQL 直接查询

**配置选项** (`application.yml`):

```yaml
spark:
  enabled: true # 默认启用，设为 false 则直接使用 SQL
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

#### 4. 验证读写分离

查看后端日志，确认读写操作路由到正确的数据源：

```bash
# 虚拟机环境
tail -f ~/CloudCom/backend/logs/backend.log | grep "HikariCP"

# Docker 本地环境
docker-compose logs -f backend | grep "HikariCP"
```

### 验证 Spark 分析

#### 1. 执行测试分析任务

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
# 虚拟机环境
tail -f ~/CloudCom/backend/logs/backend.log | grep "Spark"

# Docker 本地环境
docker-compose logs -f backend | grep "Spark"
```

#### 2. 验证统计结果

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
# 虚拟机环境
tail -f ~/CloudCom/backend/logs/backend.log | grep "HikariPool"

# Docker 本地环境
docker-compose logs -f backend | grep "HikariPool"
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

---

## 🧪 API 测试

### 自动化测试脚本

系统提供完整的 API 自动化测试脚本：

```bash
./test-vm-api.sh
```

### 测试覆盖

**18 个测试用例，100% 通过率**：

| #   | 测试项               | 状态      |
| --- | -------------------- | --------- |
| 1   | 健康检查 API         | ✅ PASSED |
| 2   | 前端页面可访问性     | ✅ PASSED |
| 3   | 用户注册 API         | ✅ PASSED |
| 4   | 用户登录 API         | ✅ PASSED |
| 5   | 获取当前用户信息 API | ✅ PASSED |
| 6   | 发布动态 API         | ✅ PASSED |
| 7   | 获取动态列表 API     | ✅ PASSED |
| 8   | 获取动态详情 API     | ✅ PASSED |
| 9   | 点赞动态 API         | ✅ PASSED |
| 10  | 发布评论 API         | ✅ PASSED |
| 11  | 获取评论列表 API     | ✅ PASSED |
| 12  | 获取我的动态 API     | ✅ PASSED |
| 13  | 获取统计数据 API     | ✅ PASSED |
| 14  | 图片上传 API         | ✅ PASSED |
| 15  | 取消点赞 API         | ✅ PASSED |
| 16  | 删除评论 API         | ✅ PASSED |
| 17  | 删除动态 API         | ✅ PASSED |
| 18  | 数据库连接测试       | ✅ PASSED |

### 测试示例输出

```
╔════════════════════════════════════════════════╗
║       Blog Circle API 测试                     ║
║       API Testing Suite                       ║
╚════════════════════════════════════════════════╝

测试目标: http://10.211.55.11:8082

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[测试 1] 健康检查 API
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HTTP 状态码: 200
响应内容: {"status":"UP","components":{"db":{"status":"UP"}...}}
✓ 测试通过

... (省略其他测试)

╔════════════════════════════════════════════════╗
║              测试结果总结                      ║
╚════════════════════════════════════════════════╝

测试统计：
  总测试数: 18
  通过: 18
  失败: 0
  通过率: 100.0%

🎉 所有测试通过！系统运行正常！
```

### 手动测试

#### 1. 用户注册

```bash
curl -X POST http://10.211.55.11:8082/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "Test@123",
    "email": "test@example.com"
  }'
```

#### 2. 用户登录

```bash
TOKEN=$(curl -X POST http://10.211.55.11:8082/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
  | jq -r '.data.token')
```

#### 3. 发布动态

```bash
curl -X POST http://10.211.55.11:8082/api/posts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "这是一条测试动态",
    "visibility": "public"
  }'
```

#### 4. 获取动态列表

```bash
curl http://10.211.55.11:8082/api/posts/list \
  -H "Authorization: Bearer $TOKEN"
```

#### 5. 触发数据分析

```bash
curl -X POST http://10.211.55.11:8082/api/stats/analyze \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🏗️ 架构设计

### 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                         用户浏览器                           │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    前端 (Vue 3 + Nginx)                      │
│  • 端口: 8080                                                │
│  • 反向代理到后端                                            │
│  • 上传限制: 50MB                                            │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP/REST API
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                后端 (Spring Boot 3)                          │
│  • 端口: 8082                                                │
│  • JWT 认证                                                  │
│  • 读写分离路由                                              │
│  • Spark 数据分析                                            │
└────────────────────┬────────────────────────────────────────┘
                     │ JDBC
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              openGauss 三实例集群                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  主库 (5432) │──│ 备库1 (5434) │  │ 备库2 (5436) │      │
│  │    写操作    │  │    读操作    │  │    读操作    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │               ▲                  ▲                 │
│         └───────流复制───┴──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### 技术选型理由

| 技术              | 选择理由                  |
| ----------------- | ------------------------- |
| **Spring Boot 3** | 最新企业级框架，生态完善  |
| **Vue 3**         | 组合式 API，性能优异      |
| **openGauss**     | 华为自研，兼容 PostgreSQL |
| **Docker**        | 容器化部署，环境一致性    |
| **MyBatis**       | 灵活的 SQL 映射           |
| **JWT**           | 无状态认证，适合分布式    |
| **Apache Spark**  | 大数据分析能力            |

## ❓ 常见问题

### 虚拟机服务相关

<details>
<summary><b>Q: 虚拟机服务无法启动？</b></summary>

**检查步骤**：

```bash
# 1. 查看服务状态
./status.sh vm

# 2. SSH 连接虚拟机查看日志
ssh root@10.211.55.11
cd /root/CloudCom
docker-compose -f docker-compose-opengauss-cluster-legacy.yml ps
docker logs blogcircle-backend
docker logs blogcircle-frontend

# 3. 重启服务
./stop-vm.sh
./start-vm.sh
```

</details>

<details>
<summary><b>Q: 前端显示 502 错误？</b></summary>

**原因**: 前端无法连接后端  
**解决**: 确认后端服务运行正常，容器网络连接正常

```bash
ssh root@10.211.55.11
docker exec blogcircle-frontend wget -O- http://blogcircle-backend:8080/actuator/health
```

</details>

<details>
<summary><b>Q: 图片上传失败 413 错误？</b></summary>

**原因**: 文件超过 50MB 限制  
**解决**: 压缩图片或修改 `frontend/nginx.conf` 中的 `client_max_body_size`

</details>

<details>
<summary><b>Q: 数据库连接失败？</b></summary>

**检查步骤**：

```bash
ssh root@10.211.55.11
docker exec opengauss-primary su - omm -c \
  "/usr/local/opengauss/bin/gsql -d blog_db -c 'SELECT 1;'"
```

</details>

### 本地开发相关

<details>
<summary><b>Q: Maven 构建失败？</b></summary>

确保：

- JDK 版本 = 17
- Maven 版本 >= 3.6
- 网络连接正常（需下载依赖）
</details>

<details>
<summary><b>Q: 前端启动失败？</b></summary>

```bash
cd frontend
rm -rf node_modules package-lock.json
npm install
npm run dev
```

</details>

### 更多帮助

遇到问题？

1. 查看日志文件
2. 运行测试脚本 `./test-vm-api.sh`
3. 查看健康检查 http://10.211.55.11:8082/actuator/health

---

## 📚 项目结构

```
CloudCom/
├── backend/                      # Spring Boot 后端
│   ├── src/main/java/
│   │   └── com/cloudcom/blog/
│   │       ├── controller/       # API 控制器
│   │       ├── service/          # 业务逻辑
│   │       ├── mapper/           # MyBatis 映射
│   │       ├── entity/           # 实体类
│   │       └── config/           # 配置类
│   ├── src/main/resources/
│   │   ├── application.yml       # 配置文件
│   │   ├── db/01_init.sql       # 数据库初始化
│   │   └── mapper/*.xml          # SQL 映射
│   └── pom.xml
│
├── frontend/                     # Vue 3 前端
│   ├── src/
│   │   ├── views/                # 页面组件
│   │   ├── components/           # 公共组件
│   │   ├── api/                  # API 封装
│   │   ├── stores/               # 状态管理
│   │   └── router/               # 路由配置
│   ├── nginx.conf                # Nginx 配置
│   └── package.json
│
├── docker-compose.yml                                # 本地开发配置
├── docker-compose-opengauss-cluster-legacy.yml      # 虚拟机部署配置
│
├── start-vm.sh                   # 虚拟机一键部署
├── stop-vm.sh                    # 虚拟机停止服务
├── status.sh                     # 服务状态检查
├── test-vm-api.sh               # API 自动化测试
│
└── README.md                     # 本文档
```

---

## 🎓 学习资源

### 官方文档

- [Spring Boot 文档](https://spring.io/projects/spring-boot)
- [Vue 3 文档](https://cn.vuejs.org/)
- [openGauss 文档](https://docs.opengauss.org/)
- [Docker 文档](https://docs.docker.com/)
- [MyBatis 文档](https://mybatis.org/mybatis-3/)

### 相关技术

- Element Plus UI: https://element-plus.org/
- Pinia 状态管理: https://pinia.vuejs.org/
- Apache Spark: https://spark.apache.org/

---