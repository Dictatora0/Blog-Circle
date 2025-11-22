#!/bin/bash
set -e

echo "=== Initializing openGauss Primary ==="

# 等待数据库完全启动
sleep 15

# 创建复制用户
su - omm -c "gsql -d postgres -p 5432 << EOF
-- 创建复制用户
CREATE USER replicator WITH REPLICATION PASSWORD 'Blog@2025';

-- 创建应用数据库
CREATE DATABASE blog_db;

-- 授予权限
GRANT ALL PRIVILEGES ON DATABASE blog_db TO bloguser;

-- 配置 pg_hba.conf 允许复制连接
\! echo 'host replication replicator 172.26.0.0/16 md5' >> /var/lib/opengauss/data/pg_hba.conf
\! echo 'host all bloguser 172.26.0.0/16 md5' >> /var/lib/opengauss/data/pg_hba.conf
\! echo 'host all all 0.0.0.0/0 md5' >> /var/lib/opengauss/data/pg_hba.conf

EOF
"

# 重新加载配置
su - omm -c 'gs_ctl reload -D /var/lib/opengauss/data'

echo "=== Primary initialization completed ==="
