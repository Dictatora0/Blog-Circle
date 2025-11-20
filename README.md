# Blog Circle 课程设计说明

一个基于 Spring Boot + Vue 3 的前后端分离博客系统，采用朋友圈风格设计，支持用户管理、文章发布、评论互动、好友系统和数据统计分析。

## 一、课题概述

Blog Circle 是一个仿微信朋友圈风格的博客社交平台，面向熟人社交场景，提供用户认证、内容管理、好友关系管理和数据统计等功能。系统采用前后端分离架构，后端使用 Spring Boot 提供 RESTful API，前端使用 Vue 3 构建响应式界面。

从用户使用角度看，本系统更接近熟人社交圈的动态流式展示，而非传统按栏目和标签组织的博客网站。用户登录系统后，首先看到的是自身及好友的最新动态，可在同一时间线上完成内容发布、图片浏览、点赞和评论等操作。

后端主要围绕博客与社交业务中常见的实体进行建模，包括用户、文章、评论、好友关系以及基础统计信息。业务概念保持简洁，便于代码阅读和二次开发。大部分业务逻辑集中在清晰的 Service 分层及配套 SQL 中，适合作为 Spring Boot 与 MyBatis 组合的教学与实践案例。

前端设计围绕"朋友圈"这一核心使用场景展开，在页面数量相对有限的前提下，尽量将常用操作控制在较少的交互步骤内。界面基于 Element Plus 实现卡片式布局和弹窗交互，既便于统一风格，也为后续功能扩展和样式调整预留空间。

**新增功能**：系统现已支持 GaussDB（openGauss）数据库、Spark 分析模块，提供完整的容器化部署方案。

## 当前项目状态概览（2025-11）

- **整体完成度**

  - 后端、前端、好友系统、统计模块等核心功能均已实现，可在本地或容器环境直接运行。
  - 提供从开发环境到虚拟机部署的一整套脚本（`start.sh` / `stop.sh`、`docker-compose-start.sh` / `docker-compose-stop.sh`、`deploy-gaussdb-cluster.sh` 等），便于一键启动和回归测试。

- **数据库与集群现状**

  - 支持三种主要运行模式：
    1. **本地 / 容器 PostgreSQL 单实例**：适用于日常开发和功能调试。
    2. **外部 GaussDB 单实例**：通过 `application-gaussdb.yml` 和 `docker-compose-gaussdb-lite.yml` 连接现有 GaussDB 主库。
    3. **单机一主二备 GaussDB 集群（VM 10.211.55.11）**：
       - 由 `setup-gaussdb-single-vm-cluster.sh` 生成并在虚拟机上执行部署脚本，在同一台主机上启动 1 个主库 + 2 个备库实例（端口分别为 5432/5433/5434）。
       - 集群部署和验证过程已在 `SINGLE_VM_CLUSTER_GUIDE.md` 和 `GAUSSDB_CLUSTER_DEPLOYMENT_SUCCESS.md` 中详细记录。

- **分析与 Spark 模块**

  - `analytics` 子模块已接入 Spark，能够在 Docker Compose GaussDB 集群或外部 GaussDB 上运行统计任务。
  - 通过 `run-spark-job.sh`、`SPARK_SETUP_GUIDE.md` 可以在本地或集群环境中复现统计作业（首次拉取 Spark 镜像耗时较长属正常现象）。

- **测试与脚本现状**

  - 根目录下提供了多类测试脚本：
    - `tests/run-all-tests.sh`：汇总调用后端单元测试、API 测试和基础环境检查。
    - `test-local-services.sh`：本地环境连通性与基础功能验证。
    - `test-gaussdb-connection.sh`、`test-vm-deployment.sh`：针对 GaussDB 与虚拟机部署的连通性与服务检查。
  - 针对 **单机一主二备 GaussDB 集群**：
    - `test-gaussdb-single-vm-cluster.sh`：在本地 Mac 上，通过 Docker 化的 `psql` 尝试从外部验证 5432/5433/5434 三个实例的连接、角色和数据同步。
    - `verify-gaussdb-cluster.sh`：推荐在虚拟机上使用 `gsql` 直接验证集群状态、数据同步和只读约束，更贴近 GaussDB 官方工具链。

