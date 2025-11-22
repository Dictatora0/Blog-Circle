#!/bin/bash
set -e

echo "=== Initializing openGauss Standby ==="

# 等待主库就绪
until su - omm -c "gsql -h ${PRIMARY_HOST} -p ${PRIMARY_PORT} -U replicator -d postgres -c 'SELECT 1' >/dev/null 2>&1"; do
  echo "Waiting for primary database..."
  sleep 5
done

echo "Primary is ready, starting standby setup..."

# 备库配置会在 docker-compose 的 command 中处理

echo "=== Standby initialization completed ==="
