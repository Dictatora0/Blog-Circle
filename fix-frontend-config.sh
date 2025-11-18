#!/bin/bash

# 修复前端 nginx 配置的脚本
# 在虚拟机上执行此脚本

set -e

echo "========================================="
echo "   修复前端 Nginx 配置"
echo "========================================="
echo ""

cd ~/CloudCom

echo "1. 备份当前配置..."
cp frontend/nginx.conf frontend/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)

echo "2. 更新 nginx.conf..."
cat > frontend/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # 使用 Docker 内置 DNS 进行动态解析
    resolver 127.0.0.11 valid=10s;
    resolver_timeout 5s;
    
    # 设置变量以启用动态 DNS 解析
    set $backend_upstream "backend:8080";

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://$backend_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /uploads {
        proxy_pass http://$backend_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

echo "3. 停止并删除前端容器..."
docker-compose stop frontend
docker-compose rm -f frontend

echo "4. 重新构建前端镜像..."
docker-compose build --no-cache frontend

echo "5. 启动前端容器..."
docker-compose up -d frontend

echo ""
echo "等待 20 秒让服务启动..."
sleep 20

echo ""
echo "6. 检查服务状态..."
docker-compose ps

echo ""
echo "7. 查看前端日志..."
docker-compose logs --tail=30 frontend

echo ""
echo "========================================="
echo "   修复完成"
echo "========================================="
echo ""
echo "如果前端日志中没有错误，请访问："
echo "  http://10.211.55.11:8080"
echo ""
