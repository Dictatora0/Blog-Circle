# 简易博客系统

一个基于 Spring Boot + MyBatis + GaussDB + Vue 3 + Element Plus 的前后端分离博客系统，集成 Spark 进行数据分析。

## 项目结构

```
CloudCom/
├── backend/          # 后端项目（Spring Boot）
├── frontend/         # 前端项目（Vue 3）
└── README.md         # 项目说明文档
```

## 技术栈

### 后端

- **框架**: Spring Boot 3.1.5
- **ORM**: MyBatis 3.0.3
- **数据库**: GaussDB / PostgreSQL 42.6.0
- **鉴权**: JWT (jjwt 0.11.5)
- **数据分析**: Apache Spark 3.5.0
- **构建工具**: Maven
- **JDK**: 17

### 前端

- **框架**: Vue 3.3.4
- **UI 组件库**: Element Plus 2.4.1
- **路由**: Vue Router 4.2.5
- **状态管理**: Pinia 2.1.7
- **HTTP 客户端**: Axios 1.5.0
- **构建工具**: Vite 4.5.0

## 功能特性

### 用户功能

- ✅ 用户注册
- ✅ 用户登录（JWT 鉴权）
- ✅ 用户信息管理

### 文章功能

- ✅ 发布文章
- ✅ 编辑文章
- ✅ 删除文章
- ✅ 浏览文章列表
- ✅ 查看文章详情
- ✅ 文章浏览计数

### 评论功能

- ✅ 发表评论
- ✅ 编辑评论
- ✅ 删除评论
- ✅ 查看文章评论列表
- ✅ 我的评论管理

### 数据分析功能（Spark）

- ✅ 统计用户发文数量
- ✅ 统计文章浏览次数
- ✅ 统计文章评论数量
- ✅ 数据可视化展示

## 环境准备

### 1. 安装 Java 17

```bash
# macOS
brew install openjdk@17

# 验证安装
java -version
```

### 2. 安装 Maven

```bash
# macOS
brew install maven

# 验证安装
mvn -version
```

### 3. 安装 PostgreSQL（或 GaussDB）

```bash
# macOS
brew install postgresql@14

# 启动服务
brew services start postgresql@14

# 创建数据库
createdb blog_db
```

### 4. 安装 Node.js（推荐 18.x 或更高版本）

```bash
# macOS
brew install node

# 验证安装
node --version
npm -version
```

## 快速开始

### 一、数据库初始化

1. 连接数据库：

```bash
psql -U your_username -d blog_db
```

2. 执行初始化脚本：

```bash
psql -U your_username -d blog_db -f backend/src/main/resources/db/init.sql
```

或者在 psql 命令行中：

```sql
\i backend/src/main/resources/db/init.sql
```

### 二、后端启动

1. 进入后端目录：

```bash
cd backend
```

2. 修改数据库配置（`src/main/resources/application.yml`）：

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/blog_db
    username: your_username # 修改为你的数据库用户名
    password: your_password # 修改为你的数据库密码
```

3. 安装依赖并启动：

```bash
# 安装依赖
mvn clean install

# 启动应用
mvn spring-boot:run
```

后端将在 `http://localhost:8080` 启动。

### 三、前端启动

1. 进入前端目录：

```bash
cd frontend
```

2. 安装依赖：

```bash
npm install
```

3. 启动开发服务器：

```bash
npm run dev
```

前端将在 `http://localhost:5173` 启动。

## 使用指南

### 1. 注册与登录

访问 `http://localhost:5173`，首先注册一个账号：

- 点击"还没有账号？立即注册"
- 填写用户名、密码、邮箱、昵称
- 注册成功后返回登录页面
- 使用注册的账号登录

### 2. 发布文章

登录后：

- 在"文章列表"页面点击"发布文章"按钮
- 输入文章标题和内容
- 点击"发布"按钮

### 3. 查看与评论

- 点击文章卡片进入文章详情页
- 在详情页可以查看完整内容
- 登录用户可以在评论区发表评论
- 文章作者可以编辑或删除自己的文章

### 4. 管理内容

- **我的文章**：查看、编辑、删除自己发布的文章
- **我的评论**：查看、编辑、删除自己的评论

### 5. 数据统计

- 进入"数据统计"页面
- 点击"运行 Spark 分析"按钮触发数据分析
- 查看不同维度的统计结果：
  - 用户发文统计
  - 文章浏览统计
  - 文章评论统计

## API 接口文档

### 认证接口

#### 用户注册

```
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

```
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

#### 获取文章列表

```
GET /api/posts/list
```

#### 获取文章详情

```
GET /api/posts/{id}/detail
```

#### 创建文章（需登录）

```
POST /api/posts
Authorization: Bearer {token}
Content-Type: application/json

{
  "title": "string",
  "content": "string"
}
```

#### 更新文章（需登录）

```
PUT /api/posts/{id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "title": "string",
  "content": "string"
}
```

#### 删除文章（需登录）

