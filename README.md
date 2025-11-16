# Blog Circle 课程设计说明

本说明文档主要面向课程设计或毕业设计评审，整体介绍 Blog Circle 系统的设计思路、实现过程和测试情况。

一个基于 Spring Boot + Vue 3 的前后端分离博客系统，采用朋友圈风格设计，支持用户管理、文章发布、评论互动、好友系统和数据统计分析。

## 一、课题概述

Blog Circle 是一个仿微信朋友圈风格的博客社交平台，面向熟人社交场景，提供用户认证、内容管理、好友关系管理和数据统计等功能。系统采用前后端分离架构，后端使用 Spring Boot 提供 RESTful API，前端使用 Vue 3 构建响应式界面。

从用户使用角度看，本系统更接近熟人社交圈的动态流式展示，而非传统按栏目和标签组织的博客网站。用户登录系统后，首先看到的是自身及好友的最新动态，可在同一时间线上完成内容发布、图片浏览、点赞和评论等操作。

后端主要围绕博客与社交业务中常见的实体进行建模，包括用户、文章、评论、好友关系以及基础统计信息。业务概念保持简洁，便于代码阅读和二次开发。大部分业务逻辑集中在清晰的 Service 分层及配套 SQL 中，适合作为 Spring Boot 与 MyBatis 组合的教学与实践案例。

前端设计围绕“朋友圈”这一核心使用场景展开，在页面数量相对有限的前提下，尽量将常用操作控制在较少的交互步骤内。界面基于 Element Plus 实现卡片式布局和弹窗交互，既便于统一风格，也为后续功能扩展和样式调整预留空间。

## 二、开发环境与技术栈

### 后端

| 技术         | 版本   | 说明                   |
| ------------ | ------ | ---------------------- |
| Spring Boot  | 3.1.5  | 核心框架               |
| MyBatis      | 3.0.3  | ORM 框架               |
| PostgreSQL   | 42.6.0 | 数据库（兼容 GaussDB） |
| JWT          | 0.11.5 | 身份认证               |
| Apache Spark | 3.5.0  | 数据分析（可选）       |
| Maven        | -      | 构建工具               |
| JDK          | 17     | Java 版本              |

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

后端 API 大致分为几类：

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
  - 第二阶段基于 `openjdk:17-jdk`，只拷贝构建好的 JAR，并创建 `/app/uploads` 目录，用来存用户上传的图片。
  - 入口命令是 `java -jar app.jar --spring.profiles.active=docker`，使用 `application-docker.yml` 里的配置。
- 前端 `frontend/Dockerfile` 同样是多阶段：
  - 第一阶段基于 `node:18-alpine`，安装依赖并执行 `npm run build` 生成静态文件。
  - 第二阶段基于 `nginx:alpine`，只负责托管 `dist/` 目录，并通过 `nginx.conf` 做反向代理。

项目提供了 `docker-compose.yml` 用于一键启动：

- `db` 服务运行 PostgreSQL，负责持久化所有业务数据，并挂载卷保存数据文件。
- `backend` 服务从 `backend/Dockerfile` 构建，依赖 `db`，通过环境变量连接数据库，对外暴露端口 `8081`。
- `frontend` 服务从 `frontend/Dockerfile` 构建，依赖 `backend`，对外暴露端口 `8080`。
- 三个服务都在同一个自定义网络 `blogcircle-network` 中，后端直接通过服务名 `db` 访问数据库。

## 三、系统功能与特点

### 核心功能

- **用户认证**：注册、登录、JWT 鉴权
- **用户管理**：个人信息、头像上传、个人主页
- **文章系统**：发布、编辑、删除、浏览、查看详情
- **评论系统**：发表、编辑、删除评论
- **点赞功能**：文章点赞与取消
- **好友系统**：搜索用户、添加好友、管理好友关系、查看好友动态时间线
- **数据统计**：用户发文统计、文章浏览统计、评论统计（SQL 分析，可选 Spark）

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

### 一键启动（推荐）

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

### comments（评论表）

- `id`: 主键
- `post_id`: 文章 ID（外键）
- `user_id`: 用户 ID（外键）
- `content`: 内容
- `created_at`: 创建时间

