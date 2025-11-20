#!/bin/bash

set -e

echo "=== 开始构建和部署后端 ==="

# 本地构建镜像
echo "1. 构建 Docker 镜像..."
cd /Users/lifulin/Desktop/CloudCom
docker build -t blogcircle-backend:final ./backend

# 保存镜像
echo "2. 保存镜像为 tar 文件..."
docker save blogcircle-backend:final -o backend-final.tar

# 传输到虚拟机
echo "3. 传输镜像到虚拟机..."
scp backend-final.tar root@10.211.55.11:~/

echo "4. 在虚拟机上部署..."
ssh root@10.211.55.11 << 'ENDSSH'
cd ~/CloudCom

# 加载镜像
echo "  - 加载 Docker 镜像..."
docker load -i ~/backend-final.tar

# 修改 docker-compose 使用新镜像
echo "  - 更新 docker-compose 配置..."
sed -i 's/blogcircle-backend:fixed/blogcircle-backend:final/' docker-compose-vm-gaussdb.yml

# 重启后端
echo "  - 停止旧容器..."
docker-compose -f docker-compose-vm-gaussdb.yml stop backend
docker-compose -f docker-compose-vm-gaussdb.yml rm -f backend

echo "  - 启动新容器..."
docker-compose -f docker-compose-vm-gaussdb.yml up -d backend

# 等待启动
echo "  - 等待应用启动..."
sleep 15

# 测试注册
echo "  - 测试注册 API..."
RESULT=$(curl -s -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"pass123","email":"test@test.com","nickname":"测试用户"}')

echo "  注册结果: $RESULT"

# 查看数据库
echo "  - 查看数据库中的用户..."
su - omm -c "gsql -d blog_db -p 5432 -c 'SELECT username, email, nickname FROM users;'"

echo "=== 部署完成 ==="
ENDSSH

echo "=== 全部完成！==="
