#!/bin/bash

###############################################################
# 虚拟机服务状态检查脚本
# 检查虚拟机上所有服务的运行状态
###############################################################

set -e

VM_IP="10.211.55.11"
VM_USER="root"
VM_PASSWORD="747599qw@"
VM_PROJECT_DIR="CloudCom"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 sshpass
if ! command -v sshpass &> /dev/null; then
    if [ -f "/opt/homebrew/bin/sshpass" ]; then
        SSHPASS="/opt/homebrew/bin/sshpass"
    else
        echo -e "${RED}✗ 未找到 sshpass，请先安装: brew install hudochenkov/sshpass/sshpass${NC}"
        exit 1
    fi
else
    SSHPASS="sshpass"
fi

vm_cmd() {
    $SSHPASS -p "$VM_PASSWORD" ssh \
        -o StrictHostKeyChecking=no \
        -o PubkeyAuthentication=no \
        -o PasswordAuthentication=yes \
        ${VM_USER}@${VM_IP} "$1"
}

echo "========================================="
echo "   虚拟机服务状态检查"
echo "========================================="
echo ""
echo "虚拟机: $VM_IP"
echo ""

# 1. 检查虚拟机连接
echo "=== 1. 虚拟机连接 ==="
if vm_cmd "echo 'connected'" 2>/dev/null | grep -q "connected"; then
    echo -e "${GREEN}✓ 虚拟机连接正常${NC}"
else
    echo -e "${RED}✗ 无法连接到虚拟机${NC}"
    exit 1
fi
echo ""

# 2. 检查 GaussDB 主库状态
echo "=== 2. GaussDB 服务状态 ==="
GAUSSDB_STATUS=$(vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data' 2>/dev/null || echo 'stopped'")
if echo "$GAUSSDB_STATUS" | grep -q "running"; then
    echo -e "${GREEN}✓ 主库运行正常${NC} (端口 5432)"
    
    # 获取主库版本和连接数
    VERSION=$(vm_cmd "su - omm -c 'gsql -d postgres -p 5432 -t -c \"SELECT version();\"' 2>/dev/null" | head -1 | xargs)
    CONNECTIONS=$(vm_cmd "su - omm -c 'gsql -d postgres -p 5432 -t -c \"SELECT count(*) FROM pg_stat_activity;\"' 2>/dev/null" | tr -d ' ')
    echo "  版本: $VERSION"
    echo "  当前连接数: $CONNECTIONS"
else
    echo -e "${RED}✗ 主库未运行${NC}"
fi

# 3. 检查集群配置
if vm_cmd "[ -d /usr/local/opengauss/data_standby1 ] && echo 'exists'" | grep -q "exists"; then
    echo ""
    echo "=== 3. GaussDB 集群状态 ==="
    
    # 检查备库1
    STANDBY1_STATUS=$(vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_standby1' 2>/dev/null || echo 'stopped'")
    if echo "$STANDBY1_STATUS" | grep -q "running"; then
        echo -e "${GREEN}✓ 备库1运行正常${NC} (端口 5434)"
    else
        echo -e "${RED}✗ 备库1未运行${NC}"
    fi
    
    # 检查备库2
    STANDBY2_STATUS=$(vm_cmd "su - omm -c 'gs_ctl status -D /usr/local/opengauss/data_standby2' 2>/dev/null || echo 'stopped'")
    if echo "$STANDBY2_STATUS" | grep -q "running"; then
        echo -e "${GREEN}✓ 备库2运行正常${NC} (端口 5436)"
    else
        echo -e "${RED}✗ 备库2未运行${NC}"
    fi
    
    # 检查复制状态
    echo ""
    echo -e "${BLUE}复制状态:${NC}"
    vm_cmd "su - omm -c 'gsql -d postgres -p 5432 -c \"SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;\"' 2>/dev/null" || echo "无法获取复制状态"
fi
echo ""

# 4. 检查 Docker 服务
echo "=== 4. Docker 容器状态 ==="
DOCKER_PS=$(vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml ps" 2>/dev/null || echo "ERROR")
if echo "$DOCKER_PS" | grep -q "ERROR"; then
    echo -e "${RED}✗ 无法获取 Docker 容器状态${NC}"
else
    echo "$DOCKER_PS"
    echo ""
    
    # 统计容器数量
    RUNNING_COUNT=$(echo "$DOCKER_PS" | grep -c "Up" || echo "0")
    echo "运行中的容器数: $RUNNING_COUNT"
fi
echo ""

# 5. 检查服务端口
echo "=== 5. 服务端口检查 ==="
check_port() {
    local port=$1
    local service=$2
    if vm_cmd "netstat -an | grep LISTEN | grep :$port" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $service (端口 $port)"
    else
        echo -e "${RED}✗${NC} $service (端口 $port) ${YELLOW}未监听${NC}"
    fi
}

check_port 5432 "GaussDB 主库"
if vm_cmd "[ -d /usr/local/opengauss/data_standby1 ] && echo 'exists'" | grep -q "exists"; then
    check_port 5433 "GaussDB 备库1"
    check_port 5434 "GaussDB 备库2"
fi
check_port 8080 "前端服务"
check_port 8081 "后端服务"
echo ""

# 6. 应用健康检查
echo "=== 6. 应用健康检查 ==="
echo -n "后端服务: "
BACKEND_HEALTH=$(curl -s "http://${VM_IP}:8081/actuator/health" 2>/dev/null || echo "ERROR")
if echo "$BACKEND_HEALTH" | grep -q "UP"; then
    echo -e "${GREEN}✓ 健康${NC}"
else
    echo -e "${RED}✗ 不健康或无法访问${NC}"
fi

echo -n "前端服务: "
if curl -s "http://${VM_IP}:8080" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 可访问${NC}"
else
    echo -e "${RED}✗ 无法访问${NC}"
fi
echo ""

# 7. 系统资源使用情况
echo "=== 7. 系统资源使用 ==="
DISK_USAGE=$(vm_cmd "df -h / | tail -1 | awk '{print \$5}'" 2>/dev/null)
MEM_USAGE=$(vm_cmd "free -m | awk 'NR==2{printf \"%.1f%%\", \$3*100/\$2}'" 2>/dev/null)
CPU_USAGE=$(vm_cmd "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - \$1\"%\"}'" 2>/dev/null)

echo "磁盘使用率: $DISK_USAGE"
echo "内存使用率: $MEM_USAGE"
echo "CPU 使用率: $CPU_USAGE"
echo ""

# 8. 日志文件大小
echo "=== 8. 日志文件检查 ==="
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml logs --tail=0 2>&1 | wc -l" > /dev/null 2>&1 && \
    echo "Docker 日志可用" || echo "Docker 日志不可用"
echo ""

echo "========================================="
echo "   状态检查完成"
echo "========================================="
echo ""
echo "访问地址:"
echo "  前端: http://${VM_IP}:8080"
echo "  后端: http://${VM_IP}:8081"
echo "  后端健康检查: http://${VM_IP}:8081/actuator/health"
echo ""
echo "管理命令:"
echo "  启动服务: ./scripts/start-vm-services.sh"
echo "  停止服务: ./scripts/stop-vm-services.sh"
echo "  重启服务: ./scripts/restart-vm-services.sh"
echo "  查看日志: ssh ${VM_USER}@${VM_IP} 'cd ${VM_PROJECT_DIR} && docker-compose -f docker-compose-vm-gaussdb.yml logs -f'"
echo ""
