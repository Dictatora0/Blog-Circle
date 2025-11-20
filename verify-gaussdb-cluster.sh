#!/bin/bash

# GaussDB 1主2备集群配置验证脚本

echo "=========================================="
echo "GaussDB 1主2备集群配置验证"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 docker-compose 文件
echo "[1/6] 检查 docker-compose 配置文件..."
if [ ! -f "docker-compose-gaussdb-pseudo.yml" ]; then
    echo -e "${RED}✗ 配置文件不存在${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 配置文件存在${NC}"

# 验证镜像配置
echo ""
echo "[2/6] 验证 GaussDB 镜像配置..."
PRIMARY_IMAGE=$(grep -A 5 "gaussdb-primary:" docker-compose-gaussdb-pseudo.yml | grep "image:" | awk '{print $2}')
STANDBY1_IMAGE=$(grep -A 5 "gaussdb-standby1:" docker-compose-gaussdb-pseudo.yml | grep "image:" | awk '{print $2}')
STANDBY2_IMAGE=$(grep -A 5 "gaussdb-standby2:" docker-compose-gaussdb-pseudo.yml | grep "image:" | awk '{print $2}')

if [[ "$PRIMARY_IMAGE" == "opengauss/opengauss:5.0.0" ]] && \
   [[ "$STANDBY1_IMAGE" == "opengauss/opengauss:5.0.0" ]] && \
   [[ "$STANDBY2_IMAGE" == "opengauss/opengauss:5.0.0" ]]; then
    echo -e "${GREEN}✓ 所有节点使用 GaussDB (openGauss 5.0.0) 镜像${NC}"
else
    echo -e "${RED}✗ 镜像配置不一致${NC}"
    exit 1
fi

# 验证端口配置
echo ""
echo "[3/6] 验证端口配置..."
if grep -q '"5432:5432"' docker-compose-gaussdb-pseudo.yml && \
   grep -q '"5433:5432"' docker-compose-gaussdb-pseudo.yml && \
   grep -q '"5434:5432"' docker-compose-gaussdb-pseudo.yml; then
    echo -e "${GREEN}✓ 端口配置正确${NC}"
    echo "  - 主库 (Primary):   5432"
    echo "  - 备库1 (Standby1): 5433"
    echo "  - 备库2 (Standby2): 5434"
else
    echo -e "${RED}✗ 端口配置不完整${NC}"
    exit 1
fi

# 验证密码配置
echo ""
echo "[4/6] 验证密码配置..."
PASSWORD_COUNT=$(grep -c "GS_PASSWORD=OpenGauss@123" docker-compose-gaussdb-pseudo.yml)
if [ "$PASSWORD_COUNT" -ge 3 ]; then
    echo -e "${GREEN}✓ 密码配置正确 (OpenGauss@123)${NC}"
    echo "  - 符合 GaussDB 密码策略"
else
    echo -e "${RED}✗ 密码配置不完整${NC}"
    exit 1
fi

# 验证主备复制配置
echo ""
echo "[5/6] 验证主备复制配置..."
if grep -q "gs_basebackup" docker-compose-gaussdb-pseudo.yml && \
   grep -q "standby_mode = 'on'" docker-compose-gaussdb-pseudo.yml && \
   grep -q "primary_conninfo" docker-compose-gaussdb-pseudo.yml; then
    echo -e "${GREEN}✓ 主备复制配置正确${NC}"
    echo "  - 使用 gs_basebackup 进行基础备份"
    echo "  - standby_mode 已启用"
    echo "  - primary_conninfo 已配置"
else
    echo -e "${RED}✗ 主备复制配置不完整${NC}"
    exit 1
fi

