#!/bin/bash

set -e

# 虚拟机 openGauss 集群一键部署脚本
# 在本地机器上执行，自动完成镜像打包、传输和部署

VM_IP="10.211.55.11"
VM_USER="root"
VM_PASSWORD="747599qw@"
VM_PATH="~/CloudCom"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "openGauss 集群虚拟机部署脚本"
echo "========================================"

# 1. 检查本地环境
echo -e "\n${YELLOW}[1/7] 检查本地环境...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker 已安装${NC}"

# 2. 拉取 openGauss 镜像
echo -e "\n${YELLOW}[2/7] 拉取 openGauss 镜像...${NC}"
if docker pull opengauss/opengauss:5.0.0; then
    echo -e "${GREEN}✓ 镜像拉取成功${NC}"
else
    echo -e "${RED}✗ 镜像拉取失败，请检查网络${NC}"
    exit 1
fi

# 3. 构建后端和前端镜像
echo -e "\n${YELLOW}[3/7] 构建应用镜像...${NC}"
docker-compose -f docker-compose-opengauss-cluster.yml build
echo -e "${GREEN}✓ 应用镜像构建完成${NC}"

# 4. 保存镜像
echo -e "\n${YELLOW}[4/7] 保存镜像文件...${NC}"
mkdir -p /tmp/opengauss-deploy
docker save opengauss/opengauss:5.0.0 -o /tmp/opengauss-deploy/opengauss-5.0.0.tar
docker save cloudcom-backend:latest -o /tmp/opengauss-deploy/backend.tar
docker save cloudcom-frontend:latest -o /tmp/opengauss-deploy/frontend.tar
echo -e "${GREEN}✓ 镜像保存完成${NC}"

# 5. 传输文件到虚拟机
echo -e "\n${YELLOW}[5/7] 传输文件到虚拟机 ${VM_IP}...${NC}"

# 传输镜像
sshpass -p "$VM_PASSWORD" scp /tmp/opengauss-deploy/*.tar ${VM_USER}@${VM_IP}:~/

# 传输项目文件
sshpass -p "$VM_PASSWORD" scp -r \
  docker-compose-opengauss-cluster.yml \
  backend/ \
  frontend/ \
  scripts/ \
  OPENGAUSS_DEPLOYMENT.md \
  ${VM_USER}@${VM_IP}:${VM_PATH}/

echo -e "${GREEN}✓ 文件传输完成${NC}"

# 6. 在虚拟机上部署
echo -e "\n${YELLOW}[6/7] 在虚拟机上部署 openGauss 集群...${NC}"
sshpass -p "$VM_PASSWORD" ssh ${VM_USER}@${VM_IP} << 'ENDSSH'
set -e

cd ~/CloudCom

echo "加载 Docker 镜像..."
docker load -i ~/opengauss-5.0.0.tar
docker load -i ~/backend.tar
docker load -i ~/frontend.tar

echo "赋予脚本执行权限..."
chmod +x scripts/*.sh

echo "部署 openGauss 集群..."
./scripts/deploy-opengauss-cluster.sh

ENDSSH

echo -e "${GREEN}✓ 虚拟机部署完成${NC}"

# 7. 运行测试
echo -e "\n${YELLOW}[7/7] 运行系统测试...${NC}"
sleep 10  # 等待服务完全启动

sshpass -p "$VM_PASSWORD" ssh ${VM_USER}@${VM_IP} << 'ENDSSH'
cd ~/CloudCom
./scripts/test-opengauss-cluster.sh
ENDSSH

# 清理临时文件
rm -rf /tmp/opengauss-deploy

echo -e "\n${GREEN}========================================"
echo "部署和测试全部完成！"
echo "========================================${NC}"
echo ""
echo "虚拟机访问地址："
echo "  前端: http://${VM_IP}:8080"
echo "  后端: http://${VM_IP}:8082"
echo ""
echo "SSH 连接虚拟机："
echo "  ssh ${VM_USER}@${VM_IP}"
echo ""
echo "查看服务状态："
echo "  ssh ${VM_USER}@${VM_IP} 'cd ~/CloudCom && docker-compose -f docker-compose-opengauss-cluster.yml ps'"
echo ""
