#!/bin/bash

# 将主库数据同步到备库
# 使用方法：在虚拟机上执行此脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  openGauss 数据同步工具"
echo "  主库 → 备库1, 备库2"
echo "=========================================="
echo ""

# 数据库连接信息
DB_NAME="blog_db"
DUMP_FILE="/tmp/blog_db_backup.sql"

# 1. 从主库导出数据
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 1: 从主库导出数据"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}正在从 opengauss-primary 导出数据...${NC}"

docker exec opengauss-primary bash -c "su - omm -c \"gs_dump ${DB_NAME} -f ${DUMP_FILE} -F p --no-owner\"" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 主库数据导出成功${NC}"
    
    # 显示导出文件大小
    DUMP_SIZE=$(docker exec opengauss-primary bash -c "ls -lh ${DUMP_FILE}" | awk '{print $5}')
    echo "  导出文件大小: ${DUMP_SIZE}"
    
    # 显示数据统计
    echo ""
    echo "数据统计："
    docker exec opengauss-primary bash -c "su - omm -c \"gsql -d ${DB_NAME} -t -c 'SELECT '\''users'\'' as table_name, COUNT(*) as count FROM users UNION ALL SELECT '\''posts'\'', COUNT(*) FROM posts UNION ALL SELECT '\''comments'\'', COUNT(*) FROM comments;'\"" 2>/dev/null | grep -v "^$"
else
    echo -e "${RED}✗ 主库数据导出失败${NC}"
    exit 1
fi

echo ""

# 2. 同步到备库1
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 2: 同步到备库1 (opengauss-standby1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 复制导出文件到备库1
echo -e "${BLUE}复制数据文件到备库1...${NC}"
docker cp opengauss-primary:${DUMP_FILE} /tmp/blog_db_backup.sql
docker cp /tmp/blog_db_backup.sql opengauss-standby1:${DUMP_FILE}

# 检查备库1是否有blog_db数据库，如果没有则创建
echo -e "${BLUE}准备备库1数据库...${NC}"
docker exec opengauss-standby1 bash -c "su - omm -c \"gsql -d postgres -p 15432 -c 'SELECT 1 FROM pg_database WHERE datname='\''${DB_NAME}'\''' \" " 2>/dev/null | grep -q "1" || \
docker exec opengauss-standby1 bash -c "su - omm -c \"gsql -d postgres -p 15432 -c 'CREATE DATABASE ${DB_NAME};'\"" 2>/dev/null

# 清空现有数据（如果有）
echo -e "${BLUE}清空备库1现有数据...${NC}"
docker exec opengauss-standby1 bash -c "su - omm -c \"gsql -d ${DB_NAME} -p 15432 -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'\"" 2>/dev/null || true

# 导入数据
echo -e "${BLUE}导入数据到备库1...${NC}"
docker exec opengauss-standby1 bash -c "su - omm -c \"gsql -d ${DB_NAME} -p 15432 -f ${DUMP_FILE}\"" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 备库1数据同步成功${NC}"
    
    # 验证数据
    echo "验证备库1数据："
    docker exec opengauss-standby1 bash -c "su - omm -c \"gsql -d ${DB_NAME} -p 15432 -t -c 'SELECT '\''users'\'' as table_name, COUNT(*) as count FROM users UNION ALL SELECT '\''posts'\'', COUNT(*) FROM posts UNION ALL SELECT '\''comments'\'', COUNT(*) FROM comments;'\"" 2>/dev/null | grep -v "^$"
else
    echo -e "${RED}✗ 备库1数据同步失败${NC}"
fi

echo ""

# 3. 同步到备库2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 3: 同步到备库2 (opengauss-standby2)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 复制导出文件到备库2
echo -e "${BLUE}复制数据文件到备库2...${NC}"
docker cp /tmp/blog_db_backup.sql opengauss-standby2:${DUMP_FILE}

# 检查备库2是否有blog_db数据库，如果没有则创建
echo -e "${BLUE}准备备库2数据库...${NC}"
docker exec opengauss-standby2 bash -c "su - omm -c \"gsql -d postgres -p 25432 -c 'SELECT 1 FROM pg_database WHERE datname='\''${DB_NAME}'\''' \" " 2>/dev/null | grep -q "1" || \
docker exec opengauss-standby2 bash -c "su - omm -c \"gsql -d postgres -p 25432 -c 'CREATE DATABASE ${DB_NAME};'\"" 2>/dev/null

# 清空现有数据（如果有）
echo -e "${BLUE}清空备库2现有数据...${NC}"
docker exec opengauss-standby2 bash -c "su - omm -c \"gsql -d ${DB_NAME} -p 25432 -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'\"" 2>/dev/null || true

# 导入数据
echo -e "${BLUE}导入数据到备库2...${NC}"
docker exec opengauss-standby2 bash -c "su - omm -c \"gsql -d ${DB_NAME} -p 25432 -f ${DUMP_FILE}\"" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 备库2数据同步成功${NC}"
    
    # 验证数据
    echo "验证备库2数据："
    docker exec opengauss-standby2 bash -c "su - omm -c \"gsql -d ${DB_NAME} -p 25432 -t -c 'SELECT '\''users'\'' as table_name, COUNT(*) as count FROM users UNION ALL SELECT '\''posts'\'', COUNT(*) FROM posts UNION ALL SELECT '\''comments'\'', COUNT(*) FROM comments;'\"" 2>/dev/null | grep -v "^$"
else
    echo -e "${RED}✗ 备库2数据同步失败${NC}"
fi

echo ""

# 4. 清理临时文件
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 4: 清理临时文件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker exec opengauss-primary bash -c "rm -f ${DUMP_FILE}" 2>/dev/null
docker exec opengauss-standby1 bash -c "rm -f ${DUMP_FILE}" 2>/dev/null
docker exec opengauss-standby2 bash -c "rm -f ${DUMP_FILE}" 2>/dev/null
rm -f /tmp/blog_db_backup.sql 2>/dev/null
echo -e "${GREEN}✓ 临时文件已清理${NC}"

echo ""
echo "=========================================="
echo "  数据同步完成"
echo "=========================================="
echo ""
echo -e "${GREEN}✓ 三个数据库现在拥有相同的数据${NC}"
echo ""
echo "注意事项："
echo "  • 这是一次性的数据复制，不是实时同步"
echo "  • 主库的新数据不会自动同步到备库"
echo "  • 如需再次同步，请重新运行此脚本"
echo ""
echo "验证命令："
echo "  查看主库数据："
echo "    docker exec opengauss-primary bash -c 'su - omm -c \"gsql -d blog_db -c \\\"SELECT COUNT(*) FROM users;\\\"\"'"
echo ""
echo "  查看备库1数据："
echo "    docker exec opengauss-standby1 bash -c 'su - omm -c \"gsql -d blog_db -p 15432 -c \\"SELECT COUNT(*) FROM users;\\"\"'"
echo ""
echo "  查看备库2数据："
echo "    docker exec opengauss-standby2 bash -c 'su - omm -c \"gsql -d blog_db -p 25432 -c \\"SELECT COUNT(*) FROM users;\\"\"'"
echo ""
