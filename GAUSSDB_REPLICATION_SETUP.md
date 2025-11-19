# GaussDB 一主二备流复制配置指南

## 集群架构

- **主库 (Primary)**: 10.211.55.11:5432
- **备库 1 (Standby1)**: 10.211.55.14:5432
- **备库 2 (Standby2)**: 10.211.55.13:5432

## 当前状态

三个节点已部署并运行
主备角色已正确设置
❌ 流复制未配置（备库未连接到主库）

---

## 配置步骤

### 步骤 1: 在主库 (10.211.55.11) 上配置

#### 1.1 创建复制用户

```bash
# SSH 到主库
ssh root@10.211.55.11

# 切换到 omm 用户
su - omm

# 创建复制用户
gsql -d postgres -p 5432 -c "CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '747599qw@';"
```

#### 1.2 配置 pg_hba.conf 允许复制连接

```bash
# 编辑 pg_hba.conf
vi /usr/local/opengauss/data/pg_hba.conf

# 在文件末尾添加以下两行：
host    replication     replicator     10.211.55.14/32       md5
host    replication     replicator     10.211.55.13/32       md5
```

#### 1.3 创建复制槽（推荐）

```bash
# 为两个备库创建复制槽
gsql -d postgres -p 5432 -c "SELECT pg_create_physical_replication_slot('standby1_slot');"
gsql -d postgres -p 5432 -c "SELECT pg_create_physical_replication_slot('standby2_slot');"
```

#### 1.4 重新加载配置

```bash
# 重新加载配置（不需要重启）
gsql -d postgres -p 5432 -c "SELECT pg_reload_conf();"

# 或者重启数据库
gs_ctl restart -D /usr/local/opengauss/data
```

---

### 步骤 2: 在备库 1 (10.211.55.14) 上配置

#### 2.1 停止数据库

```bash
# SSH 到备库1
ssh root@10.211.55.14

# 切换到 omm 用户
su - omm

# 停止数据库
gs_ctl stop -D /usr/local/opengauss/data
```

#### 2.2 备份现有数据（重要！）

```bash
# 备份现有数据目录
mv /usr/local/opengauss/data /usr/local/opengauss/data.backup.$(date +%Y%m%d)
```

#### 2.3 从主库同步数据

```bash
# 使用 gs_basebackup 从主库同步数据
gs_basebackup -h 10.211.55.11 -p 5432 -U replicator -D /usr/local/opengauss/data -Fp -Xs -P -R

# 输入密码: 747599qw@
```

**参数说明**:

- `-h`: 主库地址
- `-p`: 主库端口
- `-U`: 复制用户
- `-D`: 数据目录
- `-Fp`: 普通格式
- `-Xs`: 流式传输 WAL
- `-P`: 显示进度
- `-R`: 自动创建 standby 配置

#### 2.4 配置复制参数（如果 -R 未自动创建）

```bash
# 编辑 postgresql.auto.conf 或 postgresql.conf
vi /usr/local/opengauss/data/postgresql.auto.conf

# 添加以下配置：
primary_conninfo = 'host=10.211.55.11 port=5432 user=replicator password=747599qw@ application_name=standby1'
primary_slot_name = 'standby1_slot'
hot_standby = on
```

#### 2.5 创建 standby.signal 文件

```bash
# 创建 standby.signal 标记文件
touch /usr/local/opengauss/data/standby.signal
```

#### 2.6 启动备库

```bash
# 启动数据库
gs_ctl start -D /usr/local/opengauss/data
```

---

### 步骤 3: 在备库 2 (10.211.55.13) 上配置

重复步骤 2 的所有操作，但注意以下修改：

#### 3.1 修改 application_name 和 slot_name

```bash
# postgresql.auto.conf 中的配置：
primary_conninfo = 'host=10.211.55.11 port=5432 user=replicator password=747599qw@ application_name=standby2'
primary_slot_name = 'standby2_slot'
hot_standby = on
```

#### 3.2 执行相同的同步和启动步骤

```bash
# SSH 到备库2
ssh root@10.211.55.13

# 切换到 omm 用户
su - omm

# 停止数据库
gs_ctl stop -D /usr/local/opengauss/data

# 备份数据
mv /usr/local/opengauss/data /usr/local/opengauss/data.backup.$(date +%Y%m%d)

# 从主库同步
gs_basebackup -h 10.211.55.11 -p 5432 -U replicator -D /usr/local/opengauss/data -Fp -Xs -P -R

# 创建 standby.signal
touch /usr/local/opengauss/data/standby.signal

# 启动数据库
gs_ctl start -D /usr/local/opengauss/data
```

---

## 验证复制配置

### 在本地 Mac 上执行验证

```bash
# 运行测试脚本
cd /Users/lifulin/Desktop/CloudCom
./test-gaussdb-cluster.sh
```

### 手动验证命令

#### 1. 检查主库复制状态

```bash
docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \
  psql -h 10.211.55.11 -p 5432 -U bloguser -d postgres \
  -c "SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;"
```

**期望输出**:

```
 application_name | client_addr  |   state   | sync_state
------------------+--------------+-----------+------------
 standby1         | 10.211.55.14 | streaming | async
 standby2         | 10.211.55.13 | streaming | async
```

#### 2. 检查备库复制状态

