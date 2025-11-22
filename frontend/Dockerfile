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

# 创建启动脚本（host 网络模式）
RUN printf '#!/bin/sh\n\
BACKEND_HOST=${BACKEND_HOST:-127.0.0.1}\n\
BACKEND_PORT=${BACKEND_PORT:-8081}\n\
\n\
echo "等待 backend 服务启动 ($BACKEND_HOST:$BACKEND_PORT)..."\n\
for i in $(seq 1 30); do\n\
    if nc -z $BACKEND_HOST $BACKEND_PORT 2>/dev/null; then\n\
        echo "✓ Backend 已就绪"\n\
        break\n\
    fi\n\
    if [ $i -eq 30 ]; then\n\
        echo "⚠ Backend 未响应，继续启动 Nginx"\n\
    fi\n\
    sleep 1\n\
done\n\
\n\
echo "启动 Nginx (监听端口 8080)..."\n\
exec nginx -g "daemon off;"\n' > /start.sh && chmod +x /start.sh

EXPOSE 8080

ENTRYPOINT ["/start.sh"]














