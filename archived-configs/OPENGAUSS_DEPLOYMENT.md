# openGauss 集群容器化部署指南

本文档说明如何使用真实的 openGauss 数据库进行容器化部署。

## 架构说明

- **openGauss 版本**: 5.0.0
- **集群架构**: 一主二备（1 Primary + 2 Standby）
- **复制方式**: 流复制（Streaming Replication）
- **镜像来源**: opengauss/opengauss:5.0.0 官方镜像

## 组件说明

### 数据库集群

- **opengauss-primary**: 主库，负责读写操作，端口 5432
- **opengauss-standby1**: 备库 1，只读副本，端口 5434
- **opengauss-standby2**: 备库 2，只读副本，端口 5436

### 应用服务

- **backend**: Spring Boot 后端服务，端口 8082
- **frontend**: Vue + Nginx 前端服务，端口 8080

## 部署步骤

### 1. 准备环境

确保已安装：

- Docker 20.10+
- Docker Compose 1.29+

### 2. 本地部署

```bash
# 赋予脚本执行权限
chmod +x scripts/deploy-opengauss-cluster.sh
chmod +x scripts/test-opengauss-cluster.sh

# 部署集群
./scripts/deploy-opengauss-cluster.sh
```

### 3. 虚拟机部署

```bash
# 在本地构建镜像
docker-compose -f docker-compose-opengauss-cluster.yml build

# 保存镜像
docker save opengauss/opengauss:5.0.0 -o opengauss-5.0.0.tar
docker save cloudcom-backend -o backend.tar
docker save cloudcom-frontend -o frontend.tar

# 传输到虚拟机
scp opengauss-5.0.0.tar backend.tar frontend.tar root@10.211.55.11:~/
scp -r . root@10.211.55.11:~/CloudCom/

# 在虚拟机上加载镜像
ssh root@10.211.55.11
cd ~/CloudCom
docker load -i ~/opengauss-5.0.0.tar
docker load -i ~/backend.tar
docker load -i ~/frontend.tar

# 部署
./scripts/deploy-opengauss-cluster.sh
```

## 验证集群

```bash
# 运行测试脚本
./scripts/test-opengauss-cluster.sh
```

测试内容包括：

1. 主库连接测试
2. 备库 1 连接测试
3. 备库 2 连接测试
4. 复制状态检查
5. 读写功能测试
6. 后端服务健康检查
7. 前端服务可访问性

## 管理命令

### 查看容器状态

```bash
docker-compose -f docker-compose-opengauss-cluster.yml ps
```

### 查看日志

```bash
# 主库日志
docker-compose -f docker-compose-opengauss-cluster.yml logs -f opengauss-primary

# 备库日志
docker-compose -f docker-compose-opengauss-cluster.yml logs -f opengauss-standby1

# 后端日志
docker-compose -f docker-compose-opengauss-cluster.yml logs -f backend
```

### 连接数据库

```bash
# 连接主库
docker exec -it opengauss-primary su - omm -c "gsql -d blog_db"

# 连接备库1
docker exec -it opengauss-standby1 su - omm -c "gsql -d blog_db"

# 连接备库2
docker exec -it opengauss-standby2 su - omm -c "gsql -d blog_db"
```

### 查看复制状态

```bash
docker exec opengauss-primary su - omm -c "gsql -d blog_db -c 'SELECT * FROM pg_stat_replication'"
```

### 停止服务

```bash
docker-compose -f docker-compose-opengauss-cluster.yml down
```

### 清理所有数据

```bash
docker-compose -f docker-compose-opengauss-cluster.yml down -v
```

## 配置说明

### openGauss 环境变量

- `GS_PASSWORD`: 数据库密码（必填）
- `GS_NODENAME`: 节点名称
- `GS_USERNAME`: 数据库用户名
- `GS_PORT`: 数据库端口（默认 5432）

### 数据持久化

数据通过 Docker volumes 持久化存储：

- `opengauss-primary-data`: 主库数据
- `opengauss-standby1-data`: 备库 1 数据
- `opengauss-standby2-data`: 备库 2 数据

### 网络配置

使用自定义 bridge 网络 `opengauss-network`（172.26.0.0/16），为每个容器分配固定 IP：

- opengauss-primary: 172.26.0.10
- opengauss-standby1: 172.26.0.11
- opengauss-standby2: 172.26.0.12

## 与 PostgreSQL 方案的对比

| 特性     | PostgreSQL 13       | openGauss 5.0.0           |
| -------- | ------------------- | ------------------------- |
| 兼容性   | 完全兼容 PostgreSQL | 基于 PostgreSQL，高度兼容 |
| 性能     | 标准性能            | 针对华为硬件优化          |
| 安全性   | 标准安全特性        | 增强安全特性（国密支持）  |
| 部署难度 | 简单                | 中等（需要特权模式）      |
| 镜像大小 | ~150MB (Alpine)     | ~400MB                    |
| 官方支持 | 社区支持            | 华为官方支持              |

## 注意事项

1. **特权模式**: openGauss 容器需要 `privileged: true`
2. **启动时间**: 首次启动需要 2-3 分钟初始化
3. **内存要求**: 建议每个数据库实例至少 256MB 内存
4. **网络限制**: 虚拟机环境需要能够访问镜像仓库，或提前下载镜像

## 故障排查

### 主库无法启动

```bash
# 查看主库日志
docker logs opengauss-primary
```

### 备库无法连接主库

```bash
# 检查网络连通性
docker exec opengauss-standby1 ping opengauss-primary

# 检查复制用户
docker exec opengauss-primary su - omm -c "gsql -d blog_db -c '\du replicator'"
```

### 数据未同步

```bash
# 查看复制延迟
docker exec opengauss-primary su - omm -c "gsql -d blog_db -c 'SELECT * FROM pg_stat_replication'"
```

## 参考资料

- [openGauss 官方文档](https://docs.opengauss.org/)
- [openGauss Docker Hub](https://hub.docker.com/r/opengauss/opengauss)
- [openGauss GitHub](https://github.com/opengauss-mirror/openGauss-server)
