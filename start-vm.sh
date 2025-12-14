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

# 加载环境变量配置
if [ -f ".env.local" ]; then
    source .env.local
    echo "已加载 .env.local 配置"
else
    echo "未找到 .env.local，使用默认配置"
fi

# 虚拟机配置（支持环境变量覆盖）
VM_IP="${VM_IP:-10.211.55.11}"
VM_USER="${VM_USER:-root}"
VM_PASSWORD="${VM_PASSWORD:-747599qw@}"
VM_PROJECT_DIR="${VM_PROJECT_DIR:-/root/CloudCom}"
# 使用兼容旧版 Docker Compose 的配置文件
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose-opengauss-cluster-legacy.yml}"

echo ""
echo -e "${BOLD}${CYAN}Blog Circle 虚拟机启动${NC}"
echo -e "${CYAN}VM System Startup${NC}"
echo ""

# 检查 sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}sshpass 未安装${NC}"
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
echo -e "${BLUE}[1/8]${NC} 检查虚拟机连接..."
if ! vm_cmd "echo 'Connected'" &>/dev/null; then
    echo -e "${RED}无法连接到虚拟机 ${VM_IP}${NC}"
    exit 1
fi
echo -e "${GREEN}虚拟机连接正常${NC}"

# 检查项目目录
echo ""
echo -e "${BLUE}[2/8]${NC} 检查项目目录..."
if ! vm_cmd "[ -d ${VM_PROJECT_DIR} ]"; then
    echo -e "${RED}项目目录不存在: ${VM_PROJECT_DIR}${NC}"
    echo "请先部署项目到虚拟机"
    exit 1
fi
echo -e "${GREEN}项目目录存在${NC}"

# 同步配置文件
echo ""
echo -e "${BLUE}[3/8]${NC} 同步配置文件到虚拟机..."
echo "  • 同步 Docker Compose 配置（兼容版本）..."
sshpass -p "$VM_PASSWORD" scp -o StrictHostKeyChecking=no \
    docker-compose-opengauss-cluster-legacy.yml ${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/
echo "  • 同步脚本文件..."
vm_cmd "mkdir -p ${VM_PROJECT_DIR}/scripts"
if [ -f "scripts/full_verify.sh" ]; then
    sshpass -p "$VM_PASSWORD" scp -o StrictHostKeyChecking=no \
        scripts/full_verify.sh ${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/scripts/
    vm_cmd "chmod +x ${VM_PROJECT_DIR}/scripts/full_verify.sh"
fi
echo -e "${GREEN}配置文件同步完成${NC}"

# 检查 Docker
echo ""
echo -e "${BLUE}[4/8]${NC} 检查 Docker 环境..."
if ! vm_cmd "docker --version" &>/dev/null; then
    echo -e "${RED}Docker 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}Docker 已安装${NC}"
vm_cmd "docker --version"

# 停止已有服务并清理
echo ""
echo -e "${BLUE}[5/8]${NC} 停止已有服务并清理旧容器..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} down 2>/dev/null || true"
vm_cmd "docker rm -f blogcircle-backend blogcircle-frontend 2>/dev/null || true"
vm_cmd "docker rm -f opengauss-primary opengauss-standby1 opengauss-standby2 2>/dev/null || true"
vm_cmd "docker rm -f gaussdb-primary gaussdb-standby1 gaussdb-standby2 2>/dev/null || true"
echo -e "${GREEN}已清理旧容器${NC}"

# 在本地构建并准备所有镜像
echo ""
echo -e "${BLUE}[6/8]${NC} 在本地构建应用镜像..."

# 检查并拉取基础镜像
echo "  • 检查基础镜像..."
for img in "maven:3.8.7-eclipse-temurin-17" "eclipse-temurin:17-jre" "node:18-alpine" "nginx:alpine"; do
    if ! docker images | grep -q "${img%:*}"; then
        echo "    拉取 $img..."
        docker pull $img
    fi
done

# 构建后端镜像
echo "  • 构建后端镜像..."
docker build -t blogcircle-backend:vm ./backend || {
    echo -e "${RED}后端镜像构建失败${NC}"
    exit 1
}

# 构建前端镜像
echo "  • 构建前端镜像..."
docker build -t blogcircle-frontend:vm ./frontend || {
    echo -e "${RED}前端镜像构建失败${NC}"
    exit 1
}

echo -e "${GREEN}应用镜像构建完成${NC}"

# 传输镜像到虚拟机
echo ""
echo -e "${BLUE}[7/8]${NC} 传输镜像到虚拟机..."
mkdir -p /tmp/vm-images

echo "  • 导出 openGauss 镜像..."
docker save -o /tmp/vm-images/opengauss.tar enmotech/opengauss-lite:latest

echo "  • 导出后端镜像..."
docker save -o /tmp/vm-images/backend.tar blogcircle-backend:vm

echo "  • 导出前端镜像..."
docker save -o /tmp/vm-images/frontend.tar blogcircle-frontend:vm

echo "  • 传输镜像到虚拟机（约 500MB，请耐心等待 3-5 分钟）..."
sshpass -p "$VM_PASSWORD" scp -o StrictHostKeyChecking=no \
    /tmp/vm-images/*.tar ${VM_USER}@${VM_IP}:/tmp/

echo "  • 在虚拟机上加载镜像..."
vm_cmd "cd /tmp && \
    docker load -i opengauss.tar && \
    docker load -i backend.tar && \
    docker load -i frontend.tar && \
    rm -f *.tar"

# 清理本地临时文件
rm -rf /tmp/vm-images

echo -e "${GREEN}镜像传输完成${NC}"

# 启动服务
echo ""
echo -e "${BLUE}[8/8]${NC} 启动服务..."
echo "  • 启动 openGauss 三实例集群..."
echo "  • 启动后端服务（使用预构建镜像）..."
echo "  • 启动前端服务（使用预构建镜像）..."
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} up -d --remove-orphans"

# 等待服务就绪
echo ""
echo -e "${YELLOW}等待服务就绪...${NC}"
echo "  • 等待数据库初始化（30秒）..."
sleep 30
echo "  • 等待后端服务启动（30秒）..."
sleep 30
echo "  • 等待前端服务就绪（20秒）..."
sleep 20

# 检查服务状态
echo ""
echo -e "${YELLOW}服务状态${NC}"
vm_cmd "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} ps"

# 检查健康状态
echo ""
echo -e "${YELLOW}健康检查${NC}"

echo -n "  • openGauss 主库: "
if vm_cmd "docker exec opengauss-primary su - omm -c '/usr/local/opengauss/bin/gsql -d postgres -c \"SELECT 1\"'" &>/dev/null; then
    echo -e "${GREEN}健康${NC}"
else
    echo -e "${YELLOW}未就绪${NC}"
fi

echo -n "  • 后端服务: "
if vm_cmd "curl -sf http://localhost:8082/actuator/health" &>/dev/null; then
    echo -e "${GREEN}健康${NC}"
else
    echo -e "${YELLOW}未就绪（可能仍在初始化）${NC}"
fi

echo -n "  • 前端服务: "
if vm_cmd "curl -sf http://localhost:8080" &>/dev/null; then
    echo -e "${GREEN}健康${NC}"
else
    echo -e "${YELLOW}未就绪${NC}"
fi

# 完成
echo ""
echo -e "${BOLD}${GREEN}虚拟机服务启动完成${NC}"
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
