#!/bin/bash

################################################################################
# 修复 Docker 容器网络问题
# 在虚拟机上运行此脚本来修复 Nginx 无法解析 backend 的问题
################################################################################

echo "========================================="
echo "修复 Docker 容器网络问题"
echo "========================================="
echo ""

# 检查是否在容器内运行
if [ -f /.dockerenv ]; then
    echo "❌ 此脚本不应在容器内运行，请在主机上运行"
    exit 1
fi

# 1. 等待容器启动
echo "[1] 等待容器完全启动..."
for i in {1..30}; do
    if docker ps | grep -q blogcircle-backend; then
        break
    fi
    echo "  等待中... ($i/30)"
    sleep 1
done

# 2. 获取 backend 容器的 IP 地址
echo "[2] 获取 backend 容器 IP 地址..."
BACKEND_IP=""
for i in {1..10}; do
    BACKEND_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' blogcircle-backend 2>/dev/null || echo "")
    if [ -n "$BACKEND_IP" ]; then
        break
    fi
    echo "  重试中... ($i/10)"
    sleep 1
done

if [ -z "$BACKEND_IP" ]; then
    echo "❌ 无法获取 backend 容器 IP"
    docker-compose ps
    exit 1
fi

echo "Backend IP: $BACKEND_IP"
echo ""

# 3. 停止前端容器
echo "[3] 停止前端容器..."
docker-compose stop frontend 2>/dev/null || true
sleep 2

# 4. 更新 Nginx 配置
echo "[4] 更新 Nginx 配置..."
docker exec blogcircle-frontend sh -c "cat > /etc/nginx/conf.d/default.conf" << EOF
upstream backend_upstream {
    server $BACKEND_IP:8080;
}

server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://backend_upstream;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /uploads {
        proxy_pass http://backend_upstream;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

echo "Nginx 配置已更新"
echo ""

# 5. 重启前端容器
echo "[5] 重启前端容器..."
docker-compose up -d frontend
sleep 5

# 6. 检查前端状态
echo "[6] 检查前端状态..."
if docker-compose ps frontend | grep -q "Up"; then
    echo "前端容器已启动"
else
    echo "⚠️  前端容器可能未完全启动，查看日志..."
    docker-compose logs frontend | tail -10
fi

echo ""
echo "========================================="
echo "网络问题修复完成"
echo "========================================="
echo ""
echo "测试前端连接:"
echo "  curl http://localhost:8080"
echo ""
