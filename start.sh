#!/bin/bash

# 启动脚本

echo "========================================="
echo "       启动脚本"
echo "========================================="
echo ""

# 检查 PostgreSQL 是否运行
echo "1. 检查 PostgreSQL 服务..."
if ! pgrep -x "postgres" > /dev/null; then
    echo "   ⚠️  PostgreSQL 未运行，正在启动..."
    brew services start postgresql@14
    sleep 3
else
    echo "   ✅ PostgreSQL 正在运行"
fi

# 检查数据库是否存在
echo ""
echo "2. 检查数据库..."
if psql -lqt | cut -d \| -f 1 | grep -qw blog_db; then
    echo "   ✅ 数据库 blog_db 已存在"
else
    echo "   ⚠️  数据库 blog_db 不存在，正在创建..."
    createdb blog_db
    echo "   ✅ 数据库创建成功"
    echo "   正在初始化数据库表..."
    psql -d blog_db -f backend/src/main/resources/db/init.sql
    echo "   ✅ 数据库初始化完成"
fi

# 启动后端
echo ""
echo "3. 启动后端服务..."
cd backend
echo "   正在编译并启动 Spring Boot 应用..."
mvn spring-boot:run > ../logs/backend.log 2>&1 &
BACKEND_PID=$!
echo "   ✅ 后端服务已启动 (PID: $BACKEND_PID)"
echo "   后端地址: http://localhost:8080"
cd ..

# 等待后端启动
echo "   等待后端服务就绪..."
sleep 10

# 启动前端
echo ""
echo "4. 启动前端服务..."
cd frontend
if [ ! -d "node_modules" ]; then
    echo "   首次运行，正在安装依赖..."
    npm install
fi
echo "   正在启动 Vite 开发服务器..."
npm run dev > ../logs/frontend.log 2>&1 &
FRONTEND_PID=$!
echo "   ✅ 前端服务已启动 (PID: $FRONTEND_PID)"
echo "   前端地址: http://localhost:5173"
cd ..

# 保存 PID
mkdir -p logs
echo $BACKEND_PID > logs/backend.pid
echo $FRONTEND_PID > logs/frontend.pid

echo ""
echo "========================================="
echo "       🎉 所有服务已启动成功！"
echo "========================================="
echo ""
echo "访问地址："
echo "  前端: http://localhost:5173"
echo "  后端: http://localhost:8080"
echo ""
echo "测试账号："
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo "日志文件："
echo "  后端: logs/backend.log"
echo "  前端: logs/frontend.log"
echo ""
echo "停止服务: ./stop.sh"
echo "========================================="