### friendship（好友关系表）

- `id`: 主键
- `requester_id`: 发起方用户 ID
- `receiver_id`: 接收方用户 ID
- `status`: 状态（PENDING/ACCEPTED/REJECTED）
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

---

## 附录：实验报告（详细版）

### 一、项目概述

#### 1.1 项目背景

Blog Circle 是一个基于 Spring Boot 和 Vue 3 的前后端分离博客社交系统，采用仿微信朋友圈的设计风格。项目旨在构建一个功能完整的社交博客平台，支持用户注册登录、文章发布、评论互动、好友关系管理和数据统计分析等核心功能。

#### 1.2 项目目标

- **技术目标**：掌握前后端分离架构设计，熟练使用 Spring Boot 和 Vue 3 进行全栈开发
- **功能目标**：实现完整的用户认证、内容管理、社交互动和数据分析功能
- **学习目标**：深入理解 RESTful API 设计、JWT 认证机制、数据库设计和状态管理

#### 1.3 项目特色

1. **朋友圈风格设计**：仿微信朋友圈的 UI/UX 设计，提供熟悉的用户体验
2. **完整的好友系统**：支持好友请求、接受/拒绝、好友列表管理和时间线功能
3. **数据统计分析**：提供 SQL 和 Spark 两种数据分析方案
4. **前后端分离**：清晰的 API 接口设计，便于扩展和维护

### 二、系统架构设计

#### 2.1 整体架构

系统采用经典的前后端分离架构：

```
┌─────────────────┐         HTTP/REST API         ┌─────────────────┐
│                 │ ◄──────────────────────────► │                 │
│   Vue 3 前端     │         JWT Token             │  Spring Boot    │
│   (Port 5173)   │                                │  后端 (8080)    │
│                 │                                │                 │
└─────────────────┘                                └────────┬────────┘
                                                             │
                                                             │ JDBC
                                                             ▼
                                                    ┌─────────────────┐
                                                    │   PostgreSQL    │
                                                    │   数据库        │
                                                    └─────────────────┘
```

#### 2.2 后端架构设计

后端采用经典的三层架构模式：

**1. Controller 层（控制层）**

- 职责：接收 HTTP 请求，参数验证，调用 Service 层，返回统一响应格式
- 关键类：
  - `AuthController`：处理用户注册、登录
  - `PostController`：处理文章 CRUD 操作和时间线查询
  - `CommentController`：处理评论相关操作
  - `FriendshipController`：处理好友关系管理
  - `StatisticsController`：处理数据统计分析

**2. Service 层（业务逻辑层）**

- 职责：实现业务逻辑，事务管理，数据校验
- 关键类：
  - `UserService`：用户注册、登录、信息管理
  - `PostService`：文章发布、编辑、删除、时间线查询
  - `FriendshipService`：好友请求发送、接受、拒绝、删除
  - `CommentService`：评论的增删改查
  - `SparkAnalyticsService`：数据统计分析

**3. Mapper 层（数据访问层）**

- 职责：数据库操作，SQL 映射
- 技术：MyBatis 3.0.3
- 关键接口：
  - `UserMapper`、`PostMapper`、`CommentMapper`、`FriendshipMapper`

#### 2.3 前端架构设计

前端采用 Vue 3 Composition API + Pinia 状态管理：

**1. 视图层（Views）**

- `Login.vue`、`Register.vue`：用户认证页面
- `Home.vue`：首页，展示所有文章
- `Timeline.vue`：好友时间线，展示自己和好友的动态
- `Publish.vue`：发布文章页面
- `Profile.vue`：个人资料页面
- `Friends.vue`：好友管理页面
- `Statistics.vue`：数据统计页面

**2. 状态管理（Stores）**

- `user.js`：管理用户登录状态、Token、用户信息

**3. API 封装层**

- `auth.js`：认证相关 API
- `post.js`：文章相关 API
- `comment.js`：评论相关 API
- `friends.js`：好友相关 API
- `statistics.js`：统计相关 API

**4. 路由管理**