- **已知限制与注意事项**
  - GaussDB（openGauss）在认证协议和系统视图（如 `pg_stat_replication` 字段）上与 PostgreSQL 存在差异：
    - 使用 `postgres:15-alpine` 等标准 PostgreSQL 客户端连接 GaussDB 时，可能出现认证协议不匹配的问题，这是驱动层兼容性限制，并非业务逻辑错误。
    - 集群复制状态更多依赖 `pg_is_in_recovery()`、WAL 接收线程日志以及 GaussDB 自身的告警/日志文件进行确认。
  - 部分测试脚本假设目标环境已具备 Docker、GaussDB 客户端 (`gsql`) 等工具，实际运行前需要根据自身环境按需安装或微调脚本路径。

## 二、开发环境与技术栈

### 后端

| 技术         | 版本   | 说明              |
| ------------ | ------ | ----------------- |
| Spring Boot  | 3.1.5  | 核心框架          |
| MyBatis      | 3.0.3  | ORM 框架          |
| PostgreSQL   | 42.6.0 | 数据库驱动        |
| openGauss    | 3.0.0  | GaussDB JDBC 驱动 |
| JWT          | 0.11.5 | 身份认证          |
| Apache Spark | 3.5.0  | 数据分析（可选）  |
| Maven        | -      | 构建工具          |
| JDK          | 17     | Java 版本         |

### 前端

| 技术         | 版本  | 说明        |
| ------------ | ----- | ----------- |
| Vue          | 3.3.4 | 前端框架    |
| Element Plus | 2.4.1 | UI 组件库   |
| Vue Router   | 4.2.5 | 路由管理    |
| Pinia        | 2.1.7 | 状态管理    |
| Axios        | 1.5.0 | HTTP 客户端 |
| Vite         | 4.5.0 | 构建工具    |
| Playwright   | -     | E2E 测试    |

### 系统整体说明（服务与调用链）

从部署架构的角度看，系统主要由以下三个服务组成：

- 后端服务：Spring Boot 应用。
  - 开发环境：直接运行 `mvn spring-boot:run`，监听 `localhost:8080`。
  - Docker Compose 环境：容器内部端口为 8080，通过 `docker-compose.yml` 映射到宿主机 `8081`（`8081:8080`）。
- 前端服务：Vue 3 + Vite + Nginx。
  - 开发环境：Vite 开发服务器默认运行在 `localhost:5173`。
  - 生产环境：构建后的静态文件由 Nginx 提供，对外端口为 `8080`。
- 数据库服务：PostgreSQL 15 容器。
  - 容器端口为 `5432`，在 docker-compose 中映射为宿主机 `5432`。
  - 当前项目没有使用 Redis，所有状态直接存数据库，登录态通过 JWT 保存在前端。

服务之间的通信关系如下：

- 前端通过 HTTP 调用后端提供的 REST API。
  - 开发环境下，`vite.config.js` 把 `/api` 前缀代理到 `http://localhost:8080`。
  - 生产环境下，Nginx 把前端页面和 `/api` 转发规则写在同一个 `nginx.conf` 中，请求会被转发到后端容器。
- 后端通过 JDBC 连接数据库。
  - 本地开发使用 `jdbc:postgresql://localhost:5432/blog_db`。
  - Docker Compose 环境下通过服务名 `db` 访问：`jdbc:postgresql://db:5432/blog_db`。
  - 连接信息通过 `application-docker.yml` 和 `docker-compose.yml` 中的环境变量传入。

前端调用 API 的方式是：

- 在 `frontend/src/utils/request.js` 中统一创建了一个 Axios 实例：
  - `baseURL` 来自环境变量 `VITE_API_BASE_URL`，没有配置时默认是 `/api`。
  - 在请求拦截器里，如果本地有 Token，就自动加上 `Authorization: Bearer <token>` 请求头。
