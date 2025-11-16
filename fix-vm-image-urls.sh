#!/bin/bash

# 修复虚拟机部署中的图片URL问题
# 将数据库中的 localhost:8080 替换为正确的虚拟机地址

VM_IP="10.211.55.11"
VM_BACKEND_URL="http://$VM_IP:8081"
TOKEN="eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOjEsInVzZXJuYW1lIjoiYWRtaW4iLCJzdWIiOiJhZG1pbiIsImlhdCI6MTc2MjE0OTg0OSwiZXhwIjoxNzYyMjM2MjQ5fQ.UEHVpy4c9OiZwyIeDQLpTO312dwI8wctu2xP2BxW3Ws"

echo "修复虚拟机数据库中的图片URL..."

# 这里需要一个API端点来修复数据库中的URL
# 由于没有现成的API，让我们创建一个简单的修复脚本

# 连接到虚拟机数据库并执行修复
echo "连接到虚拟机数据库进行修复..."

sshpass -p "747599qw@" ssh -o StrictHostKeyChecking=no root@$VM_IP << 'EOF'
# 在虚拟机上执行数据库修复
docker exec blogcircle-db psql -U bloguser -d blog_db -c "
-- 修复用户头像URL
UPDATE users SET avatar = REPLACE(avatar, 'http://localhost:8080', 'http://10.211.55.11:8080') WHERE avatar LIKE 'http://localhost:8080%';

-- 修复封面图片URL（如果存在）
UPDATE users SET cover_image = REPLACE(cover_image, 'http://localhost:8080', 'http://10.211.55.11:8080') WHERE cover_image LIKE 'http://localhost:8080%';

-- 修复文章中的图片URL
UPDATE posts SET images = REPLACE(images, 'http://localhost:8080', 'http://10.211.55.11:8080') WHERE images LIKE '%http://localhost:8080%';

SELECT '修复完成' as status;
"
EOF

echo "数据库URL修复完成！"
echo ""
echo "现在图片应该能正确显示在虚拟机前端。"