- 使用 Vue Router 4.2.5 进行路由管理
- 实现路由守卫，保护需要认证的页面

### 三、核心技术实现

#### 3.1 JWT 认证机制

**实现原理**：

1. **Token 生成**（`JwtUtil.java`）：

```java
public String generateToken(Long userId, String username) {
    Map<String, Object> claims = new HashMap<>();
    claims.put("userId", userId);
    claims.put("username", username);

    return Jwts.builder()
            .setClaims(claims)
            .setSubject(username)
            .setIssuedAt(new Date())
            .setExpiration(new Date(System.currentTimeMillis() + expiration))
            .signWith(getSignKey())
            .compact();
}
```

2. **Token 验证**（`JwtInterceptor.java`）：

   - 拦截所有需要认证的请求
   - 从请求头中提取 `Authorization: Bearer {token}`
   - 验证 Token 有效性和过期时间
   - 将用户 ID 存入请求属性，供后续使用

3. **配置**（`WebConfig.java`）：
   - 配置拦截器，排除登录、注册等公开接口
   - 设置 CORS 跨域支持

**安全特性**：

- Token 有效期：24 小时
- 使用 HMAC-SHA256 算法签名
- 密码使用 BCrypt 加密存储

#### 3.2 好友系统实现

**数据库设计**：

`friendship` 表结构：

- `id`：主键
- `requester_id`：发起方用户 ID
- `receiver_id`：接收方用户 ID
- `status`：状态（PENDING/ACCEPTED/REJECTED）
- `created_at`：创建时间

**核心业务逻辑**（`FriendshipService.java`）：

1. **发送好友请求**：

   - 验证不能添加自己为好友
   - 检查是否已存在好友关系
   - 如果之前被拒绝，允许重新发送并更新状态为 PENDING
   - 创建新的好友请求记录

2. **接受/拒绝请求**：

   - 验证当前用户是接收方
   - 验证请求状态为 PENDING
   - 更新状态为 ACCEPTED 或 REJECTED

3. **好友时间线查询**：
   - 获取当前用户的所有好友 ID
   - 查询自己和所有好友发布的文章
   - 按创建时间倒序排列

**关键代码片段**：

```java
public List<Post> getFriendTimeline(Long userId) {
    // 获取所有好友ID
    List<Long> friendIds = friendshipMapper.selectFriendIdsByUserId(userId);

    // 添加自己的ID
    List<Long> userIds = new ArrayList<>();
    userIds.add(userId);
    if (friendIds != null && !friendIds.isEmpty()) {
        userIds.addAll(friendIds);
    }

    // 查询这些用户的动态
    return postMapper.selectFriendTimeline(userIds);
}
```

#### 3.3 跨域（CORS）配置

**实现方式**（`CorsConfig.java`）：

使用 Spring 的 `CorsFilter` 实现跨域支持：

```java
@Bean
public CorsFilter corsFilter() {
    CorsConfiguration config = new CorsConfiguration();

    // 开发环境允许所有来源
    config.setAllowedOriginPatterns(Collections.singletonList("*"));

    // 允许携带认证信息
    config.setAllowCredentials(true);

    // 允许所有请求头和方法
    config.setAllowedHeaders(Collections.singletonList("*"));
    config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));

    // 注册到所有路径
    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);

    return new CorsFilter(source);
}
```

**配置要点**：

- 开发环境允许所有来源，生产环境应限制特定域名
- 支持携带认证信息（`setAllowCredentials(true)`）
- 预检请求缓存时间：3600 秒

#### 3.4 文件上传功能

**后端实现**（`UploadController.java`）：

- 支持图片上传（头像、封面图、文章图片）
- 文件大小限制：单文件 10MB，总请求 50MB
- 文件存储路径：`./uploads`
- 返回文件访问 URL

**前端实现**：

- 使用 Element Plus 的 `el-upload` 组件
- 支持多图片上传（九宫格）
- 图片预览功能

#### 3.5 数据统计分析

**实现方案**：

1. **SQL 分析方案**（默认）：

   - 使用 PostgreSQL 的聚合函数进行统计
   - 统计维度：用户发文数、文章浏览数、点赞数、评论数
   - 性能优化：使用索引和聚合查询