- 业务代码不会直接拼 URL，而是通过 `src/api/` 目录下封装好的函数调用，例如文章、评论、好友等模块各有对应的 API 文件。

后端 API 大致分为：

- 认证相关：`/api/auth/register`、`/api/auth/login`。
- 文章相关：`/api/posts` 系列，包括列表、详情、创建、修改、删除、好友时间线等。
- 评论相关：`/api/comments` 系列，包括按文章查询评论、新增、编辑、删除等。
- 好友相关：`/api/friends` 系列，包括发送/接受/拒绝好友请求、好友列表、搜索用户、查看好友关系等。
- 统计相关：`/api/stats` 系列，用于触发统计任务和查询统计结果。
- 上传相关：用于头像、封面图和文章图片上传，底层统一落到服务器本地 `uploads` 目录。

数据库表结构包含了社交博客场景中最常用的几张表：

- `users`：保存用户账号、昵称、头像、封面等基本信息。
- `posts`：保存每一条动态/文章的标题、内容、作者、浏览量以及创建时间。
- `comments`：保存评论内容、关联的文章以及评论人信息。
- `friendship`：保存好友关系以及好友请求的状态（待处理、已通过、已拒绝）。
- `likes`：保存用户对文章的点赞记录，用联合唯一索引保证同一用户不会重复点赞同一篇文章。
- `access_logs`：记录访问日志，为后续统计分析提供数据来源。
- `statistics`：缓存统计结果，减少重复计算。

Docker 相关的打包和部署方式：

- 后端 `backend/Dockerfile` 使用多阶段构建：
  - 第一阶段基于 `maven:3.8.7-eclipse-temurin-17`，下载依赖并打包 Spring Boot 可执行 JAR。
  - 第二阶段基于 `eclipse-temurin:17-jre`，只拷贝构建好的 JAR，并创建 `/app/uploads` 目录，用来存用户上传的图片。
  - 入口命令为 `java -jar app.jar`；具体使用哪个 profile（如 `docker`、`gaussdb` 或 `gaussdb-cluster`）由外部的 `SPRING_PROFILES_ACTIVE` 或配置文件决定。
- 前端 `frontend/Dockerfile` 同样是多阶段：
  - 第一阶段基于 `node:18-alpine`，安装依赖并执行 `npm run build` 生成静态文件。
  - 第二阶段基于 `nginx:alpine`，只负责托管 `dist/` 目录，并通过 `nginx.conf` 做反向代理。

项目提供了多个 docker-compose 配置文件：

**标准部署（PostgreSQL）**：`docker-compose.yml`

- `db` 服务运行 PostgreSQL，负责持久化所有业务数据，并挂载卷保存数据文件。
- `backend` 服务从 `backend/Dockerfile` 构建，依赖 `db`，通过环境变量连接数据库，对外暴露端口 `8081`。
- `frontend` 服务从 `frontend/Dockerfile` 构建，依赖 `backend`，对外暴露端口 `8080`。
- 三个服务都在同一个自定义网络 `blogcircle-network` 中，后端直接通过服务名 `db` 访问数据库。

**完整部署（GaussDB + Spark 集成）**：`docker-compose-gaussdb.yml`

- 该配置假定 GaussDB 集群已在虚拟机 `10.211.55.11` 上按 `SINGLE_VM_CLUSTER_GUIDE.md` 部署完成，不在 compose 内单独启动数据库容器。
- `backend` 服务从 `backend/Dockerfile` 构建，使用 `gaussdb-cluster` profile（`application-gaussdb-cluster.yml`），并通过环境变量 `GAUSSDB_PRIMARY_URL/GAUSSDB_USERNAME/GAUSSDB_PASSWORD` 连接外部 GaussDB 集群。
- `spark-master` 和 `spark-worker` 服务提供 Spark 分析集群。
- 所有服务（backend / frontend / spark-master / spark-worker）在同一网络中，构成 Web + 分析容器栈，对接外部 GaussDB。

