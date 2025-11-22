#!/bin/bash

###############################################################
# 完整清理并重建容器化系统
# 第一阶段：清理所有旧环境
# 第二阶段：构建全新的容器化部署
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
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# 检查 sshpass
if ! command -v sshpass &> /dev/null; then
    if [ -f "/opt/homebrew/bin/sshpass" ]; then
        SSHPASS="/opt/homebrew/bin/sshpass"
    else
        echo -e "${RED}❌ 未找到 sshpass${NC}"
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
        -o ConnectTimeout=10 \
        ${VM_USER}@${VM_IP} "$1" 2>&1 | grep -v "Authorized users"
}

echo ""
echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}║       完整清理并重建容器化系统                             ║${NC}"
echo -e "${BOLD}${MAGENTA}║       Full Cleanup & Docker Rebuild                        ║${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

#############################################################
# 阶段 1: 清理虚拟机环境
#############################################################

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  阶段 1/2: 清理虚拟机环境  ${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

# 1.1 停止并删除所有 Docker 容器
echo -e "${BOLD}${BLUE}▶ 步骤 1/8: 停止并删除 Docker 容器${NC}"
vm_cmd "docker stop \$(docker ps -aq) 2>/dev/null || true"
vm_cmd "docker rm -f \$(docker ps -aq) 2>/dev/null || true"
echo -e "${GREEN}  ✓ Docker 容器已清理${NC}"
echo ""

# 1.2 删除 Docker 镜像
echo -e "${BOLD}${BLUE}▶ 步骤 2/8: 删除 Docker 镜像${NC}"
vm_cmd "docker rmi -f \$(docker images -q) 2>/dev/null || true"
echo -e "${GREEN}  ✓ Docker 镜像已清理${NC}"
echo ""

# 1.3 删除 Docker volumes 和 networks
echo -e "${BOLD}${BLUE}▶ 步骤 3/8: 清理 Docker volumes 和 networks${NC}"
vm_cmd "docker volume prune -f 2>/dev/null || true"
vm_cmd "docker network prune -f 2>/dev/null || true"
vm_cmd "docker system prune -a -f 2>/dev/null || true"
echo -e "${GREEN}  ✓ Docker 资源已清理${NC}"
echo ""

# 1.4 停止所有 GaussDB 进程
echo -e "${BOLD}${BLUE}▶ 步骤 4/8: 停止 GaussDB 进程${NC}"
vm_cmd "pkill -9 gaussdb 2>/dev/null || true"
vm_cmd "pkill -9 gs_ctl 2>/dev/null || true"
sleep 2
echo -e "${GREEN}  ✓ GaussDB 进程已停止${NC}"
echo ""

# 1.5 删除 GaussDB 数据目录
echo -e "${BOLD}${BLUE}▶ 步骤 5/8: 删除 GaussDB 数据目录${NC}"
vm_cmd "rm -rf /usr/local/opengauss/data_primary 2>/dev/null || true"
vm_cmd "rm -rf /usr/local/opengauss/data_standby1 2>/dev/null || true"
vm_cmd "rm -rf /usr/local/opengauss/data_standby2 2>/dev/null || true"
vm_cmd "rm -rf /usr/local/opengauss/data 2>/dev/null || true"
vm_cmd "rm -rf /gaussdb/data 2>/dev/null || true"
echo -e "${GREEN}  ✓ GaussDB 数据目录已删除${NC}"
echo ""

# 1.6 清理端口占用
echo -e "${BOLD}${BLUE}▶ 步骤 6/8: 清理端口占用${NC}"
for port in 5432 5434 5436 8080 8081; do
    vm_cmd "lsof -ti:$port | xargs kill -9 2>/dev/null || true"
done
echo -e "${GREEN}  ✓ 端口已释放${NC}"
echo ""

# 1.7 清理项目日志和缓存
echo -e "${BOLD}${BLUE}▶ 步骤 7/8: 清理日志和缓存${NC}"
vm_cmd "rm -rf ~/${VM_PROJECT_DIR}/backend/logs/* 2>/dev/null || true"
vm_cmd "rm -rf /tmp/backend.log /tmp/*.sql 2>/dev/null || true"
vm_cmd "rm -rf ~/${VM_PROJECT_DIR}/nohup.out 2>/dev/null || true"
echo -e "${GREEN}  ✓ 日志和缓存已清理${NC}"
echo ""

# 1.8 验证清理结果
echo -e "${BOLD}${BLUE}▶ 步骤 8/8: 验证清理结果${NC}"
CONTAINERS=$(vm_cmd "docker ps -a -q | wc -l" | tr -d ' ')
IMAGES=$(vm_cmd "docker images -q | wc -l" | tr -d ' ')
GAUSSDB_PROC=$(vm_cmd "ps aux | grep gaussdb | grep -v grep | wc -l" | tr -d ' ')

echo -e "  Docker 容器数: ${CYAN}${CONTAINERS}${NC}"
echo -e "  Docker 镜像数: ${CYAN}${IMAGES}${NC}"
echo -e "  GaussDB 进程数: ${CYAN}${GAUSSDB_PROC}${NC}"

if [ "$CONTAINERS" = "0" ] && [ "$IMAGES" = "0" ] && [ "$GAUSSDB_PROC" = "0" ]; then
    echo -e "${GREEN}  ✓ 虚拟机环境清理完成${NC}"
else
    echo -e "${YELLOW}  ⚠ 部分资源未完全清理${NC}"
fi
echo ""

echo -e "${BOLD}${GREEN}✓ 阶段 1 完成: 虚拟机环境已清理${NC}"
echo ""
sleep 2

#############################################################
# 阶段 2: 本地项目清理
#############################################################

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  阶段 2/2: 清理本地项目文件  ${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

cd "$(dirname "$0")/.."

# 2.1 删除旧的部署脚本
echo -e "${BOLD}${BLUE}▶ 删除旧的部署脚本${NC}"

SCRIPTS_TO_DELETE=(
    "init-gaussdb-cluster.sh"
    "setup-gaussdb-single-vm-cluster.sh"
    "demo-full-test.sh"
    "sync-scripts-to-vm.sh"
    "test-vm-apis.sh"
    "docker-compose-vm-gaussdb.yml"
)

for script in "${SCRIPTS_TO_DELETE[@]}"; do
    if [ -f "$script" ]; then
        rm -f "$script"
        echo -e "  ${GREEN}✓${NC} 删除: $script"
    fi
done
echo ""

# 2.2 删除 scripts 目录中的旧脚本
echo -e "${BOLD}${BLUE}▶ 删除 scripts/ 目录中的旧脚本${NC}"

OLD_SCRIPTS=(
    "scripts/setup-gaussdb-replication.sh"
    "scripts/refactor-ports.sh"
    "scripts/reset-gaussdb-ports.sh"
    "scripts/fix-gaussdb-ports.sh"
    "scripts/diagnose-gaussdb-ports.sh"
    "scripts/fix-primary-replication.sh"
    "scripts/rebuild-standby2.sh"
    "scripts/sync-gaussdb-data.sh"
    "scripts/cleanup-gaussdb-config.sh"
    "scripts/check-standby2-logs.sh"
    "scripts/full-reset-cluster.sh"
    "scripts/fix-backup-permissions.sh"
    "scripts/start-vm-services.sh"
    "scripts/stop-vm-services.sh"
    "scripts/restart-vm-services.sh"
    "scripts/check-vm-status.sh"
    "scripts/verify-gaussdb-cluster.sh"
    "scripts/test-gaussdb-readwrite.sh"
    "scripts/test-ha-failover.sh"
    "scripts/start-backend.sh"
    "scripts/start-backend-vm.sh"
    "scripts/stop-backend.sh"
    "scripts/diagnose-backend.sh"
    "scripts/deploy-backend-to-vm.sh"
    "scripts/fix-backend-vm.sh"
    "scripts/fix-backend-docker.sh"
    "scripts/reset-gaussdb-user.sh"
    "scripts/reset-all-gaussdb-instances.sh"
    "scripts/update-backend-config.sh"
    "scripts/start-frontend.sh"
    "scripts/test-e2e.sh"
    "scripts/test-performance.sh"
    "scripts/test-spark-gaussdb.sh"
    "scripts/verify-api-mapping.sh"
    "scripts/bootstrap-gaussdb-compose.sh"
)

for script in "${OLD_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        rm -f "$script"
        echo -e "  ${GREEN}✓${NC} 删除: $(basename $script)"
    fi
done
echo ""

# 2.3 删除旧的 gaussdb-docker 目录
echo -e "${BOLD}${BLUE}▶ 删除旧的 gaussdb-docker 配置${NC}"
if [ -d "gaussdb-docker" ]; then
    rm -rf gaussdb-docker
    echo -e "  ${GREEN}✓${NC} 删除: gaussdb-docker/"
fi
echo ""

echo -e "${BOLD}${GREEN}✓ 本地项目清理完成${NC}"
echo ""

#############################################################
# 总结
#############################################################

echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}║              清理完成！                                    ║${NC}"
echo -e "${BOLD}${MAGENTA}║              Cleanup Complete!                             ║${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}清理统计:${NC}"
echo -e "  ${GREEN}✓${NC} 虚拟机 Docker 容器已清理"
echo -e "  ${GREEN}✓${NC} 虚拟机 Docker 镜像已清理"
echo -e "  ${GREEN}✓${NC} GaussDB 本地安装已清理"
echo -e "  ${GREEN}✓${NC} 旧部署脚本已删除"
echo -e "  ${GREEN}✓${NC} 源代码完整保留"
echo ""

echo -e "${BOLD}${CYAN}下一步:${NC}"
echo -e "  1. 运行重建脚本: ${CYAN}./scripts/rebuild-docker-system.sh${NC}"
echo -e "  2. 或使用新的 docker-compose: ${CYAN}docker-compose up -d --build${NC}"
echo ""
