# 虚拟机部署指南

本指南说明如何直接在虚拟机上构建和部署 BlogCircle 项目。

## 📋 前提条件

### 虚拟机要求

- 操作系统：CentOS 7+ / Ubuntu 20.04+
- 内存：至少 4GB RAM
- 磁盘：至少 20GB 可用空间
- 已安装 Docker 和 Docker Compose

### 检查 Docker 环境

```bash
# 检查 Docker 版本
docker --version

# 检查 Docker Compose 版本
docker-compose --version

# 检查 Docker 服务状态
systemctl status docker
```

## 🚀 快速部署

### 步骤 1: 上传项目到虚拟机

从本地 Mac 上传项目：

```bash
# 方法 1: 使用 rsync（推荐，更快）
rsync -avz --delete \
    --exclude 'node_modules' \
    --exclude 'target' \
    --exclude '.git' \
    --exclude 'dist' \
    ./ root@10.211.55.11:~/CloudCom/

# 方法 2: 使用 scp
scp -r CloudCom root@10.211.55.11:~/
```

### 步骤 2: SSH 到虚拟机

```bash
ssh root@10.211.55.11
```

### 步骤 3: 进入项目目录

```bash
cd ~/CloudCom
```

### 步骤 4: 添加执行权限

```bash
chmod +x deploy-on-vm.sh stop-on-vm.sh
```

### 步骤 5: 执行部署

```bash
./deploy-on-vm.sh
```

**部署过程大约需要 5-10 分钟**，包括：

- 拉取 openGauss 镜像
- 构建后端 Java 应用（Maven 构建）
- 构建前端 Vue 应用（npm 构建）
- 启动所有服务
- 初始化数据库

## 📊 部署流程

```
deploy-on-vm.sh 执行流程：

[1/7] 停止旧服务
  └─ docker-compose down

[2/7] 清理旧镜像
  └─ 删除旧的 backend/frontend 镜像

[3/7] 拉取 openGauss 镜像
  └─ docker pull enmotech/opengauss-lite:latest

[4/7] 构建后端镜像
  └─ docker build backend/ (Maven 构建)

[5/7] 构建前端镜像
  └─ docker build frontend/ (npm 构建)

[6/7] 启动服务
  ├─ openGauss 主库 (端口 5432)
  ├─ openGauss 备库1 (端口 5434)
  ├─ openGauss 备库2 (端口 5436)
  ├─ 后端服务 (端口 8082)
  └─ 前端服务 (端口 8080)

[7/7] 初始化数据库
  ├─ 创建 bloguser 用户
  ├─ 创建 blog_db 数据库
  └─ 在备库创建相同的用户和数据库
```

## 🔍 验证部署

### 检查服务状态

```bash
# 查看所有容器状态
docker-compose -f docker-compose-opengauss-cluster-legacy.yml ps

# 查看详细运行状态
docker ps
```

### 访问应用

- **前端**: http://10.211.55.11:8080
- **后端 API**: http://10.211.55.11:8082
- **健康检查**: http://10.211.55.11:8082/actuator/health

### 检查数据库

```bash
# 连接主库
docker exec -it opengauss-primary bash -c 'su - omm -c "gsql -d blog_db"'

# 查看表
\dt

# 查看用户数量
SELECT COUNT(*) FROM users;

# 退出
\q
```

## 📝 常用命令

### 服务管理

```bash
# 查看所有日志
docker-compose -f docker-compose-opengauss-cluster-legacy.yml logs -f

# 查看后端日志
docker logs -f blogcircle-backend

# 查看前端日志
docker logs -f blogcircle-frontend

# 查看主库日志
docker logs -f opengauss-primary

# 重启所有服务
docker-compose -f docker-compose-opengauss-cluster-legacy.yml restart

# 重启单个服务
docker-compose -f docker-compose-opengauss-cluster-legacy.yml restart backend

# 停止服务
./stop-on-vm.sh
```

### 数据库管理

```bash
# 连接主库
docker exec -it opengauss-primary bash -c 'su - omm -c "gsql -d blog_db"'

# 连接备库1
docker exec -it opengauss-standby1 bash -c 'su - omm -c "gsql -d blog_db -p 15432"'

# 连接备库2
docker exec -it opengauss-standby2 bash -c 'su - omm -c "gsql -d blog_db -p 25432"'

# 导出数据库
docker exec opengauss-primary bash -c 'su - omm -c "gs_dump blog_db -f /tmp/backup.sql"'
docker cp opengauss-primary:/tmp/backup.sql ./backup.sql

# 同步主库数据到备库
./scripts/sync-data-to-standbys.sh
```

### 容器管理

```bash
# 进入后端容器
docker exec -it blogcircle-backend bash

# 进入主库容器
docker exec -it opengauss-primary bash

# 查看容器资源使用
docker stats

# 查看网络
docker network ls
docker network inspect cloudcom_opengauss-network
```

## 🛠️ 故障排查

### 服务无法启动

```bash
# 检查容器日志
docker logs blogcircle-backend
docker logs opengauss-primary

# 检查端口占用
netstat -tunlp | grep -E '8080|8082|5432'

# 重新构建镜像
docker-compose -f docker-compose-opengauss-cluster-legacy.yml build --no-cache
```

### 数据库连接失败