## 三、系统功能与特点

### 核心功能

- **用户认证**：注册、登录、JWT 鉴权
- **用户管理**：个人信息、头像上传、个人主页
- **文章系统**：发布、编辑、删除、浏览、查看详情
- **评论系统**：发表、编辑、删除评论
- **点赞功能**：文章点赞与取消
- **好友系统**：搜索用户、添加好友、管理好友关系、查看好友动态时间线
- **数据统计**：用户发文统计、文章浏览统计、评论统计（SQL 分析，支持 Spark）
- **GaussDB 支持**：完整的 openGauss/GaussDB 适配，支持国产数据库
- **Spark 分析**：独立 Spark 分析模块，支持大规模数据处理

### 设计特色

- 采用类朋友圈风格的界面布局，突出时间线展示。
- 支持响应式布局，兼顾桌面端与移动端访问。
- 提供统一的页面过渡和交互反馈，提升操作连贯性。
- 在关键操作节点提供即时提示，降低误操作风险。

## 四、系统运行环境与部署准备

### 必需环境

- **Java**: 17+
- **Maven**: 3.6+
- **PostgreSQL**: 14+（或 GaussDB）
- **Node.js**: 18+

### 安装步骤

#### macOS

```bash
# 安装 Java 17
brew install openjdk@17

# 安装 Maven
brew install maven

# 安装 PostgreSQL
brew install postgresql@14
brew services start postgresql@14

# 安装 Node.js
brew install node
```

#### 验证安装

```bash
java -version
mvn -version
node --version
npm --version
psql --version
```

## 五、系统启动与运行说明

### 快速开始

**最简单的方式**：本地开发环境

```bash
# 启动本地开发环境（PostgreSQL + Spring Boot + Vite）
./docker-compose-start.sh dev

# 访问应用
# 前端: http://localhost:5173
# 后端: http://localhost:8080

# 停止服务
./docker-compose-stop.sh dev
```

### 一键启动（推荐）

#### 方式 1：本地开发

1. **配置数据库**

编辑 `backend/src/main/resources/application.yml`：

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/blog_db
    username: your_username # 修改为实际的数据库用户名
    password: your_password # 修改为实际的数据库密码
```

2. **启动服务**

```bash
# 一键启动前后端（自动创建数据库和初始化表）
./start.sh
```

3. **访问系统**

- 前端地址：http://localhost:5173
- 后端地址：http://localhost:8080

4. **停止服务**

```bash
./stop.sh
```

#### 方式 2：Docker Compose（PostgreSQL）

```bash
# 启动所有服务
docker-compose up -d

# 访问应用
# 前端: http://localhost:8080
# 后端: http://localhost:8081

# 停止服务
docker-compose down
```

#### 方式 3：Docker Compose（连接现有 GaussDB 主库 + Spark）

适用于宿主环境已部署 GaussDB 集群，仅需启动前后端与 Spark。

```bash
export GAUSSDB_HOST=10.211.55.11
export GAUSSDB_PORT=5432
export GAUSSDB_USERNAME=bloguser
export GAUSSDB_PASSWORD=747599qw@

docker compose -f docker-compose-gaussdb.yml up -d

# 前端: http://localhost:8080
# 后端: http://localhost:8081
# Spark Master UI: http://localhost:8888

docker compose -f docker-compose-gaussdb.yml down
```

**注意**：Spark 镜像较大（~1GB），首次拉取可能需要较长时间。如果拉取失败，请参考 [SPARK_SETUP_GUIDE.md](./SPARK_SETUP_GUIDE.md)。

#### 方式 3b：Docker Compose（连接现有 GaussDB，仅前后端）

```bash
export GAUSSDB_HOST=10.211.55.11
export GAUSSDB_PORT=5432
export GAUSSDB_USERNAME=bloguser
export GAUSSDB_PASSWORD=blogpass

docker compose -f docker-compose-gaussdb-lite.yml up -d

