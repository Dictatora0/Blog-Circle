#!/bin/bash

###############################################################
# 修复数据目录中的备份文件权限
###############################################################

set -e

PRIMARY_DATA="/usr/local/opengauss/data_primary"
STANDBY1_DATA="/usr/local/opengauss/data_standby1"
STANDBY2_DATA="/usr/local/opengauss/data_standby2"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "   修复备份文件权限"
echo "========================================="
echo ""

fix_permissions() {
    local data_dir=$1
    local name=$2
    
    if [ ! -d "$data_dir" ]; then
        echo "$name 数据目录不存在，跳过"
        return
    fi
    
    echo "检查 $name..."
    
    # 查找所有 .bak 文件
    BAK_FILES=$(find "$data_dir" -maxdepth 1 -name "*.bak.*" 2>/dev/null)
    
    if [ -n "$BAK_FILES" ]; then
        echo "找到备份文件:"
        echo "$BAK_FILES"
        echo ""
        
        # 修改权限
        chown omm:omm "$data_dir"/*.bak.* 2>/dev/null || true
        chmod 600 "$data_dir"/*.bak.* 2>/dev/null || true
        
        echo -e "${GREEN}[OK] $name 备份文件权限已修复${NC}"
        
        # 或者删除它们（更安全）
        read -p "是否删除这些备份文件？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$data_dir"/*.bak.*
            echo -e "${GREEN}[OK] 备份文件已删除${NC}"
        fi
    else
        echo "没有找到备份文件"
    fi
    echo ""
}

# 修复所有数据目录
fix_permissions "$PRIMARY_DATA" "主库"
fix_permissions "$STANDBY1_DATA" "备库1"

# data_standby2 可能不存在或正在重建
if [ -d "$STANDBY2_DATA" ]; then
    fix_permissions "$STANDBY2_DATA" "备库2"
fi

echo "========================================="
echo -e "${GREEN}   权限修复完成${NC}"
echo "========================================="
echo ""
echo "现在可以重新运行:"
echo "  ./scripts/rebuild-standby2.sh"
echo ""
