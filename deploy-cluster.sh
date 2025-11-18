#!/bin/bash

################################################################################
# GaussDB 集群模式部署脚本
# 部署 Web 应用到主节点，连接一主二备 GaussDB 集群
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 集群配置
PRIMARY_IP="10.211.55.11"
PRIMARY_ROOT_PWD="747599qw@"
STANDBY1_IP="10.211.55.14"
STANDBY1_ROOT_PWD="747599qw@1"
STANDBY2_IP="10.211.55.13"
STANDBY2_ROOT_PWD="747599qw@2"

# 数据库配置
DB_PORT="5432"
DB_NAME="blog_db"
DB_USER="bloguser"
DB_PASSWORD="blogpass"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

################################################################################
# 1. 检查集群连接
################################################################################

check_cluster_connectivity() {
    log_info "=== 检查 GaussDB 集群连接 ==="
    
    # 检查主节点
    log_info "检查主节点: $PRIMARY_IP"
    if sshpass -p "$PRIMARY_ROOT_PWD" ssh -o StrictHostKeyChecking=no root@$PRIMARY_IP "echo 'SELECT 1;' | su - omm -c 'gsql -d postgres -p $DB_PORT' 2>/dev/null" | grep -q "1"; then
        log_success "主节点连接成功"
    else
        log_error "主节点连接失败"
        return 1
    fi
    
    # 检查备节点1
    log_info "检查备节点1: $STANDBY1_IP"
    if sshpass -p "$STANDBY1_ROOT_PWD" ssh -o StrictHostKeyChecking=no root@$STANDBY1_IP "echo 'SELECT 1;' | su - omm -c 'gsql -d postgres -p $DB_PORT' 2>/dev/null" | grep -q "1"; then
        log_success "备节点1连接成功"
    else
        log_warn "备节点1连接失败（可能未启动或网络问题）"
    fi
    
    # 检查备节点2
    log_info "检查备节点2: $STANDBY2_IP"
    if sshpass -p "$STANDBY2_ROOT_PWD" ssh -o StrictHostKeyChecking=no root@$STANDBY2_IP "echo 'SELECT 1;' | su - omm -c 'gsql -d postgres -p $DB_PORT' 2>/dev/null" | grep -q "1"; then
        log_success "备节点2连接成功"
    else
        log_warn "备节点2连接失败（可能未启动或网络问题）"
    fi
}

################################################################################
# 2. 初始化数据库
################################################################################

init_database() {
    log_info "=== 初始化数据库 ==="
    
    # 检查数据库是否存在
    log_info "检查数据库 $DB_NAME"
    DB_EXISTS=$(sshpass -p "$PRIMARY_ROOT_PWD" ssh root@$PRIMARY_IP \
        "su - omm -c 'gsql -d postgres -p $DB_PORT -t -c \"SELECT 1 FROM pg_database WHERE datname=\\\"$DB_NAME\\\"\"' 2>/dev/null" | tr -d ' ')
    
    if [ "$DB_EXISTS" = "1" ]; then
        log_success "数据库 $DB_NAME 已存在"
    else
        log_info "创建数据库 $DB_NAME"
        sshpass -p "$PRIMARY_ROOT_PWD" ssh root@$PRIMARY_IP \
            "su - omm -c 'gsql -d postgres -p $DB_PORT -c \"CREATE DATABASE $DB_NAME\"' 2>/dev/null"
        log_success "数据库创建成功"
    fi
    
    # 检查用户是否存在
    log_info "检查用户 $DB_USER"
    USER_EXISTS=$(sshpass -p "$PRIMARY_ROOT_PWD" ssh root@$PRIMARY_IP \
        "su - omm -c 'gsql -d postgres -p $DB_PORT -t -c \"SELECT 1 FROM pg_user WHERE usename=\\\"$DB_USER\\\"\"' 2>/dev/null" | tr -d ' ')
    
    if [ "$USER_EXISTS" = "1" ]; then
        log_success "用户 $DB_USER 已存在"
    else
        log_info "创建用户 $DB_USER"
        sshpass -p "$PRIMARY_ROOT_PWD" ssh root@$PRIMARY_IP \
            "su - omm -c 'gsql -d postgres -p $DB_PORT -c \"CREATE USER $DB_USER WITH PASSWORD \\\"$DB_PASSWORD\\\"\"' 2>/dev/null"
        sshpass -p "$PRIMARY_ROOT_PWD" ssh root@$PRIMARY_IP \
            "su - omm -c 'gsql -d postgres -p $DB_PORT -c \"GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER\"' 2>/dev/null"
        log_success "用户创建成功"
    fi
    
    # 上传并执行初始化脚本
    log_info "上传初始化脚本"
    sshpass -p "$PRIMARY_ROOT_PWD" scp -o StrictHostKeyChecking=no \
        backend/src/main/resources/db/01_init.sql root@$PRIMARY_IP:/tmp/
    
    log_info "执行初始化脚本"
    sshpass -p "$PRIMARY_ROOT_PWD" ssh root@$PRIMARY_IP \
        "su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -f /tmp/01_init.sql' 2>/dev/null"
    log_success "数据库初始化完成"
}

