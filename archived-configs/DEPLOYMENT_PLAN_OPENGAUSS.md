# openGauss 集群容器化部署计划

## 目标

在虚拟机 10.211.55.11 上使用真实 openGauss 5.0.0 部署一主二备集群。

## 准备工作

### ✅ 已完成

1. ✅ Docker Compose 配置文件创建 (`docker-compose-opengauss-cluster.yml`)
2. ✅ 初始化脚本编写 (`opengauss-init-primary.sh`, `opengauss-init-standby.sh`)
3. ✅ 部署脚本完成 (`deploy-opengauss-cluster.sh`)
4. ✅ 测试脚本完成 (`test-opengauss-cluster.sh`)
5. ✅ 虚拟机一键部署脚本 (`vm-deploy-opengauss.sh`)
6. ✅ 后端配置文件 (`application-opengauss-cluster.yml`)
7. ✅ 文档完成 (README, 部署指南, 迁移总结)
8. ✅ 脚本执行权限已设置

### ⏳ 待执行

1. ⏳ 在本地测试部署流程
2. ⏳ 在虚拟机上执行部署
3. ⏳ 运行完整测试套件
4. ⏳ 更新 LaTeX 报告

## 部署步骤

### 步骤 1: 本地测试（可选）

```bash
# 在本地先测试部署流程
cd /Users/lifulin/Desktop/CloudCom
./scripts/deploy-opengauss-cluster.sh

# 等待 2-3 分钟后运行测试
./scripts/test-opengauss-cluster.sh

# 如果测试通过，清理本地环境
docker-compose -f docker-compose-opengauss-cluster.yml down -v
```

**预期结果**:

- 所有容器状态为 healthy
- 测试脚本显示 "所有测试通过！"

### 步骤 2: 虚拟机一键部署

```bash
# 确保已安装 sshpass
# macOS: brew install sshpass

# 执行一键部署到虚拟机
cd /Users/lifulin/Desktop/CloudCom
./scripts/vm-deploy-opengauss.sh
```

**该脚本会自动完成**:

1. 拉取 openGauss 5.0.0 镜像
2. 构建后端和前端镜像
3. 保存镜像为 tar 文件
4. 传输镜像和项目文件到虚拟机
5. 在虚拟机上加载镜像
6. 部署 openGauss 集群
7. 运行完整测试

**预计时间**: 15-20 分钟

### 步骤 3: 手动验证（备选方案）

如果一键脚本失败，可以手动执行：

```bash
# 1. 本地准备镜像
docker pull opengauss/opengauss:5.0.0
docker-compose -f docker-compose-opengauss-cluster.yml build
docker save opengauss/opengauss:5.0.0 -o opengauss-5.0.0.tar
docker save cloudcom-backend:latest -o backend.tar
docker save cloudcom-frontend:latest -o frontend.tar

# 2. 传输到虚拟机
scp opengauss-5.0.0.tar backend.tar frontend.tar root@10.211.55.11:~/
scp -r . root@10.211.55.11:~/CloudCom/

# 3. SSH 到虚拟机
ssh root@10.211.55.11

# 4. 加载镜像
cd ~/CloudCom
docker load -i ~/opengauss-5.0.0.tar
docker load -i ~/backend.tar
docker load -i ~/frontend.tar

# 5. 部署
chmod +x scripts/*.sh
./scripts/deploy-opengauss-cluster.sh

# 6. 测试
./scripts/test-opengauss-cluster.sh
```

### 步骤 4: 验证部署

SSH 到虚拟机后执行：

```bash
cd ~/CloudCom

# 1. 查看容器状态
docker-compose -f docker-compose-opengauss-cluster.yml ps

# 2. 查看主库状态
docker exec opengauss-primary su - omm -c "gs_ctl query -D /var/lib/opengauss/data"

# 3. 查看复制状态
docker exec opengauss-primary su - omm -c "gsql -d blog_db -c 'SELECT * FROM pg_stat_replication'"

# 4. 测试前端访问
curl -I http://localhost:8080

# 5. 测试后端健康
curl http://localhost:8082/actuator/health
```

**预期结果**:

```
opengauss-primary    running   (healthy)
opengauss-standby1   running   (healthy)
opengauss-standby2   running   (healthy)
backend              running   (healthy)
frontend             running   (healthy)

复制连接数: 2/2
应用状态: UP
```

## 测试清单

### 数据库层测试

- [ ] 主库可以连接
- [ ] 备库 1 可以连接且处于恢复模式
- [ ] 备库 2 可以连接且处于恢复模式
- [ ] 复制连接数为 2/2
- [ ] 主库写入数据
- [ ] 备库 1 可以读取同步的数据
- [ ] 备库 2 可以读取同步的数据

### 应用层测试

- [ ] 后端服务健康检查通过
- [ ] 后端可以连接主库
- [ ] 后端读写分离功能正常
- [ ] 前端页面可以访问
- [ ] 前端可以通过 Nginx 代理访问后端 API

### 性能测试

- [ ] 后端 API 响应时间 < 100ms
- [ ] 前端页面加载时间 < 500ms
- [ ] 主备复制延迟 < 5 秒

## 成功标准

部署成功需满足：

1. ✅ 所有 5 个容器状态为 `healthy`
2. ✅ 2/2 备库流复制连接正常
3. ✅ 主备数据同步功能正常
4. ✅ 测试脚本 100% 通过
5. ✅ 前端页面可以访问（HTTP 200）
6. ✅ 后端健康检查通过（status: UP）

## 回滚方案

如果 openGauss 部署失败，可以回退到 PostgreSQL 13：

```bash
# 停止 openGauss 集群
docker-compose -f docker-compose-opengauss-cluster.yml down -v

# 启动 PostgreSQL 13 集群
docker-compose -f docker-compose-gaussdb-cluster.yml up -d

# 验证
./scripts/test_complete.sh
```

## 时间表

| 步骤       | 预计时间       | 说明            |
| ---------- | -------------- | --------------- |
| 本地测试   | 10-15 分钟     | 可选步骤        |
| 镜像准备   | 5-10 分钟      | 拉取和构建      |
| 文件传输   | 5-10 分钟      | 传输约 1GB 数据 |
| 虚拟机部署 | 5-10 分钟      | 加载镜像和启动  |
| 测试验证   | 5 分钟         | 运行测试脚本    |
| **总计**   | **30-50 分钟** | 完整流程        |

## 资源需求

### 虚拟机资源

- **CPU**: 4 核（已满足）
- **内存**: 8GB（已满足）
- **磁盘**: 20GB 可用空间
- **网络**: 能够访问 Docker Hub（可选）

### 镜像大小

- openGauss 5.0.0: ~400MB
- Backend: ~300MB
- Frontend: ~100MB
- **总计**: ~800MB

## 监控指标

部署后需要监控：

1. **容器状态**: `docker ps`
2. **容器资源**: `docker stats`
3. **复制延迟**: `pg_stat_replication`
4. **应用日志**: `docker-compose logs`

## 下一步

部署成功后：

1. 更新 LaTeX 报告，将 PostgreSQL 13 相关内容改为 openGauss 5.0.0
2. 截取部署和测试的截图
3. 记录性能数据
4. 撰写部署总结

## 联系信息

如有问题：

- 查看日志: `docker-compose logs -f`
- 查看文档: `OPENGAUSS_DEPLOYMENT.md`
- 查看迁移指南: `OPENGAUSS_MIGRATION_SUMMARY.md`
