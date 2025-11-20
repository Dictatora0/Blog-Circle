#!/bin/bash

# GaussDB 配置验证脚本

echo "=========================================="
echo "GaussDB 配置验证"
echo "=========================================="

# 检查 docker-compose 配置文件
echo ""
echo "[1/4] 检查 docker-compose 配置..."
if [ -f "docker-compose-gaussdb-pseudo.yml" ]; then
    echo "✓ 配置文件存在"
    
    # 检查镜像配置
    if grep -q "opengauss/opengauss:5.0.0" docker-compose-gaussdb-pseudo.yml; then
        echo "✓ 使用 GaussDB (openGauss) 镜像"
    else
        echo "✗ 未找到 GaussDB 镜像配置"
        exit 1
    fi
    
    # 检查主库配置
    if grep -q "gaussdb-primary:" docker-compose-gaussdb-pseudo.yml; then
        echo "✓ 主库配置存在"
    else
        echo "✗ 主库配置缺失"
        exit 1
    fi
    
    # 检查备库配置
    if grep -q "gaussdb-standby1:" docker-compose-gaussdb-pseudo.yml && \
       grep -q "gaussdb-standby2:" docker-compose-gaussdb-pseudo.yml; then
        echo "✓ 备库配置存在 (standby1, standby2)"
    else
        echo "✗ 备库配置不完整"
        exit 1
    fi
else
    echo "✗ 配置文件不存在"
    exit 1
fi

# 检查环境变量配置
echo ""
echo "[2/4] 检查环境变量..."
if grep -q "GS_PASSWORD" docker-compose-gaussdb-pseudo.yml && \
   grep -q "GS_DB=blog_db" docker-compose-gaussdb-pseudo.yml && \
   grep -q "GS_USER=bloguser" docker-compose-gaussdb-pseudo.yml; then
    echo "✓ GaussDB 环境变量配置正确"
else
    echo "✗ 环境变量配置不完整"
    exit 1
fi

# 检查端口配置
echo ""
echo "[3/4] 检查端口配置..."
if grep -q '"5432:5432"' docker-compose-gaussdb-pseudo.yml && \
   grep -q '"5433:5432"' docker-compose-gaussdb-pseudo.yml && \
   grep -q '"5434:5432"' docker-compose-gaussdb-pseudo.yml; then
    echo "✓ 端口配置正确"
    echo "  - 主库: 5432"
    echo "  - 备库1: 5433"
    echo "  - 备库2: 5434"
else
    echo "✗ 端口配置不完整"
    exit 1
fi

# 检查复制配置
echo ""
echo "[4/4] 检查主备复制配置..."
if grep -q "gs_basebackup" docker-compose-gaussdb-pseudo.yml; then
    echo "✓ 使用 gs_basebackup 进行主备复制"
else
    echo "✗ 未找到 gs_basebackup 配置"
    exit 1
fi

if grep -q "recovery.conf" docker-compose-gaussdb-pseudo.yml; then
    echo "✓ 备库 recovery.conf 配置存在"
else
    echo "✗ 备库恢复配置缺失"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ GaussDB 配置验证通过"
echo "=========================================="
echo ""
echo "配置摘要:"
echo "  数据库: GaussDB (openGauss 5.0.0)"
echo "  架构: 1主2备"
echo "  主库: gaussdb-primary:5432"
echo "  备库: gaussdb-standby1:5433, gaussdb-standby2:5434"
echo "  用户: bloguser"
echo "  数据库: blog_db"
echo "  复制方式: 流复制 (gs_basebackup)"
echo ""
echo "下一步:"
echo "  运行 ./start-gaussdb-cluster.sh 启动集群"
echo "=========================================="