# 前端: http://localhost:8080
# 后端: http://localhost:8081

docker compose -f docker-compose-gaussdb-lite.yml down
```

该配置以现有 GaussDB 主库为中心，快速启动应用但不包含 Spark 服务。

### 手动启动

#### 数据库初始化

```bash
# 创建数据库
createdb blog_db

# 执行初始化脚本
psql -U your_username -d blog_db -f backend/src/main/resources/db/init.sql

# 创建好友关系表（好友系统）
psql -U your_username -d blog_db -f backend/src/main/resources/db/friendship.sql
```

#### 启动后端

```bash
cd backend
mvn spring-boot:run
```

#### 启动前端

```bash
cd frontend
npm install
npm run dev
```

### 容器化部署脚本（docker-compose-start.sh / docker-compose-stop.sh）

项目提供了统一的容器化部署脚本，支持本地开发环境和容器化环境的一键管理。

### 新增功能

#### docker-compose-start.sh 新增 dev 模式

- **用途**：启动本地开发环境（PostgreSQL + Spring Boot + Vite）
- **命令**：`./docker-compose-start.sh dev`
- **功能**：自动调用现有的 `./start.sh` 脚本

#### docker-compose-stop.sh 新增 dev 模式

- **用途**：停止本地开发环境（PostgreSQL + Spring Boot + Vite）
- **命令**：`./docker-compose-stop.sh dev`
- **功能**：自动调用现有的 `./stop.sh` 脚本

### 使用方式总结

| 环境类型     | 启动命令                        | 停止命令                       | 说明                            |
| ------------ | ------------------------------- | ------------------------------ | ------------------------------- |
| 本地开发环境 | `./docker-compose-start.sh dev` | `./docker-compose-stop.sh dev` | PostgreSQL + Spring Boot + Vite |
| 虚拟机部署   | `./docker-compose-start.sh vm`  | `./docker-compose-stop.sh vm`  | 容器化部署到虚拟机 10.211.55.11 |

### 本地开发

```bash
./docker-compose-start.sh dev    # 启动本地开发环境
./docker-compose-stop.sh dev     # 停止本地开发环境
```

### 虚拟机部署

```bash
./docker-compose-start.sh vm     # 部署到虚拟机
./docker-compose-stop.sh vm      # 停止虚拟机服务
```

### 技术实现

- **依赖检查**：自动验证所需命令（如 `psql`、`mvn`、`npm` 等）
- **错误处理**：使用 `set -euo pipefail` 并配合彩色日志输出
- **兼容性**：在保留原有脚本功能的基础上，通过模式参数扩展不同场景
- **环境变量**：支持通过环境变量覆盖远程服务器地址、用户名等参数

典型使用场景如下：

- **本地开发阶段**：通过 `./docker-compose-start.sh dev` 启动本地开发环境，对应使用 `./docker-compose-stop.sh dev` 进行停止。适合开发调试阶段。
- **虚拟机部署阶段**：通过 `./docker-compose-start.sh vm` 进行容器化部署到虚拟机 10.211.55.11，对应使用 `./docker-compose-stop.sh vm` 停止服务。适合生产测试或演示环境。

## 六、测试账号与角色说明

| 用户名 | 密码     | 说明       |
| ------ | -------- | ---------- |
| admin  | admin123 | 管理员账号 |
| user1  | user123  | 普通用户   |

也可通过注册页面创建新账号。

## 七、配置说明

### 后端配置

文件：`backend/src/main/resources/application.yml`

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/blog_db
    username: your_username
    password: your_password

jwt:
  secret: your-secret-key # 生产环境请使用强随机字符串
  expiration: 86400000 # Token 有效期（24小时）

spark:
  enabled: false # Spark 分析开关（Java 17+ 环境下建议禁用）
```

### 前端配置

文件：`frontend/src/utils/request.js`

```javascript
const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "/api",
  timeout: 10000,
});
```

## 八、功能模块设计

### 1. 用户认证

