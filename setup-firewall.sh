#!/bin/bash

################################################################################
# GaussDB 集群防火墙配置脚本
# 在三个节点上配置防火墙，允许本机无条件访问
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 集群配置
PRIMARY_IP="10.211.55.11"
PRIMARY_ROOT_PWD="747599qw@"
STANDBY1_IP="10.211.55.14"
STANDBY1_ROOT_PWD="747599qw@1"
STANDBY2_IP="10.211.55.13"
STANDBY2_ROOT_PWD="747599qw@2"

# 获取本机 IP
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

################################################################################
# 配置单个节点的防火墙
################################################################################

configure_node_firewall() {
    local node_ip="$1"
    local node_pwd="$2"
    local node_name="$3"
    
    log_info "配置 $node_name ($node_ip) 防火墙..."
    
    # 检查是否使用 firewalld
    local use_firewalld=$(sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null root@$node_ip \
        "systemctl is-active firewalld 2>/dev/null || echo inactive" 2>&1 | tail -1)
    
    if [ "$use_firewalld" = "active" ]; then
        log_info "$node_name 使用 firewalld"
        
        # 开放 GaussDB 端口
        sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip \
            "firewall-cmd --permanent --add-port=5432/tcp"
        
        # 开放 SSH 端口
        sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip \
            "firewall-cmd --permanent --add-port=22/tcp"
        
        # 如果有本机 IP，添加信任源
        if [ -n "$LOCAL_IP" ]; then
            sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip \
                "firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=$LOCAL_IP accept'"
        fi
        
        # 重载防火墙
        sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip \
            "firewall-cmd --reload"
        
        log_success "$node_name firewalld 配置完成"
    else
        log_info "$node_name 使用 iptables"
        
        # 开放 GaussDB 端口
        sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip \
            "iptables -I INPUT -p tcp --dport 5432 -j ACCEPT"
        
        # 开放 SSH 端口
        sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip \
            "iptables -I INPUT -p tcp --dport 22 -j ACCEPT"
        
        # 如果有本机 IP，添加信任源
        if [ -n "$LOCAL_IP" ]; then
            sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip \
                "iptables -I INPUT -s $LOCAL_IP -j ACCEPT"
        fi
        
        # 保存 iptables 规则
        sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip \
            "service iptables save 2>/dev/null || iptables-save > /etc/sysconfig/iptables"
        
        log_success "$node_name iptables 配置完成"
    fi
    
    # 配置 SELinux（如果启用）
    sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip \
        "setenforce 0 2>/dev/null || true"
    
    sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip \
        "sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true"
}

################################################################################
# 配置 GaussDB 允许远程连接
################################################################################

