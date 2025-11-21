#!/bin/bash

# GaussDB 集群初始化脚本
# 在主库 (10.211.55.11) 上执行

set -e

echo "========================================="
echo "   GaussDB 集群初始化"
echo "========================================="
echo ""

# 数据库配置
DB_NAME="blog_db"
DB_USER="bloguser"
DB_PASS="blogpass"
PRIMARY_IP="10.211.55.11"
STANDBY1_IP="10.211.55.14"
STANDBY2_IP="10.211.55.13"

echo "1. 创建数据库和用户..."
su - omm -c "gsql -d postgres -p 5432 -c \"CREATE DATABASE ${DB_NAME};\"" || echo "数据库已存在"
su - omm -c "gsql -d postgres -p 5432 -c \"CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';\"" || echo "用户已存在"
su - omm -c "gsql -d postgres -p 5432 -c \"GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};\""
su - omm -c "gsql -d postgres -p 5432 -c \"ALTER USER ${DB_USER} WITH REPLICATION;\""

echo ""
echo "2. 配置 pg_hba.conf 允许远程连接..."
PG_HBA="/gaussdb/data/pg_hba.conf"

# 备份原文件
cp ${PG_HBA} ${PG_HBA}.backup.$(date +%Y%m%d_%H%M%S)

# 添加访问规则
cat >> ${PG_HBA} << EOF

# Blog Circle 应用访问
host    ${DB_NAME}    ${DB_USER}    0.0.0.0/0    md5
host    all           ${DB_USER}    0.0.0.0/0    md5

# 容器网络访问
host    ${DB_NAME}    ${DB_USER}    172.16.0.0/12    md5
host    all           ${DB_USER}    172.16.0.0/12    md5

# 主备复制
host    replication   all           ${STANDBY1_IP}/32    trust
host    replication   all           ${STANDBY2_IP}/32    trust
EOF

echo ""
echo "3. 配置 postgresql.conf..."
PG_CONF="/gaussdb/data/postgresql.conf"

# 备份原文件
cp ${PG_CONF} ${PG_CONF}.backup.$(date +%Y%m%d_%H%M%S)

# 修改配置
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" ${PG_CONF}
sed -i "s/#max_connections = 100/max_connections = 200/g" ${PG_CONF}
sed -i "s/#wal_level = replica/wal_level = replica/g" ${PG_CONF}
sed -i "s/#max_wal_senders = 10/max_wal_senders = 10/g" ${PG_CONF}
sed -i "s/#wal_keep_segments = 0/wal_keep_segments = 64/g" ${PG_CONF}

echo ""
echo "4. 重启 GaussDB 服务..."
su - omm -c "gs_ctl restart -D /gaussdb/data"

echo ""
echo "5. 等待服务启动..."
sleep 10

echo ""
echo "6. 验证配置..."
su - omm -c "gsql -d ${DB_NAME} -p 5432 -c \"SELECT version();\""
su - omm -c "gsql -d postgres -p 5432 -c \"SELECT * FROM pg_stat_replication;\""

echo ""
echo "7. 创建表结构..."
su - omm -c "gsql -d ${DB_NAME} -p 5432" << 'EOSQL'
-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    nickname VARCHAR(50),
    avatar VARCHAR(255),
    email VARCHAR(100),
    bio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 文章表
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    author_id INTEGER REFERENCES users(id),
    view_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 评论表
CREATE TABLE IF NOT EXISTS comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 统计表
CREATE TABLE IF NOT EXISTS statistics (
    id SERIAL PRIMARY KEY,
    stat_type VARCHAR(50) NOT NULL,
    stat_key VARCHAR(100) NOT NULL,
    stat_value BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stat_type, stat_key)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_user ON comments(user_id);
CREATE INDEX IF NOT EXISTS idx_statistics_type_key ON statistics(stat_type, stat_key);

-- 授权
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO bloguser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO bloguser;

\q
EOSQL

echo ""
echo "8. 插入测试数据..."
su - omm -c "gsql -d ${DB_NAME} -p 5432" << 'EOSQL'
-- 插入测试用户
INSERT INTO users (username, password, nickname, email) VALUES
('admin', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH', '管理员', 'admin@example.com'),
('testuser', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH', '测试用户', 'test@example.com')
ON CONFLICT (username) DO NOTHING;

\q
EOSQL

echo ""
echo "========================================="
echo "   初始化完成"
echo "========================================="
echo ""
echo "数据库信息："
echo "  主库: ${PRIMARY_IP}:5432"
echo "  备库1: ${STANDBY1_IP}:5432"
echo "  备库2: ${STANDBY2_IP}:5432"
echo "  数据库: ${DB_NAME}"
echo "  用户: ${DB_USER}"
echo "  密码: ${DB_PASS}"
echo ""
echo "测试连接："
echo "  gsql -h ${PRIMARY_IP} -p 5432 -d ${DB_NAME} -U ${DB_USER}"
echo ""