- **注册**：填写用户名、密码、邮箱、昵称
- **登录**：JWT Token 认证
- **个人信息**：修改昵称、头像、封面图

### 2. 文章管理

- **发布文章**：标题、内容、图片上传（九宫格）
- **编辑/删除**：作者可管理自己的文章
- **浏览统计**：自动记录文章浏览次数

### 3. 评论互动

- **发表评论**：登录用户可对文章发表评论
- **编辑/删除**：作者可管理自己的评论
- **评论列表**：查看文章下所有评论

### 4. 好友系统

- **搜索用户**：通过用户名、邮箱或昵称搜索
- **添加好友**：发送好友请求 → 对方同意 → 成为好友
- **好友管理**：查看好友列表、处理待处理请求、删除好友
- **好友动态**：查看自己和所有好友的最新动态时间线

### 5. 数据统计

- **SQL 分析**：默认使用 SQL 进行数据分析
- **统计维度**：用户发文、文章浏览、评论数量
- **可视化展示**：图表形式展示统计结果

## 九、部分接口示例

### 认证接口

#### 用户注册

```http
POST /api/auth/register
Content-Type: application/json

{
  "username": "string",
  "password": "string",
  "email": "string",
  "nickname": "string"
}
```

#### 用户登录

```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "string",
  "password": "string"
}

Response:
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "user": { ... }
  }
}
```

### 文章接口

| 方法   | 路径                     | 说明           | 需要认证 |
| ------ | ------------------------ | -------------- | -------- |
| GET    | `/api/posts/list`        | 获取文章列表   | 否       |
| GET    | `/api/posts/{id}/detail` | 获取文章详情   | 否       |
| POST   | `/api/posts`             | 创建文章       | 是       |
| PUT    | `/api/posts/{id}`        | 更新文章       | 是       |
| DELETE | `/api/posts/{id}`        | 删除文章       | 是       |
| GET    | `/api/posts/timeline`    | 获取好友时间线 | 是       |

### 评论接口

| 方法   | 路径                          | 说明         | 需要认证 |
| ------ | ----------------------------- | ------------ | -------- |
| GET    | `/api/comments/post/{postId}` | 获取文章评论 | 否       |
| POST   | `/api/comments`               | 创建评论     | 是       |
| PUT    | `/api/comments/{id}`          | 更新评论     | 是       |
| DELETE | `/api/comments/{id}`          | 删除评论     | 是       |

### 好友接口

| 方法   | 路径                                | 说明           | 需要认证 |
| ------ | ----------------------------------- | -------------- | -------- |
| POST   | `/api/friends/request/{receiverId}` | 发送好友请求   | 是       |
| POST   | `/api/friends/accept/{requestId}`   | 接受好友请求   | 是       |
| POST   | `/api/friends/reject/{requestId}`   | 拒绝好友请求   | 是       |
| DELETE | `/api/friends/user/{friendUserId}`  | 删除好友       | 是       |
| GET    | `/api/friends/list`                 | 获取好友列表   | 是       |
| GET    | `/api/friends/requests`             | 获取待处理请求 | 是       |
| GET    | `/api/friends/search?keyword=xxx`   | 搜索用户       | 是       |
| GET    | `/api/friends/status/{userId}`      | 检查好友状态   | 是       |

### 统计接口

| 方法 | 路径                 | 说明             | 需要认证 |
| ---- | -------------------- | ---------------- | -------- |
| POST | `/api/stats/analyze` | 运行数据分析     | 是       |
| GET  | `/api/stats`         | 获取所有统计数据 | 是       |
| GET  | `/api/stats/{type}`  | 获取指定类型统计 | 是       |

**说明**：所有需要认证的接口需在请求头中携带 `Authorization: Bearer {token}`

## 十、数据库表结构设计

### users（用户表）

- `id`: 主键
- `username`: 用户名（唯一）
- `password`: 密码（加密存储）
- `email`: 邮箱
- `nickname`: 昵称
- `avatar`: 头像路径
- `cover_image`: 封面图路径
- `created_at`: 创建时间
- `updated_at`: 更新时间

