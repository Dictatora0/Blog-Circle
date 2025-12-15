# 快速开始指南

## 目录

- [本地开发环境](#本地开发环境)
- [虚拟机部署](#虚拟机部署)
- [OpenEuler 部署](#openeuler-部署)
- [常见问题](#常见问题)

---

## 本地开发环境

### 前置条件

- Docker Desktop 4.0+
- Docker Compose 1.29+
- 8GB+ RAM
- 10GB+ 磁盘空间

### 快速启动

```bash
# 1. 复制配置文件
cp .env.opengauss.example .env.opengauss

# 2. 启动服务
docker-compose -f docker-compose-opengauss-cluster-portable.yml \
  --env-file .env.opengauss \
  up -d

# 3. 验证部署
docker-compose -f docker-compose-opengauss-cluster-portable.yml ps

# 4. 访问应用
# 前端: http://localhost:8080
# 后端: http://localhost:8082
```

### 停止服务

```bash
docker-compose -f docker-compose-opengauss-cluster-portable.yml down
```

---

## 虚拟机部署

### Windows 环境

#### 前置条件

- Windows 10/11
- PowerShell 5.1+
- SSH 客户端
- Docker Desktop

#### 部署步骤

```powershell
# 1. 编辑配置文件
# 修改虚拟机 IP、用户、密码等
# 或设置环境变量:
$env:VM_IP = "10.211.55.11"
$env:VM_USER = "root"
$env:VM_PASSWORD = "your_password"

# 2. 运行部署脚本
.\start-vm-portable.ps1

# 3. 等待部署完成（约 2-3 分钟）
```

#### 配置说明

编辑 `.env.local` 或 `.env.opengauss`：

```bash
# 虚拟机配置
VM_IP=10.211.55.11
VM_USER=root
VM_PASSWORD=747599qw@
VM_PROJECT_DIR=/root/CloudCom

# Compose 文件
COMPOSE_FILE=docker-compose-opengauss-cluster-portable.yml
ENV_FILE=.env.opengauss

# 镜像配置
OPENGAUSS_IMAGE=enmotech/opengauss-lite:5.0.0
BACKEND_IMAGE_TAG=vm
FRONTEND_IMAGE_TAG=vm
```

#### 常用命令

```powershell
# 查看服务状态
ssh root@10.211.55.11 "cd /root/CloudCom && docker-compose ps"

# 查看日志
ssh root@10.211.55.11 "cd /root/CloudCom && docker-compose logs -f"

# 停止服务
ssh root@10.211.55.11 "cd /root/CloudCom && docker-compose down"

# 重启服务
ssh root@10.211.55.11 "cd /root/CloudCom && docker-compose restart"
```

---

## OpenEuler 部署

### 前置条件

- OpenEuler 20.03+
- 4GB+ RAM
- 10GB+ 磁盘空间

### 自动部署

```bash
# 1. 上传项目到虚拟机
scp -r . root@<vm_ip>:/root/CloudCom

# 2. SSH 连接到虚拟机
ssh root@<vm_ip>

# 3. 运行部署脚本
cd /root/CloudCom
bash scripts/deploy-on-openeuler.sh

# 4. 等待部署完成
```

### 手动部署

```bash
# 1. 更新系统
sudo dnf update -y

# 2. 安装 Docker
sudo dnf install -y docker docker-compose

# 3. 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# 4. 复制配置文件
cp .env.opengauss.example .env.opengauss

# 5. 修改镜像配置（推荐使用 OpenEuler 官方镜像）
# 编辑 .env.opengauss
OPENGAUSS_IMAGE=openeuler/opengauss:5.0.0

# 6. 启动服务
docker-compose -f docker-compose-opengauss-cluster-portable.yml \
  --env-file .env.opengauss \
  up -d

# 7. 验证部署
docker-compose -f docker-compose-opengauss-cluster-portable.yml ps
```

---

## 常见问题

### Q1: 镜像拉取失败

**错误信息：**

```
Error response from daemon: pull access denied for enmotech/opengauss-lite
```

**解决方案：**

```bash
# 方案 A: 使用官方镜像
OPENGAUSS_IMAGE=openeuler/opengauss:5.0.0

# 方案 B: 配置镜像加速（中国用户）
# 编辑 /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://mirror.aliyun.com",
    "https://registry.docker-cn.com"
  ]
}

# 重启 Docker
sudo systemctl restart docker
```

### Q2: 容器启动失败

**症状：**

```
opengauss-primary exited with code 1
```

**排查步骤：**

```bash
# 1. 查看容器日志
docker logs opengauss-primary

# 2. 检查密码是否符合要求
# 密码必须包含：大小写字母、数字、特殊字符
# 示例: Blog@2025

# 3. 检查磁盘空间
df -h

# 4. 检查内存
free -h
```

### Q3: 网络连接失败

**症状：**

```
Cannot connect to database: Connection refused
```

**排查步骤：**

```bash
# 1. 检查容器是否运行
docker ps | grep opengauss

# 2. 检查网络
docker network inspect opengauss-network

# 3. 测试容器间通信
docker exec backend ping opengauss-primary

# 4. 重建网络
docker-compose down
docker network rm opengauss-network
docker-compose up -d
```

### Q4: 端口被占用

**症状：**

```
Error response from daemon: Ports are not available
```

**解决方案：**

```bash
# 1. 查看占用端口的进程
netstat -tuln | grep 5432

# 2. 修改配置文件中的端口映射
# 编辑 .env.opengauss
OPENGAUSS_PRIMARY_PORT=5433
BACKEND_MAPPED_PORT=8083
FRONTEND_MAPPED_PORT=8081

# 3. 重启服务
docker-compose down
docker-compose up -d
```

### Q5: 健康检查失败

**症状：**

```
unhealthy
```

**解决方案：**

```bash
# 1. 增加等待时间
# 编辑 .env.opengauss
HEALTHCHECK_INTERVAL=20
HEALTHCHECK_RETRIES=10

# 2. 手动检查服务
docker exec opengauss-primary ps aux | grep gaussdb

# 3. 查看详细日志
docker logs --tail 50 opengauss-primary
```

### Q6: Windows SSH 连接问题

**症状：**

```
Permission denied (publickey,password)
```

**解决方案：**

```powershell
# 1. 生成 SSH 密钥
ssh-keygen -t rsa -f $env:USERPROFILE\.ssh\id_rsa

# 2. 复制公钥到虚拟机
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@10.211.55.11 'cat >> ~/.ssh/authorized_keys'

# 3. 测试连接
ssh root@10.211.55.11 "echo Connected"
```

---

## 验证部署

### 运行验证脚本

```bash
# Linux/macOS
bash scripts/verify-portability.sh

# Windows PowerShell
# 需要手动检查各项配置
```

### 手动验证

```bash
# 1. 检查容器状态
docker-compose ps

# 2. 检查数据库连接
docker exec opengauss-primary su - omm -c '/usr/local/opengauss/bin/gsql -d postgres -c "SELECT 1"'

# 3. 检查后端 API
curl http://localhost:8082/actuator/health

# 4. 访问前端
curl http://localhost:8080
```

---

## 性能优化

### 调整 Java 内存

编辑 `.env.opengauss`：

```bash
# 开发环境（默认）
JAVA_XMS=64m
JAVA_XMX=128m

# 生产环境
JAVA_XMS=256m
JAVA_XMX=512m
```

### 调整数据库参数

编辑 `.env.opengauss`：

```bash
# 增加健康检查间隔
HEALTHCHECK_INTERVAL=20

# 增加重试次数
HEALTHCHECK_RETRIES=10
```

---

## 备份和恢复

### 备份数据

```bash
# 备份数据卷
docker run --rm -v opengauss-primary-data:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/opengauss-backup.tar.gz /data
```

### 恢复数据

```bash
# 恢复数据卷
docker run --rm -v opengauss-primary-data:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/opengauss-backup.tar.gz -C /
```

---

## 获取帮助

1. 查看详细指南：[PORTABILITY-GUIDE.md](PORTABILITY-GUIDE.md)
2. 查看项目 README：[README.md](README.md)
3. 检查容器日志：`docker-compose logs -f`
4. 提交 Issue 时请提供：
   - 操作系统和版本
   - Docker 版本
   - 完整的错误日志
   - 配置文件（隐藏密码）

---

## 更新日志

### v1.0 (2025-12-15)

- ✅ 创建可移植化 compose 文件
- ✅ 支持环境变量配置
- ✅ 添加 OpenEuler 部署脚本
- ✅ 改进 Windows 部署脚本
- ✅ 编写快速开始指南
