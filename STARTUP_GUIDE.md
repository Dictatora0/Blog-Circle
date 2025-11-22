# Blog Circle 启动指南

本指南介绍如何在本地和虚拟机环境中启动和管理 Blog Circle 系统。

---

## 📋 快速开始

### 本地环境（开发）

```bash
# 启动所有服务
./start-local.sh

# 检查服务状态
./status.sh local

# 停止所有服务
./stop-local.sh
```

### 虚拟机环境（生产）

```bash
# 启动虚拟机服务
./start-vm.sh

# 检查虚拟机状态
./status.sh vm

# 停止虚拟机服务
./stop-vm.sh
```

---

## 🏗️ 系统架构

### 容器化服务

系统采用 Docker Compose 编排，包含以下服务：

- **openGauss 主库** (opengauss-primary)
  - 端口：5432
  - 角色：读写
- **openGauss 备库 1** (opengauss-standby1)
  - 端口：5434 → 内部 15432
  - 角色：读
- **openGauss 备库 2** (opengauss-standby2)
  - 端口：5436 → 内部 25432
  - 角色：读
- **后端服务** (blogcircle-backend)
  - 端口：8082
  - 技术栈：Spring Boot 3.1.5 + JDK 17
- **前端服务** (blogcircle-frontend)
  - 端口：8080
  - 技术栈：Vue 3 + Nginx

---

## 🚀 详细使用说明

### 1. 本地启动脚本 (`start-local.sh`)

**功能：**

- 检查 Docker 环境
- 停止并清理旧容器
- 拉取 openGauss 镜像
- 构建并启动所有服务
- 等待服务就绪
- 执行健康检查

**使用方法：**

```bash
chmod +x start-local.sh
./start-local.sh
```

**预计启动时间：** 3-5 分钟（首次启动需要构建镜像）

**启动后访问：**

- 前端：http://localhost:8080
- 后端：http://localhost:8082
- 健康检查：http://localhost:8082/actuator/health

### 2. 本地停止脚本 (`stop-local.sh`)

**功能：**

- 按顺序停止服务（前端 → 后端 → 数据库）
- 移除容器
- 保留数据卷

**使用方法：**

```bash
chmod +x stop-local.sh
./stop-local.sh
```

**注意：** 数据保留在 Docker volumes 中，不会丢失

### 3. 虚拟机启动脚本 (`start-vm.sh`)

**功能：**

- 通过 SSH 连接虚拟机
- 检查 Docker 环境
- 拉取并启动服务
- 远程健康检查

**前置要求：**

- 安装 sshpass：`brew install hudochenkov/sshpass/sshpass` (macOS)
- 虚拟机已安装 Docker 和 Docker Compose
- 项目代码已部署到虚拟机 `/root/CloudCom`

**使用方法：**

```bash
chmod +x start-vm.sh
./start-vm.sh
```

**启动后访问：**

- 前端：http://10.211.55.11:8080
- 后端：http://10.211.55.11:8082

### 4. 虚拟机停止脚本 (`stop-vm.sh`)

**功能：**

- 远程停止虚拟机上的所有服务
- 清理容器但保留数据

**使用方法：**

```bash
chmod +x stop-vm.sh
./stop-vm.sh
```

### 5. 状态检查脚本 (`status.sh`)

**功能：**

- 快速查看服务运行状态
- 支持本地和虚拟机环境

**使用方法：**

```bash
chmod +x status.sh

# 检查本地状态
./status.sh local

# 检查虚拟机状态
./status.sh vm
```

---

## 🔧 常见问题

### Q1: Docker Desktop 未启动

**问题：** 运行启动脚本时提示 "Docker 未运行"

**解决：**

```bash
# macOS
open /Applications/Docker.app

# 等待 Docker Desktop 完全启动后再运行脚本
```

### Q2: 端口被占用

**问题：** 启动失败，提示端口 5432/8080/8082 被占用

**解决：**

```bash
# 查看占用端口的进程
lsof -i :5432
lsof -i :8080
lsof -i :8082

# 停止占用的进程或清理旧容器
./stop-local.sh
docker-compose -f docker-compose-opengauss-cluster.yml down -v
```