```
DELETE /api/posts/{id}
Authorization: Bearer {token}
```

### 评论接口

#### 获取文章评论

```
GET /api/comments/post/{postId}
```

#### 创建评论（需登录）

```
POST /api/comments
Authorization: Bearer {token}
Content-Type: application/json

{
  "postId": 1,
  "content": "string"
}
```

#### 更新评论（需登录）

```
PUT /api/comments/{id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "content": "string"
}
```

#### 删除评论（需登录）

```
DELETE /api/comments/{id}
Authorization: Bearer {token}
```

### 统计接口

#### 运行 Spark 分析（需登录）

```
POST /api/stats/analyze
Authorization: Bearer {token}
```

#### 获取所有统计数据（需登录）

```
GET /api/stats
Authorization: Bearer {token}
```

#### 获取指定类型统计数据（需登录）

```
GET /api/stats/{type}
Authorization: Bearer {token}

type: USER_POST_COUNT | POST_VIEW_COUNT | POST_COMMENT_COUNT
```

## 数据库表结构

### users（用户表）

- id: 主键
- username: 用户名（唯一）
- password: 密码（加密存储）
- email: 邮箱
- nickname: 昵称
- avatar: 头像
- created_at: 创建时间
- updated_at: 更新时间

### posts（文章表）

- id: 主键
- title: 标题
- content: 内容
- author_id: 作者 ID（外键）
- view_count: 浏览次数
- created_at: 创建时间
- updated_at: 更新时间

### comments（评论表）

- id: 主键
- post_id: 文章 ID（外键）
- user_id: 用户 ID（外键）
- content: 内容
- created_at: 创建时间

### access_logs（访问日志表）

- id: 主键
- user_id: 用户 ID
- post_id: 文章 ID
- action: 操作类型（CREATE_POST, VIEW_POST, ADD_COMMENT）
- created_at: 创建时间

### statistics（统计结果表）

- id: 主键
- stat_type: 统计类型
- stat_key: 统计键
- stat_value: 统计值
- created_at: 创建时间
- updated_at: 更新时间

## 项目配置说明

### 后端配置（application.yml）

- `spring.datasource`: 数据库连接配置
- `mybatis`: MyBatis 配置
- `jwt.secret`: JWT 密钥
- `jwt.expiration`: Token 过期时间
- `spark`: Spark 配置

### 前端配置（vite.config.js）

- `server.port`: 开发服务器端口
- `server.proxy`: API 代理配置

## 常见问题

### 1. 后端启动失败

**问题**: 数据库连接失败
**解决**:

- 检查 PostgreSQL 服务是否启动
- 确认数据库用户名和密码配置正确
- 确认数据库 blog_db 已创建

### 2. Spark 分析失败

**问题**: Spark 分析时出错
**解决**:

- 确保访问日志表有数据
- 检查 Spark 日志输出
- 可能需要调整 Spark 配置（如内存设置）

### 3. 前端跨域问题

**问题**: API 请求被 CORS 阻止
**解决**:

- 已在后端配置 CORS，确保后端运行在 8080 端口
- 前端通过 Vite 代理转发请求

### 4. JWT Token 过期

**问题**: 操作时提示 Token 过期
**解决**:

- 重新登录获取新 Token
- Token 默认有效期为 24 小时

## 开发注意事项

1. **密码安全**: 当前使用 SHA-256 加密，生产环境建议使用 BCrypt
2. **日志记录**: 所有关键操作都会记录到 access_logs 表
3. **权限控制**:
   - 文章和评论只能由作者本人编辑/删除
   - JWT 拦截器自动验证登录状态
4. **数据分析**: Spark 分析是资源密集型操作，建议定期执行而非实时

## 生产部署建议

1. **数据库**:

   - 使用生产级别的 GaussDB 集群
   - 配置数据库连接池
   - 定期备份数据

2. **后端**:

   - 使用 `mvn clean package` 打包
   - 配置生产环境的 application-prod.yml
   - 使用反向代理（Nginx）

3. **前端**:

   - 使用 `npm run build` 构建
   - 部署到 CDN 或静态服务器
   - 配置生产环境 API 地址

4. **安全**:
   - 修改 JWT 密钥为强随机字符串
   - 启用 HTTPS
   - 配置防火墙规则
   - 添加请求频率限制

## 技术支持

如有问题，请查看：

- Spring Boot 官方文档: https://spring.io/projects/spring-boot
- Vue 3 官方文档: https://cn.vuejs.org/
- Element Plus 官方文档: https://element-plus.org/
- Apache Spark 官方文档: https://spark.apache.org/docs/latest/

## 许可证

本项目仅供学习和研究使用。

## 更新日志

### v1.0.0 (2025-11-01)

- ✅ 完成用户注册登录功能
- ✅ 完成文章 CRUD 功能
- ✅ 完成评论 CRUD 功能
- ✅ 集成 Spark 数据分析
- ✅ 完成前端所有页面开发
- ✅ 实现 JWT 鉴权机制
