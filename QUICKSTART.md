# 快速启动指南

## 一键启动（推荐）

### 1. 确保已安装依赖

- Java 17
- Maven
- PostgreSQL（或 GaussDB）
- Node.js 18+

### 2. 配置数据库

编辑 `backend/src/main/resources/application.yml`，修改数据库连接信息：

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/blog_db
    username: your_username # 修改这里
    password: your_password # 修改这里
```

### 3. 一键启动

```bash
./start.sh
```

启动成功后访问：http://localhost:5173

### 4. 停止服务

```bash
./stop.sh
```

## 手动启动

### 后端启动

```bash
cd backend
mvn spring-boot:run
```

### 前端启动

```bash
cd frontend
npm install
npm run dev
```

## 测试账号

初始数据库中已预置测试账号：

| 用户名 | 密码     | 说明       |
| ------ | -------- | ---------- |
| admin  | admin123 | 管理员账号 |
| user1  | user123  | 普通用户   |

也可以通过注册页面创建新账号。

## 功能演示流程

### 1. 注册登录

1. 访问 http://localhost:5173
2. 点击"立即注册"创建账号
3. 使用新账号登录

### 2. 发布文章

1. 登录后进入"文章列表"
2. 点击"发布文章"按钮
3. 填写标题和内容
4. 点击"发布"

### 3. 查看和评论

1. 点击文章卡片进入详情
2. 查看文章内容
3. 在评论区发表评论

### 4. 管理内容

- **我的文章**: 管理自己发布的文章
- **我的评论**: 管理自己的评论

### 5. 查看统计

1. 进入"数据统计"页面
2. 点击"运行 Spark 分析"
3. 查看分析结果

## 常用命令

### 后端

```bash
# 编译
mvn clean compile

# 打包
mvn clean package

# 运行
mvn spring-boot:run

# 跳过测试打包
mvn clean package -DskipTests
```

### 前端

```bash
# 安装依赖
npm install

# 开发模式
npm run dev

# 构建生产版本
npm run build

# 预览构建结果
npm run preview
```

### 数据库

```bash
# 连接数据库
psql -U username -d blog_db

# 执行初始化脚本
psql -U username -d blog_db -f backend/src/main/resources/db/init.sql

# 查看表
\dt

# 退出
\q
```

## API 测试示例

### 用户注册

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "123456",
    "email": "test@example.com",
    "nickname": "测试用户"
  }'
```

### 用户登录

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "123456"
  }'
```

### 获取文章列表

```bash
curl http://localhost:8080/api/posts/list
```

### 创建文章（需要 Token）

```bash
curl -X POST http://localhost:8080/api/posts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "title": "测试文章",
    "content": "这是测试内容"
  }'
```

## 故障排查

### 后端无法启动

1. 检查 Java 版本：`java -version`
2. 检查 Maven 版本：`mvn -version`
3. 检查数据库是否运行：`psql -l`
4. 查看日志：`logs/backend.log`

### 前端无法启动

1. 检查 Node 版本：`node -v`
2. 删除 node_modules 重新安装：
   ```bash
   rm -rf node_modules
   npm install
   ```
3. 查看日志：`logs/frontend.log`

### 数据库连接失败

1. 确认 PostgreSQL 服务运行：`brew services list`
2. 确认数据库存在：`psql -l | grep blog_db`
3. 检查用户名密码配置是否正确

### Spark 分析失败

1. 确保有访问日志数据
2. 检查内存是否充足
3. 查看后端日志了解详细错误

## 开发调试

### 后端调试

使用 IDE（如 IntelliJ IDEA）：

1. 导入 Maven 项目
2. 运行 `BlogApplication.java`
3. 设置断点进行调试

### 前端调试

使用浏览器开发者工具：

1. F12 打开开发者工具
2. 在 Sources 面板设置断点
3. 查看 Console 和 Network 面板

### 数据库调试

```sql
-- 查看用户
SELECT * FROM users;

-- 查看文章
SELECT * FROM posts;

-- 查看评论
SELECT * FROM comments;

-- 查看访问日志
SELECT * FROM access_logs ORDER BY created_at DESC LIMIT 10;

-- 查看统计结果
SELECT * FROM statistics;
```

## 生产部署提示

### 后端部署

1. 修改生产环境配置
2. 打包：`mvn clean package`
3. 运行：`java -jar target/blog-system-1.0.0.jar`
4. 建议使用进程管理工具（如 systemd）

### 前端部署

1. 构建：`npm run build`
2. 将 `dist/` 目录部署到 Web 服务器
3. 配置 Nginx 反向代理

### 数据库部署

1. 使用生产级 GaussDB 集群
2. 配置连接池参数
3. 定期备份数据
4. 配置监控告警

## 更多帮助

- 详细文档：查看 `README.md`
- 后端说明：查看 `backend/README.md`
- 前端说明：查看 `frontend/README.md`

## 技术支持

遇到问题请检查：

1. 所有服务是否正常运行
2. 配置文件是否正确
3. 依赖是否完整安装
4. 日志文件中的错误信息