### Q3: 虚拟机连接失败

**问题：** `start-vm.sh` 无法连接虚拟机

**解决：**

```bash
# 1. 检查虚拟机是否运行
ping 10.211.55.11

# 2. 检查 SSH 连接
ssh root@10.211.55.11

# 3. 检查 sshpass 安装
which sshpass
```

### Q4: 服务健康检查失败

**问题：** 启动后健康检查显示"⚠ 未就绪"

**原因：** 服务可能需要更长初始化时间

**解决：**

```bash
# 等待 1-2 分钟后再次检查
./status.sh local

# 查看服务日志
docker-compose -f docker-compose-opengauss-cluster.yml logs backend
docker-compose -f docker-compose-opengauss-cluster.yml logs opengauss-primary
```

### Q5: 数据库初始化失败

**问题：** openGauss 容器启动但无法连接

**解决：**

```bash
# 查看数据库日志
docker logs opengauss-primary

# 完全重置（会删除所有数据）
docker-compose -f docker-compose-opengauss-cluster.yml down -v
./start-local.sh
```

---

## 📊 服务监控

### 查看容器状态

```bash
docker-compose -f docker-compose-opengauss-cluster.yml ps
```

### 查看实时日志

```bash
# 所有服务
docker-compose -f docker-compose-opengauss-cluster.yml logs -f

# 特定服务
docker-compose -f docker-compose-opengauss-cluster.yml logs -f backend
docker-compose -f docker-compose-opengauss-cluster.yml logs -f opengauss-primary
```

### 查看资源使用

```bash
docker stats opengauss-primary opengauss-standby1 opengauss-standby2 blogcircle-backend blogcircle-frontend
```

---

## 🧪 测试验证

### 运行完整系统验证

```bash
# 本地环境
./scripts/full_verify.sh

# 虚拟机环境（需要 SSH 到虚拟机）
ssh root@10.211.55.11
cd /root/CloudCom
./scripts/full_verify.sh
```

### 运行 openGauss 实例测试

```bash
./scripts/test-opengauss-instances.sh
```

---

## 🔄 维护操作

### 重启服务

```bash
# 本地
./stop-local.sh
./start-local.sh

# 虚拟机
./stop-vm.sh
./start-vm.sh
```

### 更新代码

```bash
# 本地
git pull
./stop-local.sh
./start-local.sh

# 虚拟机
./stop-vm.sh
ssh root@10.211.55.11 "cd /root/CloudCom && git pull"
./start-vm.sh
```

### 清理所有数据

```bash
# ⚠️ 警告：此操作会删除所有数据库数据

# 本地
docker-compose -f docker-compose-opengauss-cluster.yml down -v

# 虚拟机
ssh root@10.211.55.11 "cd /root/CloudCom && docker-compose -f docker-compose-opengauss-cluster.yml down -v"
```

---

## 📝 环境变量

系统使用 `.env.cluster` 配置虚拟机集群参数（仅供参考）：

```bash
# 虚拟机配置
PRIMARY_IP=10.211.55.11
VM_USER=root
VM_PASSWORD=747599qw@

# 数据库配置
GAUSSDB_PORT=5432
GAUSSDB_DATABASE=blog_db
GAUSSDB_USERNAME=bloguser
GAUSSDB_PASSWORD=Blog@2025
```

容器化部署的实际配置在 `docker-compose-opengauss-cluster.yml` 中定义。

---

## 🆘 获取帮助

如遇到问题，请按以下顺序排查：

1. 运行状态检查：`./status.sh`
2. 查看日志：`docker-compose logs`
3. 检查健康状态：`curl http://localhost:8082/actuator/health`
4. 运行系统验证：`./scripts/full_verify.sh`

---

## 📚 相关文档

- [README.md](./README.md) - 项目总览
- [scripts/README.md](./scripts/README.md) - 脚本详细说明
- [docker-compose-opengauss-cluster.yml](./docker-compose-opengauss-cluster.yml) - 容器编排配置