################################################################################
# 3. 部署应用
################################################################################

deploy_application() {
    log_info "=== 部署应用到主节点 ==="
    
    # 同步代码到主节点
    log_info "同步代码到 $PRIMARY_IP"
    sshpass -p "$PRIMARY_ROOT_PWD" ssh root@$PRIMARY_IP "mkdir -p /opt/blogcircle"
    sshpass -p "$PRIMARY_ROOT_PWD" rsync -avz --exclude='node_modules' --exclude='target' --exclude='.git' \
        -e "sshpass -p $PRIMARY_ROOT_PWD ssh -o StrictHostKeyChecking=no" \
        ./ root@$PRIMARY_IP:/opt/blogcircle/
    
    log_success "代码同步完成"
    
    # 启动容器
    log_info "启动 Docker 容器"
    sshpass -p "$PRIMARY_ROOT_PWD" ssh root@$PRIMARY_IP \
        "cd /opt/blogcircle && docker compose -f docker-compose-gaussdb-cluster.yml up -d"
    
    log_success "应用部署完成"
}

################################################################################
# 4. 验证部署
################################################################################

verify_deployment() {
    log_info "=== 验证部署 ==="
    
    sleep 10
    
    # 检查容器状态
    log_info "检查容器状态"
    sshpass -p "$PRIMARY_ROOT_PWD" ssh root@$PRIMARY_IP \
        "cd /opt/blogcircle && docker compose -f docker-compose-gaussdb-cluster.yml ps"
    
    # 检查后端健康
    log_info "检查后端健康"
    if curl -s http://$PRIMARY_IP:8081/actuator/health | grep -q "UP"; then
        log_success "后端服务健康"
    else
        log_warn "后端服务未就绪（可能仍在启动中）"
    fi
    
    # 检查前端
    log_info "检查前端"
    if curl -s -o /dev/null -w "%{http_code}" http://$PRIMARY_IP:8080 | grep -q "200"; then
        log_success "前端服务可访问"
    else
        log_warn "前端服务未就绪"
    fi
}

################################################################################
# 主函数
################################################################################

main() {
    echo "========================================="
    echo "  GaussDB 集群模式部署"
    echo "========================================="
    echo ""
    echo "集群配置:"
    echo "  主节点: $PRIMARY_IP"
    echo "  备节点1: $STANDBY1_IP"
    echo "  备节点2: $STANDBY2_IP"
    echo ""
    
    # 检查依赖
    if ! command -v sshpass &> /dev/null; then
        log_error "sshpass 未安装，请先安装: brew install sshpass"
        exit 1
    fi
    
    if ! command -v rsync &> /dev/null; then
        log_error "rsync 未安装"
        exit 1
    fi
    
    # 执行部署
    check_cluster_connectivity
    init_database
    deploy_application
    verify_deployment
    
    echo ""
    log_success "部署完成！"
    echo ""
    echo "访问地址:"
    echo "  前端: http://$PRIMARY_IP:8080"
    echo "  后端: http://$PRIMARY_IP:8081"
    echo "  Spark UI: http://$PRIMARY_IP:8888"
    echo ""
}

# 运行主函数
main "$@"
