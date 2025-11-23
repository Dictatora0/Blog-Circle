#!/bin/bash

###############################################################
# Blog Circle 状态检查脚本
# 快速查看本地或虚拟机服务状态
###############################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# 加载环境变量配置
[ -f ".env.local" ] && source .env.local

MODE="${1:-local}"
VM_IP="${VM_IP:-10.211.55.11}"
VM_USER="${VM_USER:-root}"
VM_PASSWORD="${VM_PASSWORD:-747599qw@}"

echo ""
echo -e "${BOLD}${CYAN}═══ Blog Circle 服务状态 ═══${NC}"
echo ""

if [ "$MODE" = "local" ]; then
    echo -e "${BOLD}环境：${NC}本地开发环境 (localhost)"
    echo -e "${BOLD}数据库：${NC}PostgreSQL 15"
    echo ""
    
    # 检查容器状态
    echo -e "${YELLOW}容器状态：${NC}"
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        docker-compose ps 2>/dev/null || echo "  无运行中的容器"
    else
        echo "  Docker 未运行"
    fi
    
    echo ""
    echo -e "${YELLOW}服务健康检查：${NC}"
    
    # 检查前端
    echo -n "  • 前端 (8080): "
    if curl -sf http://localhost:8080 &>/dev/null; then
        echo -e "${GREEN}✓ 运行中${NC}"
    else
        echo -e "${RED}✗ 停止${NC}"
    fi
    
    # 检查后端
    echo -n "  • 后端 (8081): "
    if curl -sf http://localhost:8081/actuator/health &>/dev/null; then
        echo -e "${GREEN}✓ 健康${NC}"
    else
        echo -e "${RED}✗ 停止${NC}"
    fi
    
    # 检查数据库
    echo -n "  • PostgreSQL (5432): "
    if docker exec blogcircle-db pg_isready -U bloguser -d blog_db &>/dev/null; then
        echo -e "${GREEN}✓ 运行中${NC}"
    else
        echo -e "${RED}✗ 停止${NC}"
    fi
    
elif [ "$MODE" = "vm" ]; then
    echo -e "${BOLD}环境：${NC}虚拟机 (${VM_IP})"
    echo -e "${BOLD}数据库：${NC}openGauss 集群"
    echo ""
    
    # 检查 sshpass
    if ! command -v sshpass &>/dev/null; then
        echo -e "${RED}✗ sshpass 未安装，无法检查虚拟机状态${NC}"
        exit 1
    fi
    
    vm_cmd() {
        sshpass -p "$VM_PASSWORD" ssh \
            -o StrictHostKeyChecking=no \
            -o PubkeyAuthentication=no \
            -o PasswordAuthentication=yes \
            ${VM_USER}@${VM_IP} "$1" 2>/dev/null
    }
    
    # 检查连接
    echo -n "  • 虚拟机连接: "
    if vm_cmd "echo 'Connected'" &>/dev/null; then
        echo -e "${GREEN}✓ 正常${NC}"
    else
        echo -e "${RED}✗ 无法连接${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}容器状态：${NC}"
    vm_cmd "cd /root/CloudCom && docker-compose -f docker-compose-opengauss-cluster-legacy.yml ps" || echo "  无运行中的容器"
    
    echo ""
    echo -e "${YELLOW}服务健康检查：${NC}"
    
    # 检查前端
    echo -n "  • 前端 (8080): "
    if vm_cmd "curl -sf http://localhost:8080" &>/dev/null; then
        echo -e "${GREEN}✓ 运行中${NC}"
    else
        echo -e "${RED}✗ 停止${NC}"
    fi
    
    # 检查后端
    echo -n "  • 后端 (8082): "
    if vm_cmd "curl -sf http://localhost:8082/actuator/health" &>/dev/null; then
        echo -e "${GREEN}✓ 健康${NC}"
    else
        echo -e "${RED}✗ 停止${NC}"
    fi
    
    # 检查数据库
    echo -n "  • openGauss 主库 (5432): "
    if vm_cmd "docker exec opengauss-primary su - omm -c '/usr/local/opengauss/bin/gsql -d postgres -c \"SELECT 1\"'" &>/dev/null; then
        echo -e "${GREEN}✓ 运行中${NC}"
    else
        echo -e "${RED}✗ 停止${NC}"
    fi
    
else
    echo "用法: $0 [local|vm]"
    echo "  local - 检查本地服务状态 (默认)"
    echo "  vm    - 检查虚拟机服务状态"
    exit 1
fi

echo ""
echo -e "${BOLD}常用命令：${NC}"
if [ "$MODE" = "local" ]; then
    echo "  • 启动服务: ${CYAN}./start-local.sh${NC}"
    echo "  • 停止服务: ${CYAN}./stop-local.sh${NC}"
    echo "  • 查看日志: ${CYAN}docker-compose logs -f${NC}"
    echo "  • 数据库连接: ${CYAN}docker exec -it blogcircle-db psql -U bloguser -d blog_db${NC}"
else
    echo "  • 启动服务: ${CYAN}./start-vm.sh${NC}"
    echo "  • 停止服务: ${CYAN}./stop-vm.sh${NC}"
    echo "  • SSH 连接: ${CYAN}ssh ${VM_USER}@${VM_IP}${NC}"
fi
echo ""