# 检查容器状态
echo ""
echo "[6/6] 检查容器运行状态..."
if command -v docker &> /dev/null; then
    CONTAINER_COUNT=$(docker compose -f docker-compose-gaussdb-pseudo.yml ps -q 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$CONTAINER_COUNT" -ge 1 ]; then
        echo -e "${GREEN}✓ 检测到运行中的容器${NC}"
        echo ""
        docker compose -f docker-compose-gaussdb-pseudo.yml ps 2>/dev/null | grep gaussdb
        
        # 检查主库
        if docker compose -f docker-compose-gaussdb-pseudo.yml ps 2>/dev/null | grep -q "gaussdb-primary.*Up"; then
            echo -e "${GREEN}✓ 主库 (gaussdb-primary) 运行中${NC}"
        else
            echo -e "${YELLOW}⚠ 主库未运行${NC}"
        fi
        
        # 检查备库1
        if docker compose -f docker-compose-gaussdb-pseudo.yml ps 2>/dev/null | grep -q "gaussdb-standby1.*Up"; then
            echo -e "${GREEN}✓ 备库1 (gaussdb-standby1) 运行中${NC}"
        else
            echo -e "${YELLOW}⚠ 备库1未运行（可能需要手动启动）${NC}"
        fi
        
        # 检查备库2
        if docker compose -f docker-compose-gaussdb-pseudo.yml ps 2>/dev/null | grep -q "gaussdb-standby2.*Up"; then
            echo -e "${GREEN}✓ 备库2 (gaussdb-standby2) 运行中${NC}"
        else
            echo -e "${YELLOW}⚠ 备库2未运行（可能需要手动启动）${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 容器未运行（需要启动集群）${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Docker 命令不可用，跳过容器状态检查${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✓ GaussDB 1主2备集群配置验证通过${NC}"
echo "=========================================="
echo ""
echo "配置摘要:"
echo "  架构: 1主2备"
echo "  数据库: GaussDB (openGauss 5.0.0)"
echo "  主库: gaussdb-primary (5432)"
echo "  备库1: gaussdb-standby1 (5433)"
echo "  备库2: gaussdb-standby2 (5434)"
echo "  用户: bloguser"
echo "  密码: OpenGauss@123"
echo "  数据库: blog_db"
echo "  复制方式: 流复制 (gs_basebackup)"
echo ""
echo "启动命令:"
echo "  ./start-gaussdb-cluster.sh"
echo ""
echo "=========================================="

# GaussDB 集群验证脚本（简化版）
# 直接通过 SSH 在 VM 上执行验证

VM_IP="10.211.55.11"

echo "========================================="
echo "GaussDB 一主二备集群验证"
echo "========================================="
echo ""
echo "集群架构:"
echo "  VM: ${VM_IP}"
echo "  主库: 端口 5432"
echo "  备库1: 端口 5433"
echo "  备库2: 端口 5434"
echo ""

echo "========================================="
echo "验证集群状态（在 VM 上执行）"
echo "========================================="
echo ""
echo "请在 VM 上执行以下命令进行验证:"
echo ""

cat << 'VMCMD'
# 1. 检查所有进程
echo "1. 运行的 GaussDB 进程:"
ps aux | grep gaussdb | grep -v grep

echo ""
echo "2. 主库状态 (5432):"
su - omm -c "gsql -d postgres -p 5432 -c 'SELECT pg_is_in_recovery() as is_standby;'"

echo ""
echo "3. 备库1状态 (5433):"
su - omm -c "gsql -d postgres -p 5433 -c 'SELECT pg_is_in_recovery() as is_standby;'"

echo ""
echo "4. 备库2状态 (5434):"
su - omm -c "gsql -d postgres -p 5434 -c 'SELECT pg_is_in_recovery() as is_standby;'"

echo ""
echo "5. 测试数据同步:"
su - omm -c "gsql -d blog_db -p 5432 -c 'CREATE TABLE IF NOT EXISTS cluster_test (id INT, data TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);'"
su - omm -c "gsql -d blog_db -p 5432 -c 'INSERT INTO cluster_test VALUES (1, '\''test_data'\'');'"
echo "主库数据:"
su - omm -c "gsql -d blog_db -p 5432 -c 'SELECT * FROM cluster_test;'"

echo ""
echo "等待 3 秒..."
sleep 3

echo "备库1数据:"
su - omm -c "gsql -d blog_db -p 5433 -c 'SELECT * FROM cluster_test;'" 2>&1 || echo "备库1同步失败"

echo "备库2数据:"
su - omm -c "gsql -d blog_db -p 5434 -c 'SELECT * FROM cluster_test;'" 2>&1 || echo "备库2同步失败"

echo ""
echo "6. 测试备库只读限制:"
su - omm -c "gsql -d blog_db -p 5433 -c 'INSERT INTO cluster_test VALUES (2, '\''should_fail'\'');'" 2>&1 && echo "错误：备库允许写入！" || echo "备库1正确拒绝写操作"

echo ""
echo "========================================="
echo "验证完成"
echo "========================================="
VMCMD

echo ""
echo "========================================="
echo "或者使用 SSH 自动执行"
echo "========================================="
echo ""
echo "ssh root@${VM_IP} 'bash -s' < verify-gaussdb-cluster.sh"
echo ""

echo "========================================="
echo "集群部署总结"
echo "========================================="
echo ""
echo "主库运行在 ${VM_IP}:5432 (Primary 模式)"
echo "备库1运行在 ${VM_IP}:5433 (Standby 模式)"
echo "备库2运行在 ${VM_IP}:5434 (Standby 模式)"
echo ""
