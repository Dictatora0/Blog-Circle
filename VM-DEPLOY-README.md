# 虚拟机部署快速指南

## 🚀 快速开始

### 1. 上传项目到虚拟机

```bash
# 在你的 Mac 上执行
rsync -avz --delete \
    --exclude 'node_modules' \
    --exclude 'target' \
    --exclude '.git' \
    --exclude 'dist' \
    ./ root@10.211.55.11:~/CloudCom/
```

### 2. SSH 到虚拟机并部署

```bash
# SSH 到虚拟机
ssh root@10.211.55.11

# 进入项目目录
cd ~/CloudCom

# 添加执行权限（首次执行需要）
chmod +x deploy-on-vm.sh stop-on-vm.sh

# 开始部署（大约需要 5-10 分钟）
./deploy-on-vm.sh
```

### 3. 访问应用

部署完成后：

- **前端**: http://10.211.55.11:8080
- **后端 API**: http://10.211.55.11:8082
- **健康检查**: http://10.211.55.11:8082/actuator/health

## 📝 常用操作

### 查看服务状态

```bash
docker-compose -f docker-compose-opengauss-cluster-legacy.yml ps
```

### 查看日志

```bash
# 所有服务日志
docker-compose -f docker-compose-opengauss-cluster-legacy.yml logs -f

# 只看后端日志
docker logs -f blogcircle-backend

# 只看前端日志
docker logs -f blogcircle-frontend
```

### 停止服务

```bash
./stop-on-vm.sh
```

### 重启服务

```bash
docker-compose -f docker-compose-opengauss-cluster-legacy.yml restart
```

### 数据库操作

```bash
# 连接主库
docker exec -it opengauss-primary bash -c 'su - omm -c "gsql -d blog_db"'

# 同步主库数据到备库
./scripts/sync-data-to-standbys.sh
```

## 🗂️ 服务架构

```
虚拟机 (10.211.55.11)
├── opengauss-primary   (主库)   :5432
├── opengauss-standby1  (备库1)  :5434
├── opengauss-standby2  (备库2)  :5436
├── blogcircle-backend  (后端)   :8082
└── blogcircle-frontend (前端)   :8080
```

## 📦 使用的配置文件

- **Docker Compose**: `docker-compose-opengauss-cluster-legacy.yml`
- 使用预构建的镜像标签：`blogcircle-backend:vm` 和 `blogcircle-frontend:vm`

## 🔧 故障排查

### 服务无法启动

```bash
# 查看日志
docker logs blogcircle-backend
docker logs opengauss-primary

# 检查端口
netstat -tunlp | grep -E '8080|8082|5432'
```

### 重新构建

```bash
# 完全清理后重新部署
docker-compose -f docker-compose-opengauss-cluster-legacy.yml down -v
./deploy-on-vm.sh
```

## 📚 详细文档

查看完整的部署文档：`docs/vm-deployment-guide.md`

## ⚠️ 注意事项

1. **首次部署**需要下载和构建镜像，可能需要 5-10 分钟
2. **后端启动**需要 1-2 分钟初始化数据库
3. **数据持久化**：所有数据保存在 Docker volumes 中
4. **备库数据**：需要手动同步（运行 `./scripts/sync-data-to-standbys.sh`）

---

**部署问题？** 查看日志或参考 `docs/vm-deployment-guide.md`