### posts（文章表）

- `id`: 主键
- `title`: 标题
- `content`: 内容
- `author_id`: 作者 ID（外键）
- `view_count`: 浏览次数
- `created_at`: 创建时间
- `updated_at`: 更新时间

### friendship（好友关系表）

- `id`: 主键
- `requester_id`: 发起方用户 ID
- `receiver_id`: 接收方用户 ID
- `status`: 状态（PENDING/ACCEPTED/REJECTED）
- `created_at`: 创建时间

### comments（评论表）

- `id`: 主键
- `post_id`: 文章 ID（外键）
- `user_id`: 用户 ID（外键）
- `content`: 内容
- `created_at`: 创建时间

### likes（点赞表）

- `id`: 主键
- `post_id`: 文章 ID（外键）
- `user_id`: 用户 ID（外键）
- `created_at`: 创建时间

### access_logs（访问日志表）

- `id`: 主键
- `user_id`: 用户 ID
- `post_id`: 文章 ID
- `action`: 操作类型
- `created_at`: 创建时间

### statistics（统计结果表）

- `id`: 主键
- `stat_type`: 统计类型
- `stat_key`: 统计键
- `stat_value`: 统计值
- `created_at`: 创建时间
- `updated_at`: 更新时间

## 十一、系统测试

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

# E2E 测试（需先启动开发服务器）
npm run dev  # 终端1
npm run test:e2e  # 终端2
```

## 十二、常见问题与解决思路

### 后端启动失败

**问题**：数据库连接失败

**解决方案**：

1. 确认 PostgreSQL 服务已启动：`brew services list`
2. 检查数据库配置是否正确
3. 确认数据库 `blog_db` 已创建：`psql -l | grep blog_db`
4. 查看日志：`logs/backend.log`

### 前端无法连接后端

**问题**：API 请求失败或跨域错误

**解决方案**：

1. 确认后端运行在 8080 端口
2. 检查前端配置中的 `baseURL` 是否正确
3. 确认后端已配置 CORS

### 好友请求发送失败

**问题**：发送好友请求时提示失败

**解决方案**：

1. 确认已登录并携带有效 Token
2. 检查目标用户是否存在
3. 查看浏览器控制台错误信息
4. 确认好友关系表已创建

### Token 过期

**问题**：操作时提示 Token 过期

**解决方案**：

1. 重新登录获取新 Token
2. Token 默认有效期为 24 小时

### GaussDB 单机一主二备集群常见问题

#### 问题 1：端口冲突（5432/5433/5434）

**症状**：启动主库或备库时提示端口已被占用。

**解决**：

```bash
# 检查端口占用
netstat -tlnp | grep -E '5432|5433|5434'