2. **Spark 分析方案**（可选）：
   - 集成 Apache Spark 3.5.0
   - 支持大数据量分析
   - 注意：Java 17+ 环境下可能存在兼容性问题，默认禁用

**统计接口**：

- `POST /api/stats/analyze`：触发数据分析
- `GET /api/stats`：获取所有统计数据
- `GET /api/stats/{type}`：获取指定类型统计

### 四、数据库设计

#### 4.1 数据库选型

选择 **PostgreSQL 14+** 作为主数据库，原因：

- 功能强大，支持复杂查询
- 兼容 GaussDB（国产数据库）
- 性能优秀，适合生产环境
- 支持 JSON 数据类型（未来扩展）

#### 4.2 核心表结构

**1. users（用户表）**

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    nickname VARCHAR(50),
    avatar VARCHAR(255),
    cover_image VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**2. posts（文章表）**

```sql
CREATE TABLE posts (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    author_id BIGINT REFERENCES users(id),
    view_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**3. friendship（好友关系表）**

```sql
CREATE TABLE friendship (
    id BIGSERIAL PRIMARY KEY,
    requester_id BIGINT REFERENCES users(id),
    receiver_id BIGINT REFERENCES users(id),
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(requester_id, receiver_id)
);
```

**4. comments（评论表）**

```sql
CREATE TABLE comments (
    id BIGSERIAL PRIMARY KEY,
    post_id BIGINT REFERENCES posts(id),
    user_id BIGINT REFERENCES users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**5. likes（点赞表）**

```sql
CREATE TABLE likes (
    id BIGSERIAL PRIMARY KEY,
    post_id BIGINT REFERENCES posts(id),
    user_id BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_id)
);
```

#### 4.3 索引设计

为提高查询性能，在以下字段创建索引：

- `users.username`：唯一索引（用户登录查询）
- `posts.author_id`：普通索引（按作者查询）
- `friendship.requester_id`、`friendship.receiver_id`：复合索引（好友关系查询）
- `comments.post_id`：普通索引（文章评论查询）

### 五、前端技术实现

#### 5.1 Vue 3 Composition API

**优势**：

- 更好的 TypeScript 支持
- 逻辑复用更灵活（Composables）
- 代码组织更清晰

**示例**（用户状态管理）：

```javascript
import { defineStore } from "pinia";

export const useUserStore = defineStore("user", {
  state: () => ({
    token: localStorage.getItem("token") || "",
    user: null,
  }),
  actions: {
    setToken(token) {
      this.token = token;
      localStorage.setItem("token", token);
    },
    setUser(user) {
      this.user = user;
    },
    logout() {
      this.token = "";
      this.user = null;
      localStorage.removeItem("token");
    },
  },
});
```

#### 5.2 路由守卫

实现基于 Token 的路由保护：

```javascript
router.beforeEach((to, from, next) => {
  const userStore = useUserStore();

  if (to.meta.requiresAuth && !userStore.token) {
    next("/login");
  } else if (to.path === "/login" && userStore.token) {
    next("/home");
  } else {
    next();
  }
});
```

#### 5.3 HTTP 请求拦截

统一处理 Token 和错误响应：

```javascript
// 请求拦截器：添加 Token
request.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// 响应拦截器：处理错误
request.interceptors.response.use(
  (response) => response.data,
  (error) => {
    if (error.response?.status === 401) {
      // Token 过期，跳转登录
      router.push("/login");
    }
    return Promise.reject(error);
  }
);
```

### 六、项目亮点与创新

#### 6.1 技术亮点

1. **完整的好友系统**：

   - 支持好友请求的完整生命周期（发送 → 待处理 → 接受/拒绝）
   - 实现好友时间线功能，聚合显示自己和好友的动态
   - 好友关系状态管理（PENDING/ACCEPTED/REJECTED）

2. **灵活的认证机制**：

   - JWT Token 无状态认证
   - 支持 Token 过期自动处理
   - 路由级别的权限控制

3. **优雅的错误处理**：

   - 统一的响应格式（`Result<T>`）
   - 前端统一的错误提示
   - 详细的错误日志记录

4. **数据统计分析**：
   - 提供 SQL 和 Spark 两种分析方案
   - 支持多种统计维度
   - 可视化展示统计结果

#### 6.2 设计创新

1. **朋友圈风格 UI**：

   - 仿微信朋友圈的卡片式设计
   - 九宫格图片展示
   - 流畅的页面过渡动画

2. **时间线功能**：

   - 聚合显示自己和所有好友的动态
   - 按时间倒序排列
   - 支持点赞、评论等互动操作

3. **响应式设计**：
   - 完美适配移动端和桌面端
   - 使用 Element Plus 组件库
   - 自适应的布局设计

### 七、测试与质量保证

#### 7.1 后端测试

**测试框架**：

- JUnit 5
- Mockito（Mock 框架）
- AssertJ（断言库）
- Testcontainers（集成测试）

**测试覆盖**：

- `AuthControllerTest`：认证接口测试
- `PostControllerTest`：文章接口测试
- `UserServiceTest`：用户服务测试
- `FriendshipServiceTest`：好友服务测试
- `JwtUtilTest`：JWT 工具类测试

**运行测试**：

```bash
cd backend
mvn test
```

#### 7.2 前端测试

**测试框架**：

- Vitest（单元测试）
- Playwright（E2E 测试）

**测试类型**：

- 单元测试：组件功能测试
- E2E 测试：端到端用户流程测试

**运行测试**：

```bash
cd frontend
npm run test        # 单元测试
npm run test:e2e    # E2E 测试
```

### 八、部署与运维

#### 8.1 开发环境部署

**一键启动脚本**（`start.sh`）：

- 自动检查环境依赖
- 创建数据库和表结构
- 启动后端服务（端口 8080）
- 启动前端服务（端口 5173）

#### 8.2 生产环境部署

**后端部署**：

1. 使用 Maven 打包：`mvn clean package -DskipTests`
2. 运行 JAR 包：`java -jar target/blog-system-1.0.0.jar`
3. 或使用 Docker 容器化部署

**前端部署**：

1. 构建生产版本：`npm run build`
2. 将 `dist/` 目录部署到 Nginx
3. 配置反向代理指向后端 API

#### 8.3 Docker 支持

项目提供 `docker-compose.yml` 文件，支持一键部署：

- 后端容器：Spring Boot 应用
- 前端容器：Nginx 静态文件服务
- 数据库容器：PostgreSQL

### 九、项目总结

#### 9.1 技术收获

1. **后端技术**：

   - 深入理解 Spring Boot 框架和分层架构
   - 掌握 MyBatis 数据库操作和 SQL 优化
   - 学会 JWT 认证机制和拦截器使用
   - 理解 RESTful API 设计原则

2. **前端技术**：

   - 熟练使用 Vue 3 Composition API
   - 掌握 Pinia 状态管理
   - 理解前后端分离架构
   - 学会路由守卫和权限控制

3. **数据库技术**：
   - 掌握 PostgreSQL 数据库设计
   - 理解索引优化和查询性能
   - 学会复杂 SQL 查询编写

#### 9.2 项目不足与改进方向

**当前不足**：

1. 缺少实时消息推送功能
2. 图片上传未实现压缩和 CDN 加速
3. 缺少全文搜索功能
4. 数据统计分析功能较简单

**改进方向**：

1. 集成 WebSocket 实现实时通知
2. 使用 OSS 存储图片，提升访问速度
3. 集成 Elasticsearch 实现全文搜索
4. 扩展更多统计维度和可视化图表
5. 添加缓存机制（Redis）提升性能

#### 9.3 学习心得

通过本项目的开发，深入理解了：

- 前后端分离架构的优势和实现方式
- JWT 无状态认证的工作原理
- 好友系统的业务逻辑和数据库设计
- 时间线功能的聚合查询实现
- 跨域问题的解决方案

项目不仅提升了编程技能，更重要的是培养了系统思维和工程化开发能力。

---

**最后更新**：2025-11-05