```bash
# 检查数据库是否运行
docker exec opengauss-primary bash -c 'su - omm -c "gsql -d postgres -c \"SELECT 1;\""'

# 检查用户是否存在
docker exec opengauss-primary bash -c 'su - omm -c "gsql -d postgres -c \"SELECT usename FROM pg_user;\""'

# 重新创建数据库
docker exec opengauss-primary bash -c 'su - omm -c "gsql -d postgres -c \"CREATE DATABASE blog_db OWNER bloguser;\""'
```

### 后端构建失败

```bash
# 检查 Maven 配置
cd backend
cat pom.xml

# 手动构建（查看详细错误）
docker build -t blogcircle-backend:vm -f Dockerfile .

# 清理 Maven 缓存重新构建
docker build --no-cache -t blogcircle-backend:vm -f Dockerfile .
```

### 前端构建失败

```bash
# 检查 npm 配置
cd frontend
cat package.json

# 手动构建
docker build -t blogcircle-frontend:vm -f Dockerfile .

# 清理 npm 缓存重新构建
docker build --no-cache -t blogcircle-frontend:vm -f Dockerfile .
```

## 🗑️ 清理和卸载

### 停止服务（保留数据）

```bash
./stop-on-vm.sh
```

### 完全清理（删除所有数据）

```bash
# 停止并删除所有容器和数据卷
docker-compose -f docker-compose-opengauss-cluster-legacy.yml down -v

# 删除应用镜像
docker rmi blogcircle-backend:vm blogcircle-frontend:vm

# 删除 openGauss 镜像（可选）
docker rmi enmotech/opengauss-lite:latest

# 清理未使用的镜像和缓存
docker system prune -af
```

## 📦 数据持久化

数据保存在以下 Docker volumes 中：

```bash
# 查看所有 volumes
docker volume ls

# 主要 volumes：
# - cloudcom_opengauss-primary-data   (主库数据)
# - cloudcom_opengauss-standby1-data  (备库1数据)
# - cloudcom_opengauss-standby2-data  (备库2数据)
# - cloudcom_backend-uploads          (上传文件)

# 备份 volume
docker run --rm -v cloudcom_opengauss-primary-data:/data -v $(pwd):/backup alpine tar czf /backup/primary-data-backup.tar.gz /data

# 恢复 volume
docker run --rm -v cloudcom_opengauss-primary-data:/data -v $(pwd):/backup alpine tar xzf /backup/primary-data-backup.tar.gz -C /
```

## 🔄 更新部署

### 更新代码并重新部署

```bash
# 从本地 Mac 同步新代码
rsync -avz --delete \
    --exclude 'node_modules' \
    --exclude 'target' \
    --exclude '.git' \
    ./ root@10.211.55.11:~/CloudCom/

# SSH 到虚拟机
ssh root@10.211.55.11

# 重新部署
cd ~/CloudCom
./deploy-on-vm.sh
```

### 只更新后端

```bash
# 停止后端
docker-compose -f docker-compose-opengauss-cluster-legacy.yml stop backend

# 重新构建后端
cd backend
docker build -t blogcircle-backend:vm -f Dockerfile .

# 启动后端
cd ..
docker-compose -f docker-compose-opengauss-cluster-legacy.yml up -d backend
```

### 只更新前端

```bash
# 停止前端
docker-compose -f docker-compose-opengauss-cluster-legacy.yml stop frontend

# 重新构建前端
cd frontend
docker build -t blogcircle-frontend:vm -f Dockerfile .

# 启动前端
cd ..
docker-compose -f docker-compose-opengauss-cluster-legacy.yml up -d frontend
```

## 📚 相关脚本

| 脚本                       | 用途                | 位置       |
| -------------------------- | ------------------- | ---------- |
| `deploy-on-vm.sh`          | 在虚拟机上部署      | 项目根目录 |
| `stop-on-vm.sh`            | 在虚拟机上停止服务  | 项目根目录 |
| `sync-data-to-standbys.sh` | 同步主库到备库      | scripts/   |
| `verify-opengauss.sh`      | 验证 openGauss 集群 | scripts/   |

## ⚙️ 配置文件

- **Docker Compose**: `docker-compose-opengauss-cluster-legacy.yml`
- **后端配置**: `backend/src/main/resources/application-opengauss-cluster.yml`
- **前端配置**: `frontend/.env.production`

## 💡 提示和最佳实践

1. **首次部署**：确保虚拟机有足够的内存（至少 4GB）
2. **网络配置**：确保防火墙允许 8080、8082、5432 端口
3. **数据备份**：定期备份数据库和上传文件
4. **日志管理**：定期清理日志文件，避免磁盘占满
5. **性能优化**：根据实际负载调整 JVM 参数和数据库连接池
6. **安全建议**：
   - 修改默认密码 `Blog@2025`
   - 配置防火墙规则
   - 使用 HTTPS（配置 Nginx 反向代理）

## 📞 故障支持

如遇问题，请检查：

1. 容器日志：`docker logs <container_name>`
2. 系统资源：`docker stats`
3. 网络连接：`docker network inspect cloudcom_opengauss-network`
4. 磁盘空间：`df -h`
5. Docker 版本兼容性

---

**部署成功后，访问 http://10.211.55.11:8080 即可使用系统！** 🎉
