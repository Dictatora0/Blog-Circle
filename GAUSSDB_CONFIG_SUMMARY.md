# GaussDB 集群配置摘要

## ✅ 配置验证状态：通过

---

## 一、集群架构

### 1.1 拓扑结构

```
┌─────────────────────────────────────────────┐
│           GaussDB 主备集群                   │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────┐                          │
│  │   Primary    │  (主库)                   │
│  │  Port: 5432  │  读写操作                 │
│  └──────┬───────┘                          │
│         │                                   │
│         │ 流复制 (Streaming Replication)    │
│         │                                   │
│    ┌────┴────┬─────────────┐              │
│    │         │             │              │
│    ▼         ▼             ▼              │
│  ┌─────┐  ┌─────┐      ┌─────┐          │
│  │ S1  │  │ S2  │      │ ... │          │
│  │5433 │  │5434 │      │     │          │
│  └─────┘  └─────┘      └─────┘          │
│  (备库1)  (备库2)                         │
│  只读      只读                            │
└─────────────────────────────────────────────┘
```

### 1.2 节点信息

| 节点     | 容器名           | 端口 | 角色 | 功能     |
| -------- | ---------------- | ---- | ---- | -------- |
| Primary  | gaussdb-primary  | 5432 | 主库 | 读写操作 |
| Standby1 | gaussdb-standby1 | 5433 | 备库 | 只读操作 |
| Standby2 | gaussdb-standby2 | 5434 | 备库 | 只读操作 |

---

## 二、技术配置

### 2.1 数据库版本

- **产品**: GaussDB (openGauss)
- **版本**: 5.0.0
- **镜像**: `opengauss/opengauss:5.0.0`
- **兼容性**: PostgreSQL 协议兼容

### 2.2 连接信息

```yaml
数据库名: blog_db
用户名: bloguser
密码: 747599qw@
字符集: UTF-8
```

### 2.3 主库配置

```yaml
服务名: gaussdb-primary
镜像: opengauss/opengauss:5.0.0
端口映射: 5432:5432
数据目录: /var/lib/opengauss
特权模式: true
环境变量:
  - GS_PASSWORD=747599qw@
  - GS_DB=blog_db
  - GS_USER=bloguser
  - GS_PORT=5432
```

### 2.4 备库配置

```yaml
# Standby1
服务名: gaussdb-standby1
镜像: opengauss/opengauss:5.0.0
端口映射: 5433:5432
复制源: gaussdb-primary:5432
复制方式: gs_basebackup (流复制)
恢复模式: standby_mode = 'on'

# Standby2
服务名: gaussdb-standby2
镜像: opengauss/opengauss:5.0.0
端口映射: 5434:5432
复制源: gaussdb-primary:5432
复制方式: gs_basebackup (流复制)
恢复模式: standby_mode = 'on'
启动延迟: 10秒 (避免与 standby1 冲突)
```

---

## 三、主备复制机制

### 3.1 复制原理

GaussDB 使用 **流复制（Streaming Replication）** 实现主备同步：

1. **主库**：

   - 接收所有写操作
   - 生成 WAL（Write-Ahead Log）日志
   - 通过流复制协议发送 WAL 到备库

2. **备库**：

   - 实时接收 WAL 日志流
   - 重放 WAL 日志恢复数据
   - 保持与主库数据一致

3. **一致性**：
   - 异步复制（微小延迟）
   - 备库数据与主库保持同步
   - 延迟通常 < 1 秒

### 3.2 初始化流程

```bash
# 备库初始化步骤
1. 清理数据目录
   rm -rf /var/lib/opengauss/*

2. 从主库复制基础数据
   gs_basebackup \
     -h gaussdb-primary \
     -p 5432 \
     -U bloguser \
     -W 747599qw@ \
     -D /var/lib/opengauss \
     -Fp \    # 普通格式
     -Xs \    # 流式传输 WAL
     -P       # 显示进度

3. 配置恢复模式
   echo "standby_mode = 'on'" >> recovery.conf
   echo "primary_conninfo = 'host=gaussdb-primary port=5432 user=bloguser password=747599qw@'" >> recovery.conf

4. 启动备库
   exec gaussdb
```

### 3.3 复制验证

```sql
-- 在主库查询复制状态
SELECT
    client_addr,      -- 备库地址
    state,            -- 复制状态 (streaming)
    sync_state        -- 同步状态
FROM pg_stat_replication;

-- 在备库查询恢复状态
SELECT pg_is_in_recovery();  -- 返回 true 表示备库模式
```

---

## 四、读写分离配置

### 4.1 数据源配置

```yaml
# application-gaussdb-cluster.yml
spring:
  datasource:
    primary: # 主库（写操作）
      url: jdbc:postgresql://gaussdb-primary:5432/blog_db
      username: bloguser
      password: 747599qw@

    replica: # 备库（读操作）
      url: jdbc:postgresql://gaussdb-standby1:5433,gaussdb-standby2:5434/blog_db?targetServerType=preferSecondary&loadBalanceHosts=true
      username: bloguser
      password: 747599qw@
      read-only: true
```

### 4.2 负载均衡

- **策略**: 轮询（Round-Robin）
- **目标**: 优先使用备库
- **参数**:
  - `targetServerType=preferSecondary` - 优先备库
  - `loadBalanceHosts=true` - 启用负载均衡

---

## 五、启动与验证

### 5.1 启动集群

```bash
# 方式1：使用启动脚本（推荐）
./start-gaussdb-cluster.sh

# 方式2：手动启动
docker compose -f docker-compose-gaussdb-pseudo.yml up -d
```

