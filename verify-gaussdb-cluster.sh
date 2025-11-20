#!/bin/bash

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
