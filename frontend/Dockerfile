FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine

# 安装 netcat 用于检查 backend 可用性
RUN apk add --no-cache netcat-openbsd

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 创建启动脚本
RUN printf '#!/bin/sh\n\
echo "等待 backend 容器启动..."\n\
for i in $(seq 1 30); do\n\
    if nc -z backend 8080 2>/dev/null; then\n\
        echo "Backend 已就绪"\n\
        break\n\
    fi\n\
    echo "  等待中... ($i/30)"\n\
    sleep 1\n\
done\n\
\n\
BACKEND_IP=$(getent hosts backend | awk '"'"'{ print $1 }'"'"')\n\
\n\
if [ -n "$BACKEND_IP" ]; then\n\
    echo "Backend IP: $BACKEND_IP"\n\
    sed -i "s/server backend:8080/server $BACKEND_IP:8080/g" /etc/nginx/conf.d/default.conf\n\
else\n\
    echo "警告: 无法解析 backend 主机名，使用默认配置"\n\
fi\n\
\n\
echo "启动 Nginx..."\n\
exec nginx -g "daemon off;"\n' > /start.sh && chmod +x /start.sh

EXPOSE 80

ENTRYPOINT ["/start.sh"]














