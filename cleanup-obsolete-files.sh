#!/bin/bash

###############################################################
# 清理过时配置文件和脚本
# 说明：清理虚拟机直接部署相关的旧文件，保留容器化部署相关文件
###############################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${CYAN}  清理过时配置文件和脚本  ${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo ""

CLEANED=0

# 1. 清理 target 目录中的备份文件
echo -e "${YELLOW}[1/5] 清理编译目录备份文件...${NC}"
if [ -f "backend/target/classes/application-gaussdb-cluster.yml.backup.20251122_115332" ]; then
    rm -f backend/target/classes/application-gaussdb-cluster.yml.backup.20251122_115332
    echo "  ✓ 已删除 backend/target 备份文件"
    ((CLEANED++))
fi
if [ -f "backend/target/classes/com/cloudcom/blog/config/WebConfig.java.backup.20251105_133232" ]; then
    rm -f backend/target/classes/com/cloudcom/blog/config/WebConfig.java.backup.20251105_133232
    echo "  ✓ 已删除 WebConfig 备份文件"
    ((CLEANED++))
fi

# 2. 清理虚拟机部署相关脚本（保留作为归档）
echo -e "\n${YELLOW}[2/5] 归档虚拟机部署脚本...${NC}"
mkdir -p scripts/archived-vm-scripts
VM_SCRIPTS=(
    "scripts/check-vm-status.sh"
    "scripts/restart-vm-services.sh"
    "scripts/start-vm-services.sh"
    "scripts/stop-vm-services.sh"
    "scripts/vm-deploy-opengauss.sh"
)
for script in "${VM_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        mv "$script" "scripts/archived-vm-scripts/"
        echo "  ✓ 已归档 $(basename $script)"
        ((CLEANED++))
    fi
done

# 3. 归档旧的 GaussDB 集群管理脚本
echo -e "\n${YELLOW}[3/5] 归档旧 GaussDB 管理脚本...${NC}"
mkdir -p scripts/archived-gaussdb-scripts
GAUSSDB_SCRIPTS=(
    "scripts/bootstrap-gaussdb-compose.sh"
    "scripts/cleanup-gaussdb-config.sh"
    "scripts/diagnose-gaussdb-ports.sh"
    "scripts/fix-gaussdb-ports.sh"
    "scripts/reset-gaussdb-ports.sh"
    "scripts/test-gaussdb-readwrite.sh"
    "scripts/refactor-ports.sh"
    "scripts/verify-gaussdb-cluster.sh"
    "scripts/setup-gaussdb-single-vm-cluster.sh"
)
for script in "${GAUSSDB_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        mv "$script" "scripts/archived-gaussdb-scripts/"
        echo "  ✓ 已归档 $(basename $script)"
        ((CLEANED++))
    fi
done

# 4. 归档旧的 Docker Compose 配置
echo -e "\n${YELLOW}[4/5] 归档旧 Docker Compose 配置...${NC}"
mkdir -p archived-configs
OLD_COMPOSE_FILES=(
    "docker-compose-gaussdb-cluster.yml"
    "docker-compose-vm.yml"
)
for file in "${OLD_COMPOSE_FILES[@]}"; do
    if [ -f "$file" ]; then
        mv "$file" "archived-configs/"
        echo "  ✓ 已归档 $file"
        ((CLEANED++))
    fi
done

# 5. 归档旧的部署文档
echo -e "\n${YELLOW}[5/5] 归档旧部署文档...${NC}"
OLD_DOCS=(
    "VM_DEPLOYMENT_TEST_REPORT.md"
    "DEPLOYMENT_PLAN_OPENGAUSS.md"
    "OPENGAUSS_DEPLOYMENT.md"
    "OPENGAUSS_MIGRATION_SUMMARY.md"
)
for doc in "${OLD_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        mv "$doc" "archived-configs/"
        echo "  ✓ 已归档 $doc"
        ((CLEANED++))
    fi
done

echo ""
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ 清理完成！${NC}"
echo -e "  共处理 ${CLEANED} 个文件"
echo ""
echo -e "${YELLOW}说明：${NC}"
echo "  • 备份文件已删除"
echo "  • 虚拟机部署脚本已归档至 scripts/archived-vm-scripts/"
echo "  • GaussDB 管理脚本已归档至 scripts/archived-gaussdb-scripts/"
echo "  • 旧配置文件已归档至 archived-configs/"
echo ""
echo -e "${CYAN}当前项目使用：${NC}"
echo "  • docker-compose-opengauss-cluster.yml (容器化 openGauss 集群)"
echo "  • scripts/test-opengauss-instances.sh (实例测试)"
echo "  • scripts/full_verify.sh (完整验证)"
echo ""
