#!/bin/bash

# VM 容器化部署完整测试脚本
# 测试 VM 上的 PostgreSQL + Backend + Frontend + Spark 完整系统

set -e

VM_IP="10.211.55.11"
VM_USER="parallels"
VM_PASSWORD="747599qw@"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }

header() {
    echo ""
    echo "========================================="
    echo "   $1"
    echo "========================================="
    echo ""
}

# 测试 PostgreSQL 容器（VM 上）
test_postgres() {
    header "测试 PostgreSQL 容器"
    
    log "检查 VM PostgreSQL 容器状态..."
    if ! ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "docker exec gaussdb-primary psql -U bloguser -d blog_db -c 'SELECT 1'" &>/dev/null; then
        err "VM PostgreSQL 容器未运行或无法连接"
        return 1
    fi
    ok "VM PostgreSQL 容器运行正常"
    
    log "检查数据库表..."
    TABLES=$(ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "docker exec gaussdb-primary psql -U bloguser -d blog_db -t -c \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'\"" | tr -d ' ')
    ok "数据库包含 $TABLES 个表"
    
    log "检查测试数据..."
    USERS=$(ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "docker exec gaussdb-primary psql -U bloguser -d blog_db -t -c 'SELECT COUNT(*) FROM users'" | tr -d ' ')
    POSTS=$(ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "docker exec gaussdb-primary psql -U bloguser -d blog_db -t -c 'SELECT COUNT(*) FROM posts'" | tr -d ' ')
    ok "用户数: $USERS, 文章数: $POSTS"
}

