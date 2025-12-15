# OpenGauss Docker 项目可移植性指南

本指南帮助您在不同的虚拟机和环境上部署 Blog Circle 项目。

## 目录

1. [快速开始](#快速开始)
2. [环境配置](#环境配置)
3. [常见问题排查](#常见问题排查)
4. [网络配置](#网络配置)
5. [镜像兼容性](#镜像兼容性)

---

## 快速开始

### 第一步：准备环境配置文件

```bash
# 复制配置模板
cp .env.opengauss.example .env.opengauss

# 编辑配置文件，根据实际环境修改
vi .env.opengauss
```

### 第二步：启动服务

```bash
# 使用新的可移植化 compose 文件
docker-compose -f docker-compose-opengauss-cluster-portable.yml --env-file .env.opengauss up -d

# 或者使用原始文件（需要手动修改硬编码值）
docker-compose -f docker-compose-opengauss-cluster-legacy.yml up -d
```

### 第三步：验证部署

```bash
# 查看容器状态
docker-compose -f docker-compose-opengauss-cluster-portable.yml ps

# 检查日志
docker-compose -f docker-compose-opengauss-cluster-portable.yml logs -f

# 测试数据库连接
docker exec opengauss-primary su - omm -c '/usr/local/opengauss/bin/gsql -d postgres -c "SELECT 1"'
```

---

## 环境配置

### 关键配置项说明

#### 1. 数据库密码 (`OPENGAUSS_PASSWORD`)

- **必须包含**：大小写字母、数字、特殊字符
- **示例**：`Blog@2025`
- **注意**：修改后需要重新初始化数据库

#### 2. 镜像选择 (`OPENGAUSS_IMAGE`)

**推荐的镜像版本：**

| 镜像                            | 优点           | 缺点                | 适用场景   |
| ------------------------------- | -------------- | ------------------- | ---------- |
| `enmotech/opengauss-lite:5.0.0` | 轻量级，启动快 | 功能较少            | 开发、测试 |
| `enmotech/opengauss:5.0.0`      | 功能完整       | 镜像较大            | 生产环境   |
| `openeuler/opengauss:5.0.0`     | 官方镜像，稳定 | 需要 OpenEuler 环境 | 生产环境   |

**如何选择：**

```bash
# 开发环境（推荐）
OPENGAUSS_IMAGE=enmotech/opengauss-lite:5.0.0

# 生产环境
OPENGAUSS_IMAGE=openeuler/opengauss:5.0.0

# 如果在 OpenEuler 上部署
OPENGAUSS_IMAGE=openeuler/opengauss:5.0.0
```

#### 3. 网络配置 (`DOCKER_NETWORK_SUBNET`)

如果遇到网络冲突，修改子网：

```bash
# 默认
DOCKER_NETWORK_SUBNET=172.26.0.0/16

# 如果冲突，尝试其他子网
DOCKER_NETWORK_SUBNET=172.27.0.0/16
DOCKER_NETWORK_SUBNET=172.28.0.0/16
```

**检查网络冲突：**

```bash
# 列出所有 Docker 网络
docker network ls

# 检查特定网络
docker network inspect opengauss-network

# 检查宿主机网络
ip addr show  # Linux
ifconfig      # macOS
```

#### 4. 端口映射

默认端口映射：

| 服务   | 容器端口 | 宿主机端口 | 用途       |
| ------ | -------- | ---------- | ---------- |
| 主库   | 5432     | 5432       | 数据库连接 |
| 备库 1 | 15432    | 5434       | 备库连接   |
| 备库 2 | 25432    | 5436       | 备库连接   |
| 后端   | 8080     | 8082       | API 服务   |
| 前端   | 8080     | 8080       | Web 界面   |

**如果端口被占用：**

```bash
# 修改 .env.opengauss
OPENGAUSS_PRIMARY_PORT=5433        # 改为 5433
BACKEND_MAPPED_PORT=8083           # 改为 8083
FRONTEND_MAPPED_PORT=8081          # 改为 8081
```

---

## 常见问题排查

### 问题 1：镜像拉取失败

**症状：**

```
Error response from daemon: pull access denied for enmotech/opengauss-lite
```

**解决方案：**

```bash
# 方案 A：使用官方镜像
OPENGAUSS_IMAGE=openeuler/opengauss:5.0.0

# 方案 B：检查网络连接
ping docker.io

# 方案 C：配置 Docker 镜像加速（中国用户）
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

### 问题 2：容器启动后立即退出

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

# 3. 检查磁盘空间
df -h

# 4. 检查内存
free -h

# 5. 手动启动容器查看详细错误
docker run -it --rm \
  -e GS_PASSWORD="Blog@2025" \
  enmotech/opengauss-lite:5.0.0 \
  /bin/bash
```

### 问题 3：网络连接失败

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

# 4. 检查防火墙
sudo ufw status
sudo firewall-cmd --list-all

# 5. 重建网络
docker-compose -f docker-compose-opengauss-cluster-portable.yml down
docker network rm opengauss-network
docker-compose -f docker-compose-opengauss-cluster-portable.yml up -d
```

### 问题 4：健康检查失败

**症状：**

```
unhealthy
```

**解决方案：**

```bash
# 1. 增加等待时间（在 .env.opengauss 中）
HEALTHCHECK_INTERVAL=20
HEALTHCHECK_RETRIES=10

# 2. 手动检查服务
docker exec opengauss-primary ps aux | grep gaussdb

# 3. 查看详细日志
docker logs --tail 50 opengauss-primary
```

### 问题 5：在 OpenEuler 上部署失败

**症状：**

```
image not found
```

**解决方案：**

```bash
# 1. 确保使用 OpenEuler 兼容的镜像
OPENGAUSS_IMAGE=openeuler/opengauss:5.0.0

# 2. 检查 OpenEuler 版本
cat /etc/os-release

# 3. 更新包管理器
sudo dnf update -y

# 4. 安装 Docker（如果未安装）
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# 5. 添加当前用户到 docker 组
sudo usermod -aG docker $USER
newgrp docker
```

---

## 网络配置

### Docker 网络模式对比

| 模式    | 说明                     | 适用场景                |
| ------- | ------------------------ | ----------------------- |
| bridge  | 默认，容器间通过网络通信 | 大多数场景              |
| host    | 容器使用宿主机网络       | 需要高性能              |
| overlay | 跨主机通信               | Docker Swarm/Kubernetes |

**当前配置使用 bridge 模式，适合单机部署。**

### 网络故障排查

```bash
# 1. 检查网络驱动
docker network ls

# 2. 检查网络配置
docker network inspect opengauss-network

# 3. 检查容器网络设置
docker inspect opengauss-primary | grep -A 20 NetworkSettings

# 4. 测试容器间通信
docker exec backend ping opengauss-primary

# 5. 测试外部连接
docker exec backend curl -v http://opengauss-primary:5432
```

---

## 镜像兼容性

### 支持的操作系统

| OS                     | Docker | OpenGauss 镜像          | 状态    |
| ---------------------- | ------ | ----------------------- | ------- |
| Ubuntu 20.04+          | 20.10+ | enmotech/opengauss-lite | ✅ 支持 |
| CentOS 7+              | 20.10+ | enmotech/opengauss-lite | ✅ 支持 |
| OpenEuler 20.03+       | 20.10+ | openeuler/opengauss     | ✅ 支持 |
| macOS (Docker Desktop) | 4.0+   | enmotech/opengauss-lite | ✅ 支持 |
| Windows (WSL2)         | 4.0+   | enmotech/opengauss-lite | ✅ 支持 |

### 镜像大小对比

```bash
# 查看镜像大小
docker images | grep opengauss

# 预期大小
# enmotech/opengauss-lite:5.0.0  ~500MB
# enmotech/opengauss:5.0.0       ~1.5GB
# openeuler/opengauss:5.0.0      ~1.2GB
```

### 拉取镜像优化

```bash
# 1. 使用镜像加速（中国用户）
docker pull registry.docker-cn.com/enmotech/opengauss-lite:5.0.0

# 2. 离线导入镜像
docker load < opengauss-lite.tar

# 3. 构建本地镜像
docker build -t opengauss-lite:5.0.0 .
```

---

## 最佳实践

### 1. 配置管理

```bash
# ✅ 推荐：使用环境变量文件
docker-compose -f docker-compose-opengauss-cluster-portable.yml \
  --env-file .env.opengauss \
  up -d

# ❌ 不推荐：硬编码配置
docker-compose -f docker-compose-opengauss-cluster-legacy.yml up -d
```

### 2. 数据持久化

```bash
# 检查数据卷
docker volume ls | grep opengauss

# 备份数据
docker run --rm -v opengauss-primary-data:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/opengauss-backup.tar.gz /data

# 恢复数据
docker run --rm -v opengauss-primary-data:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/opengauss-backup.tar.gz -C /
```

### 3. 日志管理

```bash
# 查看实时日志
docker-compose -f docker-compose-opengauss-cluster-portable.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose-opengauss-cluster-portable.yml logs -f opengauss-primary

# 导出日志
docker-compose -f docker-compose-opengauss-cluster-portable.yml logs > deployment.log
```

### 4. 性能优化

```bash
# 在 .env.opengauss 中调整
JAVA_XMS=256m          # 增加初始堆内存
JAVA_XMX=512m          # 增加最大堆内存
PRIVILEGED_MODE=false  # 生产环境关闭 privileged
```

---

## 支持和反馈

如遇到问题，请：

1. 查看本指南的[常见问题排查](#常见问题排查)部分
2. 检查容器日志：`docker logs <container_name>`
3. 提供以下信息提交 issue：
   - 操作系统和版本
   - Docker 版本
   - 完整的错误日志
   - `.env.opengauss` 配置（隐藏密码）

---

## 更新日志

### v1.0 (2025-12-15)

- ✅ 创建可移植化 compose 文件
- ✅ 添加环境配置模板
- ✅ 编写完整的排查指南
- ✅ 支持多个 OpenGauss 镜像版本
