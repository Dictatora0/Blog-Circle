#!/bin/bash

# 系统诊断脚本 - 快速定位问题

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[检查]${NC} $1"; }
ok() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }

echo "========================================="
echo "   系统诊断"
echo "========================================="
echo ""

# 1. 检查 Docker
log "检查 Docker..."
if docker ps &>/dev/null; then
    ok "Docker 运行正常"
    docker --version
else
    err "Docker 未运行或无权限"
fi
echo ""

# 2. 检查容器状态
log "检查容器状态..."
if docker ps -a | grep blogcircle &>/dev/null; then
    docker ps -a | grep blogcircle
    echo ""
    
    # 检查后端日志
    if docker ps | grep blogcircle-backend &>/dev/null; then
        log "后端容器运行中，检查最近日志..."
        docker logs --tail=20 blogcircle-backend 2>&1 | tail -10
    else
        err "后端容器未运行"
        log "最近的错误日志:"
        docker logs --tail=50 blogcircle-backend 2>&1 | grep -i error | tail -5
    fi
else
    warn "未找到 blogcircle 容器"
fi
echo ""

# 3. 检查 GaussDB 连接
log "检查 GaussDB 主库连接..."
if nc -zv 10.211.55.11 5432 2>&1 | grep -q succeeded; then
    ok "主库网络可达"
    if command -v psql &>/dev/null; then
        PGPASSWORD="747599qw@" psql -h 10.211.55.11 -p 5432 -U bloguser -d blog_db -c "SELECT 1;" &>/dev/null
        if [ $? -eq 0 ]; then
            ok "主库连接成功"
        else
            err "主库连接失败 - 检查用户名/密码"
        fi
    else
        warn "未安装 psql，跳过数据库连接测试"
    fi
else
    err "主库网络不可达"
fi
echo ""

log "检查 GaussDB 备库1连接..."
if nc -zv 10.211.55.14 5432 2>&1 | grep -q succeeded; then
    ok "备库1网络可达"
else
    err "备库1网络不可达"
fi
echo ""

log "检查 GaussDB 备库2连接..."
if nc -zv 10.211.55.13 5432 2>&1 | grep -q succeeded; then
    ok "备库2网络可达"
else
    err "备库2网络不可达"
fi
echo ""

# 4. 检查端口占用
log "检查端口占用..."
for port in 8080 8081 8082 8090 8091 5432 7077; do
    if lsof -i :$port &>/dev/null || netstat -an | grep ":$port " &>/dev/null; then
        ok "端口 $port 已被占用"
    else
        warn "端口 $port 未被占用"
    fi
done
echo ""

# 5. 检查 Spark 容器
log "检查 Spark 容器..."
if docker ps | grep spark-master &>/dev/null; then
    ok "Spark Master 运行中"
    if curl -s http://localhost:8090 &>/dev/null; then
        ok "Spark Master UI 可访问"
    else
        warn "Spark Master UI 不可访问"
    fi
else
    warn "Spark Master 未运行"
fi

if docker ps | grep spark-worker &>/dev/null; then
    ok "Spark Worker 运行中"
else
    warn "Spark Worker 未运行"
fi
echo ""

# 6. 检查网络
log "检查 Docker 网络..."
if docker network ls | grep blogcircle-network &>/dev/null; then
    ok "Docker 网络存在"
    docker network inspect blogcircle-network | grep -A 5 "Containers"
else
    err "Docker 网络不存在"
fi
echo ""

# 7. 检查磁盘空间
log "检查磁盘空间..."
df -h / | tail -1
echo ""

# 8. 检查内存
log "检查内存使用..."
free -h 2>/dev/null || vm_stat | head -5
echo ""

# 9. 生成诊断报告
echo "========================================="
echo "   诊断总结"
echo "========================================="
echo ""

ISSUES=0

if ! docker ps | grep blogcircle-backend &>/dev/null; then
    err "后端容器未运行"
    ((ISSUES++))
fi

if ! nc -zv 10.211.55.11 5432 2>&1 | grep -q succeeded; then
    err "无法连接 GaussDB 主库"
    ((ISSUES++))
fi

if [ $ISSUES -eq 0 ]; then
    ok "未发现严重问题"
else
    err "发现 $ISSUES 个问题需要修复"
fi

echo ""
echo "建议操作:"
echo "1. 查看完整日志: docker-compose logs -f"
echo "2. 重启服务: docker-compose restart"
echo "3. 重新部署: docker-compose down && docker-compose up -d"
echo "4. 检查 GaussDB: ssh root@10.211.55.11 'su - omm -c \"gs_ctl status -D /gaussdb/data\"'"
echo ""