### 5.2 验证步骤

**1) 检查容器状态**

```bash
docker compose -f docker-compose-gaussdb-pseudo.yml ps
```

期望输出：3 个容器都是 `healthy` 状态

**2) 验证主库连接**

```bash
docker compose -f docker-compose-gaussdb-pseudo.yml exec gaussdb-primary \
    gsql -d blog_db -U bloguser -W 747599qw@ -c "SELECT version();"
```

**3) 查看复制状态**

```bash
docker compose -f docker-compose-gaussdb-pseudo.yml exec gaussdb-primary \
    gsql -d blog_db -U bloguser -W 747599qw@ \
    -c "SELECT client_addr, state FROM pg_stat_replication;"
```

期望输出：2 个备库，状态为 `streaming`

**4) 验证备库只读**

```bash
# 在备库执行写操作应该失败
docker compose -f docker-compose-gaussdb-pseudo.yml exec gaussdb-standby1 \
    gsql -d blog_db -U bloguser -W 747599qw@ \
    -c "CREATE TABLE test(id int);"
```

期望输出：错误（只读模式）

### 5.3 常用命令

```bash
# 查看日志
docker compose -f docker-compose-gaussdb-pseudo.yml logs gaussdb-primary
docker compose -f docker-compose-gaussdb-pseudo.yml logs gaussdb-standby1

# 进入容器
docker compose -f docker-compose-gaussdb-pseudo.yml exec gaussdb-primary bash

# 停止集群
docker compose -f docker-compose-gaussdb-pseudo.yml down

# 清理数据（慎用）
docker compose -f docker-compose-gaussdb-pseudo.yml down -v
```

---

## 六、性能优化

### 6.1 连接池配置

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
```

### 6.2 复制优化

- **wal_level**: replica（启用流复制）
- **max_wal_senders**: 10（最多 10 个复制连接）
- **wal_keep_segments**: 64（保留 WAL 段数）

### 6.3 查询优化

- 读操作自动路由到备库
- 写操作集中在主库
- 减少主库负载，提升整体性能

---

## 七、故障处理

### 7.1 主库故障

```bash
# 1. 检查主库状态
docker compose -f docker-compose-gaussdb-pseudo.yml logs gaussdb-primary

# 2. 重启主库
docker compose -f docker-compose-gaussdb-pseudo.yml restart gaussdb-primary

# 3. 如需提升备库为主库（手动故障转移）
# 在备库执行：
gs_ctl promote -D /var/lib/opengauss
```

### 7.2 备库故障

```bash
# 1. 检查备库状态
docker compose -f docker-compose-gaussdb-pseudo.yml logs gaussdb-standby1

# 2. 重启备库
docker compose -f docker-compose-gaussdb-pseudo.yml restart gaussdb-standby1

# 3. 如需重建备库
docker compose -f docker-compose-gaussdb-pseudo.yml stop gaussdb-standby1
docker volume rm cloudcom_gaussdb-data-standby1
docker compose -f docker-compose-gaussdb-pseudo.yml up -d gaussdb-standby1
```

### 7.3 复制延迟

```sql
-- 查看复制延迟
SELECT
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    sync_state
FROM pg_stat_replication;
```

---

## 八、安全配置

### 8.1 密码管理

- 主库密码：`747599qw@`
- 备库复制密码：`747599qw@`
- **生产环境建议**：使用环境变量或密钥管理系统

### 8.2 网络隔离

- 使用 Docker 网络：`gaussdb-network`
- 容器间通信隔离
- 仅暴露必要端口

### 8.3 权限控制

- 复制用户：`bloguser`（具有复制权限）
- 应用用户：`bloguser`（读写权限）
- **生产环境建议**：分离复制用户和应用用户

---

## 九、监控指标

### 9.1 关键指标

- 复制延迟（Replication Lag）
- WAL 发送速率
- 连接数
- 查询响应时间
- 磁盘使用率

### 9.2 监控查询

```sql
-- 复制状态
SELECT * FROM pg_stat_replication;

-- 数据库大小
SELECT pg_database_size('blog_db');

-- 活跃连接
SELECT count(*) FROM pg_stat_activity;

-- 慢查询
SELECT * FROM pg_stat_statements
WHERE mean_exec_time > 1000
ORDER BY mean_exec_time DESC;
```

---

## 十、配置文件清单

```
CloudCom/
├── docker-compose-gaussdb-pseudo.yml    # 主配置文件 ✓
├── start-gaussdb-cluster.sh             # 启动脚本 ✓
├── verify-gaussdb-config.sh             # 验证脚本 ✓
├── backend/src/main/resources/
│   ├── application-gaussdb-cluster.yml  # 数据源配置
│   └── db/01_init.sql                   # 初始化SQL
└── tests/
    └── run-all-tests.sh                 # 测试脚本
```

---

## ✅ 配置完成确认

- [x] GaussDB 镜像配置（opengauss/opengauss:5.0.0）
- [x] 主库配置（gaussdb-primary:5432）
- [x] 备库配置（standby1:5433, standby2:5434）
- [x] 流复制配置（gs_basebackup）
- [x] 环境变量配置
- [x] 端口映射配置
- [x] 健康检查配置
- [x] 启动脚本
- [x] 验证脚本

**状态**: ✅ 配置验证通过，可以启动集群进行测试

---

**创建日期**: 2025 年 11 月 20 日  
**配置版本**: v1.0  
**验证状态**: ✅ 通过