# 测试 Mac 本地服务连接 VM PostgreSQL
test_mac_services() {
    header "测试 Mac 本地服务"
    
    log "测试 Backend API..."
    RESPONSE=$(curl -s http://localhost:8081/api/posts/list)
    if echo "$RESPONSE" | grep -q '"code":200'; then
        ok "Backend API 正常"
    else
        err "Backend API 失败: $RESPONSE"
        return 1
    fi
    
    log "测试用户注册..."
    REGISTER=$(curl -s -X POST http://localhost:8081/api/auth/register \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"vmtest$(date +%s)\",\"password\":\"test123\",\"email\":\"test@vm.com\"}")
    if echo "$REGISTER" | grep -q '"code":200'; then
        ok "用户注册成功"
    else
        warn "用户注册失败（可能已存在）: $REGISTER"
    fi
    
    log "测试用户登录..."
    LOGIN=$(curl -s -X POST http://localhost:8081/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123"}')
    if echo "$LOGIN" | grep -q '"token"'; then
        TOKEN=$(echo "$LOGIN" | jq -r '.data.token')
        ok "用户登录成功，获取 Token"
        
        log "测试创建文章..."
        POST=$(curl -s -X POST http://localhost:8081/api/posts \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "{\"title\":\"VM测试文章\",\"content\":\"这是VM部署测试文章 $(date)\"}")
        if echo "$POST" | grep -q '"code":200'; then
            POST_ID=$(echo "$POST" | jq -r '.data.id')
            ok "创建文章成功，ID: $POST_ID"
            
            log "测试文章详情..."
            DETAIL=$(curl -s "http://localhost:8081/api/posts/${POST_ID}/detail")
            if echo "$DETAIL" | grep -q '"code":200'; then
                ok "获取文章详情成功"
            else
                err "获取文章详情失败: $DETAIL"
            fi
            
            log "测试创建评论..."
            COMMENT=$(curl -s -X POST http://localhost:8081/api/comments \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $TOKEN" \
                -d "{\"postId\":${POST_ID},\"content\":\"测试评论\"}")
            if echo "$COMMENT" | grep -q '"code":200'; then
                ok "创建评论成功"
            else
                warn "创建评论失败: $COMMENT"
            fi
            
            log "测试点赞..."
            LIKE=$(curl -s -X POST "http://localhost:8081/api/likes/${POST_ID}" \
                -H "Authorization: Bearer $TOKEN")
            if echo "$LIKE" | grep -q '"code":200'; then
                ok "点赞成功"
            else
                warn "点赞失败: $LIKE"
            fi
        else
            err "创建文章失败: $POST"
        fi
    else
        err "用户登录失败: $LOGIN"
        return 1
    fi
}

# 测试 Spark 作业
test_spark_job() {
    header "测试 Spark 作业"
    
    log "检查 Spark 容器状态..."
    if ! docker ps | grep -q blogcircle-spark-master; then
        err "Spark Master 容器未运行"
        return 1
    fi
    ok "Spark 容器运行正常"
    
    log "运行 Spark 分析作业..."
    cd /Users/lifulin/Desktop/CloudCom
    if ./run-spark-job.sh cluster 2>&1 | tee /tmp/spark-test.log | grep -q "分析任务完成"; then
        ok "Spark 作业执行成功"
        
        log "检查统计结果..."
        STATS=$(ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "docker exec gaussdb-primary psql -U bloguser -d blog_db -t -c 'SELECT COUNT(*) FROM statistics'" | tr -d ' ')
        ok "统计表记录数: $STATS"
    else
        err "Spark 作业执行失败，查看日志: /tmp/spark-test.log"
        return 1
    fi
}

# 测试数据库连接池
test_db_pool() {
    header "测试数据库连接池"
    
    log "并发请求测试（10个请求）..."
    for i in {1..10}; do
        curl -s http://localhost:8081/api/posts/list > /dev/null &
    done
    wait
    ok "并发请求完成"
    
    log "检查 Backend 日志中的连接池状态..."
    docker logs blogcircle-backend 2>&1 | tail -20 | grep -i "hikari" || true
}

# 测试前端访问
test_frontend() {
    header "测试前端服务"
    
    log "测试前端页面..."
    FRONTEND=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082)
    if [ "$FRONTEND" = "200" ]; then
        ok "前端服务正常 (HTTP $FRONTEND)"
    else
        err "前端服务异常 (HTTP $FRONTEND)"
        return 1
    fi
    
    log "测试前端访问 Backend API..."
    # 前端通过 nginx 代理访问 backend
    PROXY=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/api/posts/list)
    if [ "$PROXY" = "200" ]; then
        ok "前端代理 Backend 正常 (HTTP $PROXY)"
    else
        warn "前端代理 Backend 异常 (HTTP $PROXY)"
    fi
}

# 性能测试
test_performance() {
    header "性能测试"
    
    log "测试 API 响应时间..."
    for i in {1..5}; do
        TIME=$(curl -s -o /dev/null -w "%{time_total}" http://localhost:8081/api/posts/list)
        echo "  请求 $i: ${TIME}s"
    done
    
    log "测试数据库查询性能..."
    ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "docker exec gaussdb-primary psql -U bloguser -d blog_db -c '\\timing on' -c 'SELECT COUNT(*) FROM posts'" 2>&1 | grep "Time:" || true
}

# 显示系统状态
show_system_status() {
    header "系统状态总览"
    
    echo "容器状态:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep blogcircle || echo "  无运行中的容器"
    
    echo ""
    echo "PostgreSQL 状态:"
    ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "docker exec gaussdb-primary psql -U bloguser -d blog_db -c 'SELECT version()'" 2>/dev/null || echo "  PostgreSQL 未运行"
    
    echo ""
    echo "数据统计:"
    ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "docker exec gaussdb-primary psql -U bloguser -d blog_db -t -c \"
        SELECT 
            '用户数: ' || COUNT(*) FROM users
        UNION ALL
        SELECT '文章数: ' || COUNT(*) FROM posts
        UNION ALL
        SELECT '评论数: ' || COUNT(*) FROM comments
        UNION ALL
        SELECT '点赞数: ' || COUNT(*) FROM likes
        UNION ALL
        SELECT '访问日志: ' || COUNT(*) FROM access_logs
    \"" 2>/dev/null || echo "  无法获取数据统计"
}

# 主测试流程
main() {
    header "VM 容器化部署完整测试"
    
    log "开始测试..."
    
    # 1. PostgreSQL 测试
    if test_postgres; then
        ok "PostgreSQL 测试通过"
    else
        err "PostgreSQL 测试失败"
        exit 1
    fi
    
    # 2. Mac 服务测试
    if test_mac_services; then
        ok "Mac 服务测试通过"
    else
        err "Mac 服务测试失败"
        exit 1
    fi
    
    # 3. 前端测试
    if test_frontend; then
        ok "前端测试通过"
    else
        warn "前端测试未通过（非关键）"
    fi
    
    # 4. 数据库连接池测试
    test_db_pool
    
    # 5. Spark 作业测试
    if test_spark_job; then
        ok "Spark 作业测试通过"
    else
        warn "Spark 作业测试未通过（非关键）"
    fi
    
    # 6. 性能测试
    test_performance
    
    # 7. 系统状态
    show_system_status
    
    header "测试完成"
    ok "所有核心功能测试通过！"
    
    echo ""
    echo "访问地址:"
    echo "  前端: http://localhost:8082"
    echo "  后端: http://localhost:8081"
    echo "  Spark Master UI: http://localhost:8090"
    echo ""
    echo "测试账号:"
    echo "  用户名: admin"
    echo "  密码: admin123"
}

# 执行测试
main
