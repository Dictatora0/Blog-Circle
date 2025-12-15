## 执行的操作

### 1. 创建数据库用户

```bash
# 在备库1创建 bloguser 用户
CREATE USER bloguser WITH PASSWORD 'Blog@2025' CREATEDB;

# 在备库2创建 bloguser 用户
CREATE USER bloguser WITH PASSWORD 'Blog@2025' CREATEDB;
```

### 2. 导出主库数据

```bash
# 从 opengauss-primary 导出 blog_db
gs_dump blog_db -f /home/omm/blog_db_backup.sql -F p --no-owner
# 导出文件大小: 20KB
# 包含: 515 个数据库对象
```

### 3. 导入到备库 1

```bash
# 创建数据库
CREATE DATABASE blog_db OWNER bloguser;

# 导入数据
gsql -d blog_db -p 15432 -f /home/omm/blog_db_backup.sql
```

### 4. 导入到备库 2

```bash
# 创建数据库
CREATE DATABASE blog_db OWNER bloguser;

# 导入数据
gsql -d blog_db -p 25432 -f /home/omm/blog_db_backup.sql
```

### 后续数据变化

**主库新增数据后:**

- 主库: 会有新数据
- 备库 1: 不会自动更新（保持旧数据）
- 备库 2: 不会自动更新（保持旧数据）

**需要再次同步时:**

```bash
# 在虚拟机上执行
cd ~/CloudCom
./scripts/sync-data-to-standbys.sh
```

## 🔍 验证命令

### 快速检查三个数据库的数据量

```bash
# 在虚拟机上执行
ssh root@10.211.55.11

# 主库
docker exec opengauss-primary bash -c 'su - omm -c "gsql -d blog_db -c \"SELECT COUNT(*) FROM users;\""'

# 备库1 (端口 15432)
docker exec opengauss-standby1 bash -c 'su - omm -c "gsql -d blog_db -p 15432 -c \"SELECT COUNT(*) FROM users;\""'

# 备库2 (端口 25432)
docker exec opengauss-standby2 bash -c 'su - omm -c "gsql -d blog_db -p 25432 -c \"SELECT COUNT(*) FROM users;\""'
```

### 检查表结构

```bash
# 主库表列表
docker exec opengauss-primary bash -c 'su - omm -c "gsql -d blog_db -c \"\\dt\""'

# 备库1表列表
docker exec opengauss-standby1 bash -c 'su - omm -c "gsql -d blog_db -p 15432 -c \"\\dt\""'

# 备库2表列表
docker exec opengauss-standby2 bash -c 'su - omm -c "gsql -d blog_db -p 25432 -c \"\\dt\""'
```