```bash
# 备库1
docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \
  psql -h 10.211.55.14 -p 5432 -U bloguser -d postgres \
  -c "SELECT pg_is_in_recovery();"

# 备库2
docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \
  psql -h 10.211.55.13 -p 5432 -U bloguser -d postgres \
  -c "SELECT pg_is_in_recovery();"
```

**期望输出**: `t` (true，表示处于恢复模式)

#### 3. 测试数据同步

```bash
# 在主库插入数据
docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \
  psql -h 10.211.55.11 -p 5432 -U bloguser -d blog_db \
  -c "CREATE TABLE repl_test (id INT, data TEXT); INSERT INTO repl_test VALUES (1, 'test');"

# 等待 2 秒

# 在备库1查询
docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \
  psql -h 10.211.55.14 -p 5432 -U bloguser -d blog_db \
  -c "SELECT * FROM repl_test;"

# 在备库2查询
docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \
  psql -h 10.211.55.13 -p 5432 -U bloguser -d blog_db \
  -c "SELECT * FROM repl_test;"

# 清理测试表
docker run --rm -e PGPASSWORD=747599qw@ postgres:15-alpine \
  psql -h 10.211.55.11 -p 5432 -U bloguser -d blog_db \
  -c "DROP TABLE repl_test;"
```

---

## 常见问题排查

### 问题 1: 复制用户连接失败

**症状**: `FATAL: no pg_hba.conf entry for replication`

**解决**:

1. 检查主库 `pg_hba.conf` 是否添加了复制连接规则
2. 确保执行了 `pg_reload_conf()` 或重启了数据库

### 问题 2: 备库无法连接主库

**症状**: `could not connect to the primary server`

**解决**:

1. 检查网络连通性: `ping 10.211.55.11`
2. 检查端口开放: `nc -zv 10.211.55.11 5432`
3. 检查防火墙规则

### 问题 3: 复制槽不存在

**症状**: `replication slot "standby1_slot" does not exist`

**解决**:

1. 在主库创建复制槽，或
2. 在备库配置中移除 `primary_slot_name` 参数

### 问题 4: 数据不同步

**症状**: 主库数据变更后，备库没有更新

**解决**:

1. 检查复制状态: `SELECT * FROM pg_stat_replication;`
2. 检查复制延迟: `SELECT pg_wal_lsn_diff(sent_lsn, replay_lsn) FROM pg_stat_replication;`
3. 检查备库日志: `tail -f /usr/local/opengauss/data/pg_log/*.log`

---

## 快速配置脚本（在 VM 上执行）

### 主库配置脚本

```bash
#!/bin/bash
# 在主库 10.211.55.11 上执行

su - omm << 'EOF'
# 创建复制用户
gsql -d postgres -p 5432 -c "CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '747599qw@';"

# 创建复制槽
gsql -d postgres -p 5432 -c "SELECT pg_create_physical_replication_slot('standby1_slot');"
gsql -d postgres -p 5432 -c "SELECT pg_create_physical_replication_slot('standby2_slot');"

# 添加 pg_hba.conf 规则
echo "host    replication     replicator     10.211.55.14/32       md5" >> /usr/local/opengauss/data/pg_hba.conf
echo "host    replication     replicator     10.211.55.13/32       md5" >> /usr/local/opengauss/data/pg_hba.conf

# 重新加载配置
gsql -d postgres -p 5432 -c "SELECT pg_reload_conf();"

echo "主库配置完成！"
EOF
```

### 备库配置脚本

```bash
#!/bin/bash
# 在备库上执行（修改 STANDBY_NAME 和 SLOT_NAME）

STANDBY_NAME="standby1"  # 备库2改为 standby2
SLOT_NAME="standby1_slot"  # 备库2改为 standby2_slot

su - omm << EOF
# 停止数据库
gs_ctl stop -D /usr/local/opengauss/data

# 备份数据
mv /usr/local/opengauss/data /usr/local/opengauss/data.backup.\$(date +%Y%m%d)

# 从主库同步
gs_basebackup -h 10.211.55.11 -p 5432 -U replicator -W -D /usr/local/opengauss/data -Fp -Xs -P -R

# 配置复制参数
cat >> /usr/local/opengauss/data/postgresql.auto.conf << PGCONF
primary_conninfo = 'host=10.211.55.11 port=5432 user=replicator password=747599qw@ application_name=${STANDBY_NAME}'
primary_slot_name = '${SLOT_NAME}'
hot_standby = on
PGCONF

# 创建 standby.signal
touch /usr/local/opengauss/data/standby.signal

# 启动数据库
gs_ctl start -D /usr/local/opengauss/data

echo "备库配置完成！"
EOF
```

---

## 配置完成后的验证清单

- [ ] 主库 `pg_stat_replication` 显示两个备库连接
- [ ] 备库 `pg_is_in_recovery()` 返回 `t`
- [ ] 主库插入数据后，备库能查询到相同数据
- [ ] 备库拒绝写操作（返回 read-only 错误）
- [ ] 运行 `./test-gaussdb-cluster.sh` 所有测试通过

---

## 下一步

配置完成后，在本地 Mac 运行：

```bash
cd /Users/lifulin/Desktop/CloudCom
./test-gaussdb-cluster.sh
```

如果所有测试通过，GaussDB 一主二备集群部署成功！
