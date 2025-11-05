#!/bin/bash

set -e

# ============================================
#   配置区域（请根据实际情况修改）
# ============================================
SERVER_IP="10.211.55.11"
SERVER_USER="root"
SERVER_PASSWORD="747599qw@"
PROJECT_DIR="CloudCom"


# ============================================
#   颜色定义
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
#   辅助函数
# ============================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================
#   检查依赖
# ============================================
check_dependencies() {
    log_info "检查依赖工具..."
    
    # 检查 sshpass（用于密码认证）
    if ! command -v sshpass &> /dev/null; then
        log_error "未找到 sshpass，请先安装："
        echo "  macOS: brew install hudochenkov/sshpass/sshpass"
        echo "  Linux: yum install sshpass 或 apt-get install sshpass"
        exit 1
    fi
    
    # 检查 ssh
    if ! command -v ssh &> /dev/null; then
        log_error "未找到 ssh，请先安装 OpenSSH"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# ============================================
#   测试 SSH 连接
# ============================================
test_ssh_connection() {
    log_info "测试 SSH 连接..."
    
    # 先测试密码认证是否可用
    local ssh_output
    ssh_output=$(sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        -o PasswordAuthentication=yes \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        "${SERVER_USER}@${SERVER_IP}" "echo 'SSH连接成功'" 2>&1)
    
    local ssh_exit_code=$?
    
    if [ $ssh_exit_code -eq 0 ]; then
        log_success "SSH 连接测试成功"
    else
        log_error "SSH 连接失败"
        echo "错误信息: $ssh_output"
        echo ""
        log_error "请检查："
        echo "  1. 服务器IP是否正确: $SERVER_IP"
        echo "  2. 用户名是否正确: $SERVER_USER"
        echo "  3. 密码是否正确: $SERVER_PASSWORD"
        echo "  4. 服务器是否允许密码认证（检查 /etc/ssh/sshd_config 中的 PasswordAuthentication 设置）"
        echo "  5. 服务器是否可访问（尝试: ping $SERVER_IP）"
        exit 1
    fi
}

# ============================================
#   执行远程命令（带输出缓冲）
# ============================================
execute_remote() {
    local cmd="$1"
    local ssh_output
    local ssh_exit_code
    
    ssh_output=$(sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no \
        -o PasswordAuthentication=yes \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        "${SERVER_USER}@${SERVER_IP}" "$cmd" 2>&1)
    ssh_exit_code=$?
    
    # 输出命令结果
    echo "$ssh_output"
    
    # 如果SSH连接失败，输出错误信息
    if [ $ssh_exit_code -ne 0 ]; then
        if echo "$ssh_output" | grep -q "Permission denied"; then
            log_error "SSH 认证失败，请检查密码是否正确"
        fi
    fi
    
    return $ssh_exit_code
}

# ============================================
#   执行远程命令（实时输出，用于长时间运行的命令）
# ============================================
execute_remote_stream() {
    local cmd="$1"
    
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no \
        -o PasswordAuthentication=yes \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        "${SERVER_USER}@${SERVER_IP}" "$cmd"
    
    return $?
}

# ============================================
#   检查端口是否被占用
# ============================================
check_port_in_use() {
    local port="$1"
    # 使用 ss 或 netstat 检查端口占用
    # 返回 0 表示端口被占用，返回 1 表示端口空闲
    execute_remote "ss -ltn | grep -q ':${port} ' || netstat -ltn 2>/dev/null | grep -q ':${port} '" 2>/dev/null
    return $?
}

# ============================================
#   清理占用端口的进程
# ============================================
clean_port_process() {
    local port="$1"
    local port_name="$2"  # 用于日志显示，如 "数据库"
    
    log_info "   分析占用端口 ${port} 的进程..."
    
    # 获取占用端口的进程信息
    local process_info
    process_info=$(execute_remote "ss -ltnp 2>/dev/null | grep ':${port} ' || lsof -i:${port} -t 2>/dev/null | head -1" 2>/dev/null | grep -v "Authorized users" | head -1)
    
    if [ -z "$process_info" ]; then
        log_warning "   无法获取进程信息，可能需要root权限"
        return 1
    fi
    
    # 检查是否是 PostgreSQL 服务
    local is_postgres
    is_postgres=$(execute_remote "systemctl is-active postgresql 2>/dev/null || systemctl is-active postgresql-*.service 2>/dev/null | head -1" 2>/dev/null | grep -v "Authorized users" | xargs)
    
    if [ "$is_postgres" = "active" ] && [ "$port" = "5432" ]; then
        log_warning "   检测到系统 PostgreSQL 服务正在运行"
        log_info "   尝试停止 PostgreSQL 服务..."
        
        # 尝试停止 PostgreSQL
        execute_remote "systemctl stop postgresql 2>/dev/null || systemctl stop postgresql-*.service 2>/dev/null" > /dev/null 2>&1
        sleep 3
        
        # 验证是否成功
        if ! check_port_in_use "$port"; then
            log_success "   PostgreSQL 服务已停止，端口 ${port} 已释放"
            return 0
        else
            log_warning "   PostgreSQL 服务停止失败，尝试强制终止..."
            local pg_pid
            pg_pid=$(execute_remote "lsof -i:${port} -t 2>/dev/null | head -1" 2>/dev/null | grep -o '[0-9]\+' | head -1)
            if [ -n "$pg_pid" ]; then
                execute_remote "kill -9 ${pg_pid} 2>/dev/null" > /dev/null 2>&1
                sleep 2
                if ! check_port_in_use "$port"; then
                    log_success "   进程已终止，端口 ${port} 已释放"
                    return 0
                fi
            fi
        fi
    else
        # 尝试获取进程PID并终止
        log_info "   尝试终止占用端口的进程..."
        local pid
        pid=$(execute_remote "lsof -i:${port} -t 2>/dev/null | head -1" 2>/dev/null | grep -o '[0-9]\+' | head -1)
        
        if [ -n "$pid" ]; then
            log_info "   找到进程 PID: ${pid}，正在终止..."
            execute_remote "kill -9 ${pid} 2>/dev/null" > /dev/null 2>&1
            sleep 2
            
            if ! check_port_in_use "$port"; then
                log_success "   进程已终止，端口 ${port} 已释放"
                return 0
            else
                log_warning "   进程终止失败"
                return 1
            fi
        else
            log_warning "   无法获取进程PID"
            return 1
        fi
    fi
    
    return 1
}

# ============================================
#   查找可用端口（在远程服务器上执行，避免多次SSH调用）
# ============================================
find_available_port() {
    local start_port="$1"
    local max_attempts=20
    
    # 在远程服务器上执行端口查找逻辑，一次性完成
    local available_port
    available_port=$(execute_remote "
        start_port=${start_port}
        max_attempts=${max_attempts}
        current_port=\$start_port
        
        while [ \$max_attempts -gt 0 ]; do
            if ! ss -ltn | grep -q \":\${current_port} \" && ! netstat -ltn 2>/dev/null | grep -q \":\${current_port} \"; then
                echo \$current_port
                exit 0
            fi
            current_port=\$((current_port + 1))
            max_attempts=\$((max_attempts - 1))
        done
        exit 1
    " 2>/dev/null | grep -o '[0-9]\+' | head -1)
    
    if [ -n "$available_port" ]; then
        echo "$available_port"
        return 0
    else
        return 1
    fi
}

# ============================================
#   检测并处理端口冲突
# ============================================
check_and_resolve_port_conflicts() {
    log_info "检测端口冲突..."
    
    local db_port=5432
    local backend_port=8081
    local frontend_port=8080
    local has_conflict=false
    local need_modify_compose=false
    
    # 检查数据库端口
    if check_port_in_use "$db_port"; then
        log_warning "端口 ${db_port} (数据库) 已被占用"
        has_conflict=true
        
        # 1. 检查是否是旧的 Docker 容器占用
        local old_container
        old_container=$(execute_remote "docker ps -a --filter 'publish=${db_port}' --format '{{.Names}}' 2>/dev/null | head -1" | tr -d '\r\n' | sed 's/Authorized users only.*//g' | xargs)
        if [ -n "$old_container" ] && [ "$old_container" != "Authorized users only. All activities may be monitored and reported." ]; then
            log_info "   发现旧容器占用端口: $old_container，尝试清理..."
            execute_remote "docker stop '$old_container' 2>/dev/null && docker rm '$old_container' 2>/dev/null" > /dev/null 2>&1 || true
            sleep 2
            
            # 再次检查
            if ! check_port_in_use "$db_port"; then
                log_success "   端口 ${db_port} 已释放"
                has_conflict=false
            fi
        fi
        
        # 2. 如果仍被占用，尝试清理占用端口的进程
        if check_port_in_use "$db_port"; then
            log_warning "   端口仍被占用，尝试清理进程..."
            if clean_port_process "$db_port" "数据库"; then
                log_success "   端口 ${db_port} 已成功释放"
                has_conflict=false
            fi
        fi
        
        # 3. 如果仍然被占用，查找可用端口
        if check_port_in_use "$db_port"; then
            log_warning "   无法释放端口 ${db_port}，将使用其他端口"
            log_info "   正在查找可用的数据库端口..."
            local new_port
            new_port=$(find_available_port $((db_port + 1)))
            if [ -n "$new_port" ]; then
                log_warning "   将数据库端口改为: ${new_port}"
                log_info "   正在修改 docker-compose.yml..."
                execute_remote "cd ${PROJECT_DIR} && sed -i.bak 's/\"5432:5432\"/\"'${new_port}':5432\"/' docker-compose.yml" > /dev/null 2>&1
                # 验证修改是否成功
                local port_check
                port_check=$(execute_remote "cd ${PROJECT_DIR} && grep '\"'${new_port}':5432\"' docker-compose.yml" 2>/dev/null | tr -d '\r\n' | xargs)
                if [ -n "$port_check" ]; then
                    log_success "   数据库端口已成功修改为: ${new_port}"
                    db_port=$new_port
                    need_modify_compose=true
                else
                    log_error "   端口修改失败，请手动检查"
                    return 1
                fi
            else
                log_error "   无法找到可用的数据库端口"
                return 1
            fi
        fi
    else
        log_success "端口 ${db_port} (数据库) 可用"
    fi
    
    # 检查后端端口
    if check_port_in_use "$backend_port"; then
        log_warning "端口 ${backend_port} (后端) 已被占用"
        has_conflict=true
        
        # 1. 检查Docker容器
        local old_container
        old_container=$(execute_remote "docker ps -a --filter 'publish=${backend_port}' --format '{{.Names}}' 2>/dev/null | head -1" | tr -d '\r\n' | sed 's/Authorized users only.*//g' | xargs)
        if [ -n "$old_container" ] && [ "$old_container" != "Authorized users only. All activities may be monitored and reported." ]; then
            log_info "   发现旧容器占用端口: $old_container，尝试清理..."
            execute_remote "docker stop '$old_container' 2>/dev/null && docker rm '$old_container' 2>/dev/null" > /dev/null 2>&1 || true
            sleep 2
            
            if ! check_port_in_use "$backend_port"; then
                log_success "   端口 ${backend_port} 已释放"
                has_conflict=false
            fi
        fi
        
        # 2. 尝试清理进程
        if check_port_in_use "$backend_port"; then
            log_warning "   端口仍被占用，尝试清理进程..."
            if clean_port_process "$backend_port" "后端"; then
                log_success "   端口 ${backend_port} 已成功释放"
                has_conflict=false
            fi
        fi
        
        # 3. 查找可用端口
        if check_port_in_use "$backend_port"; then
            log_warning "   无法释放端口 ${backend_port}，将使用其他端口"
            log_info "   正在查找可用的后端端口..."
            local new_port
            new_port=$(find_available_port $((backend_port + 1)))
            if [ -n "$new_port" ]; then
                log_warning "   将后端端口改为: ${new_port}"
                log_info "   正在修改 docker-compose.yml..."
                execute_remote "cd ${PROJECT_DIR} && sed -i.bak 's/\"8081:8081\"/\"'${new_port}':8081\"/' docker-compose.yml" > /dev/null 2>&1
                local port_check
                port_check=$(execute_remote "cd ${PROJECT_DIR} && grep '\"'${new_port}':8081\"' docker-compose.yml" 2>/dev/null | tr -d '\r\n' | xargs)
                if [ -n "$port_check" ]; then
                    log_success "   后端端口已成功修改为: ${new_port}"
                    backend_port=$new_port
                    need_modify_compose=true
                else
                    log_error "   端口修改失败，请手动检查"
                    return 1
                fi
            else
                log_error "   无法找到可用的后端端口"
                return 1
            fi
        fi
    else
        log_success "端口 ${backend_port} (后端) 可用"
    fi
    
    # 检查前端端口
    if check_port_in_use "$frontend_port"; then
        log_warning "端口 ${frontend_port} (前端) 已被占用"
        has_conflict=true
        
        # 1. 检查Docker容器
        local old_container
        old_container=$(execute_remote "docker ps -a --filter 'publish=${frontend_port}' --format '{{.Names}}' 2>/dev/null | head -1" | tr -d '\r\n' | sed 's/Authorized users only.*//g' | xargs)
        if [ -n "$old_container" ] && [ "$old_container" != "Authorized users only. All activities may be monitored and reported." ]; then
            log_info "   发现旧容器占用端口: $old_container，尝试清理..."
            execute_remote "docker stop '$old_container' 2>/dev/null && docker rm '$old_container' 2>/dev/null" > /dev/null 2>&1 || true
            sleep 2
            
            if ! check_port_in_use "$frontend_port"; then
                log_success "   端口 ${frontend_port} 已释放"
                has_conflict=false
            fi
        fi
        
        # 2. 尝试清理进程
        if check_port_in_use "$frontend_port"; then
            log_warning "   端口仍被占用，尝试清理进程..."
            if clean_port_process "$frontend_port" "前端"; then
                log_success "   端口 ${frontend_port} 已成功释放"
                has_conflict=false
            fi
        fi
        
        # 3. 查找可用端口
        if check_port_in_use "$frontend_port"; then
            log_warning "   无法释放端口 ${frontend_port}，将使用其他端口"
            log_info "   正在查找可用的前端端口..."
            local new_port
            new_port=$(find_available_port $((frontend_port + 1)))
            if [ -n "$new_port" ]; then
                log_warning "   将前端端口改为: ${new_port}"
                log_info "   正在修改 docker-compose.yml..."
                execute_remote "cd ${PROJECT_DIR} && sed -i.bak 's/\"8080:80\"/\"'${new_port}':80\"/' docker-compose.yml" > /dev/null 2>&1
                local port_check
                port_check=$(execute_remote "cd ${PROJECT_DIR} && grep '\"'${new_port}':80\"' docker-compose.yml" 2>/dev/null | tr -d '\r\n' | xargs)
                if [ -n "$port_check" ]; then
                    log_success "   前端端口已成功修改为: ${new_port}"
                    frontend_port=$new_port
                    need_modify_compose=true
                else
                    log_error "   端口修改失败，请手动检查"
                    return 1
                fi
            else
                log_error "   无法找到可用的前端端口"
                return 1
            fi
        fi
    else
        log_success "端口 ${frontend_port} (前端) 可用"
    fi
    
    # 保存端口配置供后续使用
    export FINAL_DB_PORT=$db_port
    export FINAL_BACKEND_PORT=$backend_port
    export FINAL_FRONTEND_PORT=$frontend_port
    export PORTS_MODIFIED=$need_modify_compose
    
    if [ "$need_modify_compose" = true ]; then
        log_warning "docker-compose.yml 已被修改以使用可用端口"
    fi
    
    return 0
}

# ============================================
#   主函数
# ============================================
main() {
    echo ""
    echo "========================================="
    echo "   Blog Circle 远程更新部署脚本"
    echo "========================================="
    echo ""
    log_info "服务器: ${SERVER_USER}@${SERVER_IP}"
    log_info "项目目录: ${PROJECT_DIR}"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 测试连接
    test_ssh_connection
    
    # 执行部署步骤
    log_info "开始远程部署流程..."
    echo ""
    
    # 1. 检查项目目录是否存在
    log_info "1. 检查项目目录..."
    if execute_remote "[ -d \"${PROJECT_DIR}\" ]"; then
        log_success "项目目录存在"
    else
        log_error "项目目录不存在: ${PROJECT_DIR}"
        log_warning "请先在服务器上克隆仓库或创建目录"
        exit 1
    fi
    
    # 2. 配置 Git 安全目录和网络设置（解决 dubious ownership 和网络问题）
    log_info "2. 配置 Git 安全目录和网络设置..."
    # 使用绝对路径配置 Git 安全目录
    execute_remote "cd ${PROJECT_DIR} && pwd | xargs -I {} git config --global --add safe.directory {}" || true
    execute_remote "git config --global --add safe.directory /root/${PROJECT_DIR}" || true
    # 配置 Git 使用 HTTP/1.1 而不是 HTTP/2（解决网络问题）
    execute_remote "git config --global http.version HTTP/1.1" || true
    # 增加超时时间和缓冲区大小
    execute_remote "git config --global http.postBuffer 524288000" || true
    execute_remote "git config --global http.lowSpeedLimit 0" || true
    execute_remote "git config --global http.lowSpeedTime 0" || true
    # 配置 SSL 验证和重试
    execute_remote "git config --global http.sslVerify true" || true
    execute_remote "git config --global http.sslBackend openssl" || true
    # 增加连接超时时间
    execute_remote "git config --global http.timeout 300" || true
    log_success "Git 配置完成"
    
    # 3. 配置使用 SSH 方式拉取代码
    log_info "3. 配置 Git 使用 SSH 方式..."
    
    # 检查当前远程仓库 URL
    local current_url
    current_url=$(execute_remote "cd ${PROJECT_DIR} && git remote get-url origin" 2>/dev/null | grep -v "Authorized users" | xargs)
    
    # 如果是 HTTPS，转换为 SSH
    if echo "$current_url" | grep -q "^https://"; then
        log_info "   检测到 HTTPS URL，转换为 SSH..."
        # 将 https://github.com/user/repo 转换为 git@github.com:user/repo.git
        local ssh_url
        ssh_url=$(echo "$current_url" | sed 's|^https://github.com/|git@github.com:|' | sed 's|$|.git|' | sed 's|\.git\.git$|.git|')
        log_info "   新的 SSH URL: $ssh_url"
        execute_remote "cd ${PROJECT_DIR} && git remote set-url origin '$ssh_url'" > /dev/null 2>&1
        log_success "   已切换到 SSH 方式"
    else
        log_success "   已使用 SSH 方式"
    fi
    
    # 4. 拉取最新代码（带重试机制）
    log_info "4. 拉取最新代码..."
    
    MAX_RETRIES=5
    RETRY_COUNT=0
    FETCH_SUCCESS=false
    RESET_SUCCESS=false
    
    # 先尝试 fetch，带重试机制
    log_info "   同步远程代码（SSH）..."
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if execute_remote "cd ${PROJECT_DIR} && git fetch origin dev 2>&1"; then
            FETCH_SUCCESS=true
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                local wait_time=$((RETRY_COUNT * 3))
                log_warning "网络连接失败，第 ${RETRY_COUNT}/${MAX_RETRIES} 次重试，等待 ${wait_time} 秒..."
                sleep $wait_time  # 递增延迟：3秒、6秒、9秒、12秒
            fi
        fi
    done
    
    if [ "$FETCH_SUCCESS" = false ]; then
        log_warning "Git fetch 失败，但继续尝试使用本地已有的远程引用..."
    fi
    
    # 重置到远程分支
    RETRY_COUNT=0
    log_info "   更新本地代码..."
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if execute_remote "cd ${PROJECT_DIR} && git reset --hard origin/dev 2>&1"; then
            RESET_SUCCESS=true
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                local wait_time=$((RETRY_COUNT * 2))
                log_warning "重置失败，第 ${RETRY_COUNT}/${MAX_RETRIES} 次重试，等待 ${wait_time} 秒..."
                sleep $wait_time
            fi
        fi
    done
    
    if [ "$RESET_SUCCESS" = true ]; then
        log_success "代码更新成功"
    else
        log_error "代码更新失败，已重试 ${MAX_RETRIES} 次"
        log_warning "请检查网络连接或手动在服务器上执行: cd ${PROJECT_DIR} && git pull origin dev"
        exit 1
    fi
    
    # 5. 显示最新提交
    log_info "5. 显示最新提交信息..."
    execute_remote "cd ${PROJECT_DIR} && git log --oneline -3"
    echo ""
    
    # 6. 验证 docker-compose.yml
    log_info "6. 验证 docker-compose.yml..."
    if execute_remote "[ -f \"${PROJECT_DIR}/docker-compose.yml\" ]"; then
        log_success "docker-compose.yml 存在"
    else
        log_error "docker-compose.yml 不存在"
        exit 1
    fi
    
    # 7. 停止现有容器
    log_info "7. 停止现有容器..."
    execute_remote "cd ${PROJECT_DIR} && docker-compose down 2>/dev/null || true"
    log_success "容器已停止"
    
    # 8. 检测并处理端口冲突
    log_info "8. 检测端口占用情况..."
    if ! check_and_resolve_port_conflicts; then
        log_error "端口冲突无法解决，部署终止"
        exit 1
    fi
    echo ""
    
    # 9. 构建并启动服务
    log_info "9. 构建并启动服务（这可能需要几分钟）..."
    log_info "   正在构建 Docker 镜像并启动容器，请耐心等待..."
    echo ""
    
    # 使用实时输出模式显示构建进度
    if execute_remote_stream "cd ${PROJECT_DIR} && docker-compose up -d --build"; then
        echo ""
        log_success "服务启动成功"
    else
        echo ""
        log_error "服务启动失败"
        exit 1
    fi
    
    # 10. 等待服务启动
    log_info "10. 等待服务启动（8秒）..."
    sleep 8
    
    # 11. 检查服务状态
    log_info "11. 检查服务状态..."
    execute_remote "cd ${PROJECT_DIR} && docker-compose ps"
    echo ""
    
    # 12. 显示服务日志
    log_info "12. 显示服务日志（最后20行）..."
    echo ""
    echo "=== 数据库日志 ==="
    execute_remote "cd ${PROJECT_DIR} && docker-compose logs --tail=20 db 2>/dev/null || echo '数据库日志暂不可用'"
    echo ""
    echo "=== 后端日志 ==="
    execute_remote "cd ${PROJECT_DIR} && docker-compose logs --tail=20 backend 2>/dev/null || echo '后端日志暂不可用'"
    echo ""
    echo "=== 前端日志 ==="
    execute_remote "cd ${PROJECT_DIR} && docker-compose logs --tail=20 frontend 2>/dev/null || echo '前端日志暂不可用'"
    echo ""
    
    # 完成
    echo "========================================="
    log_success "远程部署完成！"
    echo "========================================="
    echo ""
    echo "访问地址："
    echo "  前端: http://${SERVER_IP}:${FINAL_FRONTEND_PORT:-8080}"
    echo "  后端: http://${SERVER_IP}:${FINAL_BACKEND_PORT:-8081}"
    if [ "$PORTS_MODIFIED" = true ]; then
        echo ""
        log_warning "注意：由于端口冲突，部分端口已自动调整"
        echo "  数据库端口: ${FINAL_DB_PORT:-5432}"
        echo "  后端端口: ${FINAL_BACKEND_PORT:-8081}"
        echo "  前端端口: ${FINAL_FRONTEND_PORT:-8080}"
    fi
    echo ""
    echo "常用命令（在服务器上执行）："
    echo "  cd ${PROJECT_DIR}"
    echo "  docker-compose logs -f          # 查看所有日志"
    echo "  docker-compose logs -f backend # 查看后端日志"
    echo "  docker-compose restart          # 重启服务"
    echo "  docker-compose down             # 停止服务"
    echo ""
}

# 运行主函数
main
