#!/bin/bash

###############################################################
# Blog Circle 虚拟机启动脚本
# 通过 SSH 在虚拟机上启动服务
###############################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# 虚拟机配置
VM_IP="10.211.55.11"
VM_USER="root"
VM_PASSWORD="747599qw@"
VM_PROJECT_DIR="/root/CloudCom"
COMPOSE_FILE="docker-compose-opengauss-cluster.yml"

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                ║${NC}"
echo -e "${BOLD}${CYAN}║       Blog Circle 虚拟机启动                   ║${NC}"
echo -e "${BOLD}${CYAN}║       VM System Startup                        ║${NC}"
echo -e "${BOLD}${CYAN}║                                                ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════╝${NC}"
echo ""

# 检查 sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}✗ sshpass 未安装${NC}"
    echo "安装方法："
    echo "  macOS: brew install hudochenkov/sshpass/sshpass"
    echo "  Linux: sudo apt-get install sshpass"
    exit 1
fi

# SSH 命令封装
vm_cmd() {
    sshpass -p "$VM_PASSWORD" ssh \
        -o StrictHostKeyChecking=no \
        -o PubkeyAuthentication=no \
        -o PasswordAuthentication=yes \
        ${VM_USER}@${VM_IP} "$1"
}

# 检查虚拟机连接
echo -e "${BLUE}[1/7]${NC} 检查虚拟机连接..."
if ! vm_cmd "echo 'Connected'" &>/dev/null; then
    echo -e "${RED}✗ 无法连接到虚拟机 ${VM_IP}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 虚拟机连接正常${NC}"

# 检查项目目录
echo ""
echo -e "${BLUE}[2/7]${NC} 检查项目目录..."
if ! vm_cmd "[ -d ${VM_PROJECT_DIR} ]"; then
    echo -e "${RED}✗ 项目目录不存在: ${VM_PROJECT_DIR}${NC}"
    echo "请先部署项目到虚拟机"
    exit 1
fi
echo -e "${GREEN}✓ 项目目录存在${NC}"

# 检查 Docker
echo ""
echo -e "${BLUE}[3/7]${NC} 检查 Docker 环境..."
if ! vm_cmd "docker --version" &>/dev/null; then
    echo -e "${RED}✗ Docker 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker 已安装${NC}"
vm_cmd "docker --version"

# 停止已有服务
echo ""
echo -e "${BLUE}[4/7]${NC} 停止已有服务..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} down 2>/dev/null || true"
echo -e "${GREEN}✓ 已清理旧容器${NC}"

# 拉取镜像
echo ""
echo -e "${BLUE}[5/7]${NC} 拉取 openGauss 镜像..."
vm_cmd "docker pull enmotech/opengauss-lite:latest"
echo -e "${GREEN}✓ 镜像已就绪${NC}"

# 启动服务
echo ""
echo -e "${BLUE}[6/7]${NC} 启动服务..."
echo "  • 启动 openGauss 三实例集群..."
echo "  • 构建并启动后端服务..."
echo "  • 构建并启动前端服务..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} up -d --build"

# 等待服务就绪
echo ""
echo -e "${BLUE}[7/7]${NC} 等待服务就绪..."
echo "  • 等待数据库初始化（90秒）..."
sleep 30
echo "  • 等待后端服务启动（60秒）..."
sleep 30
echo "  • 等待前端服务就绪（30秒）..."
sleep 30

# 检查服务状态
echo ""
echo -e "${YELLOW}═══ 服务状态 ═══${NC}"
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} ps"

# 检查健康状态
echo ""
echo -e "${YELLOW}═══ 健康检查 ═══${NC}"

echo -n "  • openGauss 主库: "
if vm_cmd "docker exec opengauss-primary su - omm -c '/usr/local/opengauss/bin/gsql -d postgres -c \"SELECT 1\"'" &>/dev/null; then
    echo -e "${GREEN}✓ 健康${NC}"
else
    echo -e "${YELLOW}⚠ 未就绪${NC}"
fi

echo -n "  • 后端服务: "
if vm_cmd "curl -sf http://localhost:8082/actuator/health" &>/dev/null; then
    echo -e "${GREEN}✓ 健康${NC}"
else
    echo -e "${YELLOW}⚠ 未就绪（可能仍在初始化）${NC}"
fi

echo -n "  • 前端服务: "
if vm_cmd "curl -sf http://localhost:8080" &>/dev/null; then
    echo -e "${GREEN}✓ 健康${NC}"
else
    echo -e "${YELLOW}⚠ 未就绪${NC}"
fi

# 完成
echo ""
echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                                                ║${NC}"
echo -e "${BOLD}${GREEN}║  ✓ 虚拟机服务启动完成！                       ║${NC}"
echo -e "${BOLD}${GREEN}║    VM System Started Successfully!             ║${NC}"
echo -e "${BOLD}${GREEN}║                                                ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}访问地址：${NC}"
echo -e "  • 前端：${CYAN}http://${VM_IP}:8080${NC}"
echo -e "  • 后端：${CYAN}http://${VM_IP}:8082${NC}"
echo -e "  • 健康检查：${CYAN}http://${VM_IP}:8082/actuator/health${NC}"
echo ""
echo -e "${BOLD}数据库连接：${NC}"
echo -e "  • 主库：${CYAN}${VM_IP}:5432${NC}"
echo -e "  • 备库1：${CYAN}${VM_IP}:5434${NC}"
echo -e "  • 备库2：${CYAN}${VM_IP}:5436${NC}"
echo ""
echo -e "${BOLD}常用命令：${NC}"
echo -e "  • 查看日志：${CYAN}./scripts/check_db.sh${NC} (在虚拟机上)"
echo -e "  • 停止服务：${CYAN}./stop-vm.sh${NC}"
echo -e "  • 系统验证：${CYAN}./scripts/full_verify.sh${NC} (在虚拟机上)"
echo ""
