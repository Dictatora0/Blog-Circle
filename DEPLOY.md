# Blog Circle 容器化部署指南

## 环境要求

- Docker 18.09.0+
- Docker Compose 1.28.0+
- openEuler 22.03 LTS (aarch64)

## 快速部署

### 方式一：从本地远程部署到服务器（最推荐）

**前提条件：**
- 本地需要安装 `sshpass`（用于密码认证）
  - macOS: `brew install hudochenkov/sshpass/sshpass`
  - Linux: `yum install sshpass` 或 `apt-get install sshpass`

**使用方法：**
```bash
# 在本地项目目录执行
./remote-deploy.sh
```

脚本会自动：
1. 连接到服务器 `10.211.55.11`
2. 进入项目目录并拉取最新代码
3. 停止现有容器
4. 重新构建并启动服务
5. 显示服务状态和日志

**配置说明：**
脚本中的服务器信息已配置：
- 服务器IP: `10.211.55.11`
- 用户名: `root`
- 项目目录: `CloudCom`

如需修改，请编辑 `remote-deploy.sh` 文件顶部的配置区域。

### 方式二：在服务器上使用脚本自动更新部署（推荐）

```bash
# 进入项目目录
cd /path/to/CloudCom

# 执行更新部署脚本（会自动拉取最新代码并重新构建）
./update-deploy.sh
```

### 方式二：手动更新部署

```bash
# 1. 进入项目目录
cd /path/to/CloudCom

# 2. 拉取最新代码
git pull origin dev

# 3. 验证代码已更新
git log --oneline -3

# 4. 停止现有容器（保留数据卷）
docker-compose down

# 5. 重新构建并启动
docker-compose up -d --build
```

### 方式三：首次部署

```bash
cd /path/to/CloudCom
docker-compose up -d --build
```

### 2. 查看服务状态

```bash
docker-compose ps
```

### 3. 查看日志

```bash
docker-compose logs -f
```

### 4. 停止服务

```bash
docker-compose down
```

### 停止并删除数据卷

```bash
docker-compose down -v
```

## 服务访问

- 前端: http://10.211.55.11:8080
- 后端: http://10.211.55.11:8081
- 数据库: 10.211.55.11:5432

## 测试接口

### 登录接口

```bash
curl -X POST http://10.211.55.11:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### 文章列表

```bash
curl http://10.211.55.11:8081/api/blog/list
```

## 数据库连接

容器内后端连接数据库使用：

- 主机: db
- 端口: 5432
- 数据库: blog_db
- 用户名: bloguser
- 密码: blogpass

## 数据持久化

- 数据库数据: `db_data` 卷
- 后端上传文件: `backend_uploads` 卷

## 镜像命名

- 前端: `blogcircle-frontend`
- 后端: `blogcircle-backend`
- 数据库: `postgres:15`

## 故障排查

### 查看容器日志

```bash
docker-compose logs backend
docker-compose logs frontend
docker-compose logs db
```

### 进入容器调试

```bash
docker exec -it blogcircle-backend /bin/bash
docker exec -it blogcircle-frontend /bin/sh
docker exec -it blogcircle-db psql -U bloguser -d blog_db
```

### 重建服务

```bash
docker-compose up -d --build --force-recreate backend
```

## 注意事项

1. 确保端口 8080、8081、5432 未被占用
2. 数据库初始化脚本会在首次启动时自动执行
3. 上传的文件存储在 `backend_uploads` 卷中
4. 修改配置后需要重新构建镜像
