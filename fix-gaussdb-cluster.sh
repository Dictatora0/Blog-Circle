#!/bin/bash

# 修复虚拟机上的 GaussDB 一主二备集群
# 在虚拟机 10.211.55.11 上执行

set -e

echo "========================================="
echo "修复 GaussDB 一主二备集群"
echo "========================================="
echo ""

echo "1. 停止所有 GaussDB 实例..."
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_primary -m fast" 2>/dev/null || echo "主库已停止或未运行"
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_standby1 -m fast" 2>/dev/null || echo "备库1已停止或未运行"
su - omm -c "gs_ctl stop -D /usr/local/opengauss/data_standby2 -m fast" 2>/dev/null || echo "备库2已停止或未运行"
sleep 3

echo ""
echo "2. 清理锁文件..."
rm -f /usr/local/opengauss/data_primary/postmaster.pid 2>/dev/null || true
rm -f /usr/local/opengauss/data_standby1/postmaster.pid 2>/dev/null || true
rm -f /usr/local/opengauss/data_standby2/postmaster.pid 2>/dev/null || true

echo ""
echo "3. 检查主库配置文件..."
if [ -f "/usr/local/opengauss/data_primary/standby.signal" ]; then
    echo "警告：主库目录存在 standby.signal 文件，这会导致主库以备库模式启动"
    echo "删除 standby.signal..."
    rm -f /usr/local/opengauss/data_primary/standby.signal
fi

echo ""
echo "4. 启动主库..."
su - omm -c "gs_ctl start -D /usr/local/opengauss/data_primary"
sleep 5

echo ""
echo "5. 检查主库状态..."
su - omm -c "gs_ctl status -D /usr/local/opengauss/data_primary"

echo ""
echo "6. 启动备库1..."
su - omm -c "gs_ctl start -D /usr/local/opengauss/data_standby1" || echo "备库1启动失败"
sleep 3

echo ""
echo "7. 启动备库2..."
su - omm -c "gs_ctl start -D /usr/local/opengauss/data_standby2" || echo "备库2启动失败"
sleep 3

echo ""
echo "8. 验证集群状态..."
echo "--- 主库 ---"
su - omm -c "gs_ctl status -D /usr/local/opengauss/data_primary"
echo ""
echo "--- 备库1 ---"
su - omm -c "gs_ctl status -D /usr/local/opengauss/data_standby1"
echo ""
echo "--- 备库2 ---"
su - omm -c "gs_ctl status -D /usr/local/opengauss/data_standby2"

echo ""
echo "9. 查询复制状态..."
su - omm -c "gsql -d blog_db -p 5432 -c 'SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;'" || echo "无法查询复制状态"

echo ""
echo "========================================="
echo "修复完成！"
echo "========================================="
