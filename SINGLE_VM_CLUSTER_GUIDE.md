# GaussDB 单机一主二备集群部署指南

## 架构说明

在单个 VM (10.211.55.11) 上运行三个 GaussDB 实例：

```
┌─────────────────────────────────────┐
│   VM: 10.211.55.11                  │
│                                     │
│  ┌──────────────┐                  │
│  │ 主库 (5432)  │                  │
│  │ Primary      │                  │
│  └──────┬───────┘                  │
│         │                           │
│    ┌────┴────┐                     │
│    │         │                     │
│  ┌─▼────┐  ┌─▼────┐               │
│  │备库1 │  │备库2 │               │
│  │5433  │  │5434  │               │
│  └──────┘  └──────┘               │
└─────────────────────────────────────┘
```

## 优势

**简单**: 所有实例在同一台机器，无需配置跨网络通信
**快速**: 本地复制，延迟极低
**易管理**: 统一管理，便于监控和维护
**测试友好**: 适合开发和测试环境

## 部署步骤

### 步骤 1: 生成部署脚本

在本地 Mac 运行：

```bash
cd /Users/lifulin/Desktop/CloudCom
chmod +x setup-gaussdb-single-vm-cluster.sh
./setup-gaussdb-single-vm-cluster.sh > /tmp/vm_cluster_setup.sh
```

### 步骤 2: 将脚本复制到 VM

```bash
# 方法 1: 使用 scp（如果可以）
scp /tmp/vm_cluster_setup.sh root@10.211.55.11:/tmp/

# 方法 2: 手动复制
# 打开 /tmp/vm_cluster_setup.sh，复制内容
# 在 VM 上创建文件并粘贴
```

### 步骤 3: 在 VM 上执行部署

SSH 到 VM 并执行：

```bash
ssh root@10.211.55.11

# 赋予执行权限
chmod +x /tmp/vm_cluster_setup.sh

# 执行部署（大约需要 2-3 分钟）
/tmp/vm_cluster_setup.sh
```

### 步骤 4: 验证部署

回到本地 Mac，运行验证脚本：

```bash
cd /Users/lifulin/Desktop/CloudCom
chmod +x test-gaussdb-single-vm-cluster.sh
./test-gaussdb-single-vm-cluster.sh
```

## 预期输出

如果部署成功，你应该看到：

```
=========================================
   测试结果
=========================================

总测试数: 12
通过: 12
失败: 0
通过率: 100%

✓ 所有测试通过！GaussDB 单机一主二备集群部署成功。

集群信息:
  主库: 10.211.55.11:5432
  备库1: 10.211.55.11:5433
  备库2: 10.211.55.11:5434
  数据库: blog_db
  用户: bloguser
```

## 连接信息

部署完成后，可以通过以下方式连接：

### 主库（读写）

```bash
docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \
  psql -h 10.211.55.11 -p 5432 -U bloguser -d blog_db
```

### 备库 1（只读）

```bash
docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \
  psql -h 10.211.55.11 -p 5433 -U bloguser -d blog_db
```

### 备库 2（只读）

```bash
docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \
  psql -h 10.211.55.11 -p 5434 -U bloguser -d blog_db
```

## 管理命令

### 查看所有实例状态

```bash
# 在 VM 上执行
su - omm -c "ps aux | grep gaussdb"
```

### 停止所有实例

```bash
# 在 VM 上执行
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_primary"
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_standby1"
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_standby2"
```

### 启动所有实例

```bash
# 在 VM 上执行
su - omm -c "gs_ctl start -D /usr/local/opengauss/data_primary"
su - omm -c "gs_ctl start -D /usr/local/opengauss/data_standby1"
su - omm -c "gs_ctl start -D /usr/local/opengauss/data_standby2"
```

### 查看复制状态

```bash
# 在主库查看
su - omm -c "gsql -d postgres -p 5432 -c 'SELECT * FROM pg_stat_replication;'"
```

## 故障排查

### 问题 1: 端口冲突

**症状**: 启动失败，提示端口已被占用

**解决**:

```bash
# 检查端口占用
netstat -tlnp | grep -E '5432|5433|5434'

# 停止占用端口的进程
kill -9 <PID>
```

### 问题 2: 数据目录权限错误

**症状**: 启动失败，提示权限不足

**解决**:

```bash
chown -R omm:dbgrp /usr/local/opengauss/data_*
chmod 700 /usr/local/opengauss/data_*
```

### 问题 3: 复制未建立

**症状**: 备库启动但未连接到主库

**解决**:

```bash
# 检查备库日志
tail -f /usr/local/opengauss/data_standby1/pg_log/*.log

# 检查 standby.signal 文件是否存在
ls -la /usr/local/opengauss/data_standby1/standby.signal

# 检查 postgresql.auto.conf 配置
cat /usr/local/opengauss/data_standby1/postgresql.auto.conf
```

## 性能优化建议

### 1. 调整 WAL 保留大小

```sql
-- 在主库执行
ALTER SYSTEM SET wal_keep_size = '2GB';
SELECT pg_reload_conf();
```

### 2. 启用同步复制（可选）

```sql
-- 在主库执行
ALTER SYSTEM SET synchronous_standby_names = 'FIRST 1 (standby1, standby2)';
SELECT pg_reload_conf();
```

### 3. 调整连接数

```sql
-- 根据需要调整
ALTER SYSTEM SET max_connections = 300;
-- 需要重启生效
```

## 下一步

部署成功后，可以：

1. 运行后端服务测试: `./test-local-services.sh`
2. 配置应用连接到主库 (10.211.55.11:5432)
3. 配置读写分离（主库写，备库读）
4. 测试故障切换（手动提升备库为主库）

## 清理和重置

如需重新部署：

```bash
# 在 VM 上执行
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_primary" || true
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_standby1" || true
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_standby2" || true

rm -rf /usr/local/opengauss/data_primary
rm -rf /usr/local/opengauss/data_standby1
rm -rf /usr/local/opengauss/data_standby2

# 然后重新执行部署脚本
```
