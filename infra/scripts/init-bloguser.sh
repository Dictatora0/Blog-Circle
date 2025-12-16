#!/bin/bash
###############################################################
# 初始化 openGauss bloguser 和 blog_db
# 在 VM 上的 openGauss 容器内执行
###############################################################

set -e

CONTAINER_NAME="${1:-docker-compose_opengauss-primary_1}"

echo "正在初始化 bloguser 和 blog_db..."

# 直接通过 gsql -c 执行 SQL，避免文件引号问题
docker exec "$CONTAINER_NAME" su - omm -c "gsql -d postgres -p 5432 -c \"DROP DATABASE IF EXISTS blog_db;\""
docker exec "$CONTAINER_NAME" su - omm -c "gsql -d postgres -p 5432 -c \"DROP USER IF EXISTS bloguser CASCADE;\""
docker exec "$CONTAINER_NAME" su - omm -c "gsql -d postgres -p 5432 -c \"CREATE USER bloguser WITH PASSWORD 'Blog@2025';\""
docker exec "$CONTAINER_NAME" su - omm -c "gsql -d postgres -p 5432 -c \"ALTER USER bloguser SYSADMIN;\""
docker exec "$CONTAINER_NAME" su - omm -c "gsql -d postgres -p 5432 -c \"CREATE DATABASE blog_db OWNER bloguser;\""
docker exec "$CONTAINER_NAME" su - omm -c "gsql -d postgres -p 5432 -c \"GRANT ALL PRIVILEGES ON DATABASE blog_db TO bloguser;\""

echo "bloguser 和 blog_db 初始化完成"
echo ""
echo "验证用户创建："
docker exec "$CONTAINER_NAME" su - omm -c "gsql -d postgres -p 5432 -c \"SELECT usename FROM pg_user WHERE usename='bloguser';\""