# 停止占用端口的进程（确认 PID 正确后再执行）
kill -9 <PID>
```

#### 问题 2：数据目录权限错误

**症状**：`gs_ctl` 或 `gaussdb` 启动失败，报权限不足。

**解决**：

```bash
OMM_GROUP=$(id -gn omm)
chown -R omm:$OMM_GROUP /usr/local/opengauss/data_*
chmod 700 /usr/local/opengauss/data_*
```

#### 问题 3：备库未建立复制

**症状**：备库已启动并且 `pg_is_in_recovery() = t`，但主库 `pg_stat_replication` 为空，或者在备库查询业务表时报 “relation 不存在”。

**排查步骤**：

```bash
# 检查备库日志
tail -f /usr/local/opengauss/data_standby1/pg_log/*.log

# 检查 standby.signal / recovery.conf 是否存在
ls -la /usr/local/opengauss/data_standby1/standby.signal
ls -la /usr/local/opengauss/data_standby1/recovery.conf

# 检查复制连接配置
cat /usr/local/opengauss/data_standby1/recovery.conf
```

> 更完整的单机一主二备集群部署与排障说明，可参考 `SINGLE_VM_CLUSTER_GUIDE.md` 和 `GAUSSDB_CLUSTER_DEPLOYMENT_SUCCESS.md`，但以本 README 为入口文档。

## 十三、项目工程结构

```
CloudCom/
├── backend/                    # 后端项目
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/          # Java 源码
│   │   │   └── resources/    # 配置文件、SQL 脚本
│   │   └── test/             # 测试代码
│   └── pom.xml
├── frontend/                   # 前端项目
│   ├── src/
│   │   ├── api/              # API 接口封装
│   │   ├── components/       # 公共组件
│   │   ├── views/           # 页面组件
│   │   ├── router/          # 路由配置
│   │   ├── stores/         # 状态管理
│   │   └── utils/          # 工具函数
│   ├── tests/              # 测试文件
│   └── package.json
├── logs/                    # 日志文件
├── start.sh                # 启动脚本
├── stop.sh                 # 停止脚本
└── README.md               # 项目文档
```

## 十四、开发与维护说明

### 后端开发

1. 使用 IntelliJ IDEA 或 Eclipse 导入 Maven 项目
2. 配置 JDK 17
3. 运行 `BlogApplication.java` 启动应用
4. 新增功能遵循 Controller → Service → Mapper 分层架构

### 前端开发

1. 使用 VS Code 或 WebStorm 打开项目
2. 安装推荐插件：Volar、ESLint
3. 组件开发遵循 Vue 3 Composition API 风格
4. API 调用统一通过 `src/api/` 目录封装

### 代码规范

- **后端**：遵循 Spring Boot 官方规范，使用 Lombok 简化代码
- **前端**：遵循 Vue 3 官方风格指南，使用 ESLint 检查

## 十五、生产部署建议

### 后端部署

```bash
# 打包
cd backend
mvn clean package -DskipTests

# 运行
java -jar target/blog-system-1.0.0.jar

# 或使用 systemd 管理服务
sudo systemctl start blog-system
```

### 前端部署

```bash
# 构建生产版本
cd frontend
npm run build

# 部署 dist/ 目录到 Nginx 或其他静态服务器
# 配置反向代理指向后端 API
```

## 十六、安全与运维建议

1. 修改 JWT 密钥为强随机字符串
2. 启用 HTTPS
3. 配置防火墙规则
4. 添加请求频率限制
5. 定期备份数据库

## 十七、使用范围说明

本项目仅供学习和研究使用。

## 十八、参考文档

- Spring Boot 文档：https://spring.io/projects/spring-boot
- Vue 3 文档：https://cn.vuejs.org/
- Element Plus 文档：https://element-plus.org/
- MyBatis 文档：https://mybatis.org/mybatis-3/

## 文档与脚本索引（当前状态）

- **README.md**：项目主入口文档，优先以此为准，涵盖总体架构、运行方式、GaussDB 单机一主二备集群现状及常见问题排查。
- **SINGLE_VM_CLUSTER_GUIDE.md**：GaussDB 单机一主二备集群的详细部署步骤和背景说明，关键信息已合并到 README，可作为补充阅读材料。
- **GAUSSDB_CLUSTER_DEPLOYMENT_SUCCESS.md**：单机一主二备集群在 VM `10.211.55.11` 上的实际部署结果与参数快照，用于记录当前环境状态。
- **DEPLOYMENT_GUIDE.md**：整体部署流程与注意事项，部分内容与 README 重叠，后续以 README 为最新权威说明。
- **DOCKER_REFERENCE.md**：各类 Docker / Docker Compose 配置的补充说明，适合需要深入了解容器化细节时查阅。
- **SPARK_SETUP_GUIDE.md**：Spark 环境准备与运行说明，仅在需要运行 `analytics` 模块的 Spark 统计任务时参考。
- 其他以 `*_GUIDE.md`、`*_SUMMARY.md`、`*_COMPLETE*.md` 等命名的文档，多为阶段性总结或历史交付记录，内部信息已逐步并入 README，可视为存档，不再单独更新。

---