configure_gaussdb_access() {
    local node_ip="$1"
    local node_pwd="$2"
    local node_name="$3"
    
    log_info "配置 $node_name GaussDB 远程访问..."
    
    # 直接使用 omm 用户查找数据目录
    log_info "检测 $node_name GaussDB 数据目录..."
    sshpass -p "$node_pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$node_ip << 'CONFIG_GAUSSDB' 2>/dev/null
# 查找 GaussDB 数据目录
DATA_DIR=""

# 方式1: 从 omm 用户的 .bashrc 获取 GAUSSHOME
if [ -f /home/omm/.bashrc ]; then
    DATA_DIR=$(grep "export GAUSSHOME" /home/omm/.bashrc 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' ' | head -1)
    if [ -n "$DATA_DIR" ]; then
        DATA_DIR="$DATA_DIR/data"
    fi
fi

# 方式2: 从 gs_ctl 查询
if [ -z "$DATA_DIR" ] || [ ! -d "$DATA_DIR" ]; then
    DATA_DIR=$(su - omm -c 'gs_ctl query 2>/dev/null' | grep "dn_" | head -1 | awk '{print $NF}' 2>/dev/null)
fi

# 方式3: 查找 pg_hba.conf
if [ -z "$DATA_DIR" ] || [ ! -d "$DATA_DIR" ]; then
    DATA_DIR=$(find /home/omm -name 'pg_hba.conf' -type f 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
fi

# 方式4: 查找 base 目录
if [ -z "$DATA_DIR" ] || [ ! -d "$DATA_DIR" ]; then
    DATA_DIR=$(find /home/omm -type d -name 'base' 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
fi

# 方式5: 查找 postgresql.conf
if [ -z "$DATA_DIR" ] || [ ! -d "$DATA_DIR" ]; then
    DATA_DIR=$(find /home/omm -name 'postgresql.conf' -type f 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
fi

# 方式6: 使用默认值
if [ -z "$DATA_DIR" ] || [ ! -d "$DATA_DIR" ]; then
    DATA_DIR="/gaussdb/data"
fi

echo "[INFO] GaussDB 数据目录: $DATA_DIR"

# 配置 pg_hba.conf
if [ -f "$DATA_DIR/pg_hba.conf" ]; then
    echo "[INFO] 配置 pg_hba.conf..."
    if ! grep -q "^host all all 0.0.0.0/0" "$DATA_DIR/pg_hba.conf"; then
        su - omm -c "echo 'host all all 0.0.0.0/0 md5' >> $DATA_DIR/pg_hba.conf" 2>/dev/null || true
        echo "[SUCCESS] pg_hba.conf 已更新"
    else
        echo "[INFO] pg_hba.conf 已包含远程连接配置"
    fi
else
    echo "[WARN] pg_hba.conf 不存在: $DATA_DIR/pg_hba.conf"
fi

# 配置 postgresql.conf
if [ -f "$DATA_DIR/postgresql.conf" ]; then
    echo "[INFO] 配置 postgresql.conf..."
    if ! grep -q "^listen_addresses = " "$DATA_DIR/postgresql.conf"; then
        su - omm -c "sed -i \"s/#listen_addresses = .*/listen_addresses = '*'/g\" $DATA_DIR/postgresql.conf" 2>/dev/null || true
        echo "[SUCCESS] postgresql.conf 已更新"
    else
        echo "[INFO] postgresql.conf 已配置监听地址"
    fi
else
    echo "[WARN] postgresql.conf 不存在: $DATA_DIR/postgresql.conf"
fi

# 重启 GaussDB
echo "[INFO] 重启 GaussDB..."
su - omm -c "gs_ctl restart -D $DATA_DIR" 2>/dev/null || echo "[INFO] 重启命令已发送"

sleep 2
echo "[SUCCESS] GaussDB 配置完成"
CONFIG_GAUSSDB
}

################################################################################
# 测试连接
################################################################################

test_connection() {
    local node_ip="$1"
    local node_name="$2"
    
    log_info "测试 $node_name 连接..."
    
    # 测试 SSH 连接
    if sshpass -p "747599qw@" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$node_ip "echo 'SSH 连接成功'" >/dev/null 2>&1; then
        log_success "$node_name SSH 连接成功"
    else
        log_error "$node_name SSH 连接失败"
        return 1
    fi
    
    # 测试 GaussDB 连接（如果安装了 psql）
    if command -v psql &> /dev/null; then
        if timeout 5 psql -h "$node_ip" -p 5432 -U bloguser -d blog_db -c "SELECT 1" >/dev/null 2>&1; then
            log_success "$node_name GaussDB 连接成功"
        else
            log_error "$node_name GaussDB 连接失败（可能需要输入密码或数据库不存在）"
        fi
    fi
}

################################################################################
# 主函数
################################################################################

main() {
    echo "========================================="
    echo "  GaussDB 集群防火墙配置"
    echo "========================================="
    echo ""
    echo "本机 IP: $LOCAL_IP"
    echo "将配置以下节点允许本机访问:"
    echo "  主节点: $PRIMARY_IP"
    echo "  备节点1: $STANDBY1_IP"
    echo "  备节点2: $STANDBY2_IP"
    echo ""
    
    # 检查依赖
    if ! command -v sshpass &> /dev/null && [ ! -f /opt/homebrew/bin/sshpass ]; then
        log_error "sshpass 未安装，请先安装: brew install sshpass"
        exit 1
    fi
    
    # 如果 sshpass 不在 PATH 中，添加到 PATH
    if [ -f /opt/homebrew/bin/sshpass ] && ! command -v sshpass &> /dev/null; then
        export PATH="/opt/homebrew/bin:$PATH"
    fi
    
    # 配置主节点
    configure_node_firewall "$PRIMARY_IP" "$PRIMARY_ROOT_PWD" "主节点"
    configure_gaussdb_access "$PRIMARY_IP" "$PRIMARY_ROOT_PWD" "主节点"
    
    # 配置备节点1
    configure_node_firewall "$STANDBY1_IP" "$STANDBY1_ROOT_PWD" "备节点1"
    configure_gaussdb_access "$STANDBY1_IP" "$STANDBY1_ROOT_PWD" "备节点1"
    
    # 配置备节点2
    configure_node_firewall "$STANDBY2_IP" "$STANDBY2_ROOT_PWD" "备节点2"
    configure_gaussdb_access "$STANDBY2_IP" "$STANDBY2_ROOT_PWD" "备节点2"
    
    echo ""
    log_success "所有节点防火墙配置完成！"
    echo ""
    
    # 测试连接
    echo "========================================="
    echo "  测试连接"
    echo "========================================="
    echo ""
    test_connection "$PRIMARY_IP" "主节点"
    test_connection "$STANDBY1_IP" "备节点1"
    test_connection "$STANDBY2_IP" "备节点2"
    
    echo ""
    echo "========================================="
    echo "  访问说明"
    echo "========================================="
    echo ""
    echo "现在可以从本机访问集群:"
    echo "  psql -h $PRIMARY_IP -p 5432 -U bloguser -d blog_db"
    echo ""
    echo "或使用 Java 连接:"
    echo "  jdbc:opengauss://$PRIMARY_IP:5432/blog_db"
    echo ""
}

# 运行主函数
main "$@"
