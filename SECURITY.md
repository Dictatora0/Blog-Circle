# 安全配置说明

## ⚠️ 重要提示

本项目包含的脚本和配置文件中的密码**仅用于实验环境**，请勿在生产环境中使用。

## 密码配置

### 虚拟机访问

- **IP**: 10.211.55.11
- **用户**: root
- **密码**: `747599qw@` （实验环境）

⚠️ **生产环境建议**：

- 使用 SSH 密钥认证替代密码
- 配置防火墙限制访问
- 定期更换密码

### 数据库密码

- **用户**: bloguser
- **密码**: `Blog@2025` （当前使用）
- **旧密码**: `747599qw@` （部分脚本仍在使用）

⚠️ **生产环境建议**：

- 使用环境变量管理密码
- 使用密钥管理服务（如 HashiCorp Vault）
- 启用数据库 SSL/TLS 加密连接

## 环境变量配置

推荐使用环境变量而非硬编码密码：

```bash
# 创建 .env.local 文件（不提交到 Git）
cat > .env.local << EOF
VM_IP=10.211.55.11
VM_USER=root
VM_PASSWORD=your_secure_password

GAUSSDB_HOST=10.211.55.11
GAUSSDB_PASSWORD=your_db_password
EOF

# 在脚本中使用
source .env.local
```

## 已知包含密码的文件

### 核心脚本（需要配置）

- `deploy.sh`
- `start-vm.sh`
- `stop-vm.sh`
- `status.sh`
- `sync-to-vm.sh`

### 配置文件

- `.env.cluster` （已废弃）
- `analytics/Dockerfile`

### 测试文件

- `backend/src/test/java/.../ApiEndToEndTest.java`
- `backend/src/test/java/.../DatabaseIntegrationTest.java`

### 归档脚本（低优先级）

- `scripts/archived-vm-scripts/`
- `scripts/archived-gaussdb-scripts/`
- 其他测试脚本

## 最佳实践

1. **永远不要在公开仓库中提交真实密码**
2. **使用 .gitignore 忽略包含敏感信息的文件**
3. **定期审查代码中的硬编码凭证**
4. **使用密钥管理工具管理生产环境密码**
5. **为不同环境使用不同的密码**

## 审计日志

- 2025-11-23: 初始安全审计，发现 32 处硬编码密码
- 建议：迁移到环境变量配置方案
