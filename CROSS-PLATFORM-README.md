# 跨平台部署指南

本项目支持 macOS、Linux 和 Windows 系统。

## 🖥️ 选择你的操作系统

### macOS / Linux

使用 Bash 脚本：

```bash
# 启动虚拟机服务
./start-vm.sh

# 停止虚拟机服务
./stop-vm.sh

# 直接在虚拟机上部署
./deploy-on-vm.sh
```

**前提条件**：

- `sshpass` 工具（用于 SSH 密码认证）
- Docker（用于本地构建镜像）

**安装 sshpass**：

```bash
# macOS
brew install hudochenkov/sshpass/sshpass

# Ubuntu/Debian
sudo apt-get install sshpass

# CentOS/RHEL
sudo yum install sshpass
```

### Windows

使用 PowerShell 脚本：

```powershell
# 启动虚拟机服务
.\start-vm.ps1

# 停止虚拟机服务
.\stop-vm.ps1
```

**前提条件**：

- OpenSSH 客户端（Windows 10+ 自带，需启用）
- Docker Desktop
- SSH 密钥认证（PowerShell 不支持命令行密码）

**详细设置**：查看 [WINDOWS-SETUP-GUIDE.md](WINDOWS-SETUP-GUIDE.md)

## 📁 脚本文件对照表

| 功能            | macOS/Linux             | Windows        |
| --------------- | ----------------------- | -------------- |
| 启动虚拟机服务  | `start-vm.sh`           | `start-vm.ps1` |
| 停止虚拟机服务  | `stop-vm.sh`            | `stop-vm.ps1`  |
| 直接在 VM 部署  | `deploy-on-vm.sh`       | -              |
| 同步修复文件    | `sync-fix-to-vm.sh`     | -              |
| Docker 网络修复 | `fix-docker-network.sh` | -              |

## 🚀 快速开始

### 方案 1: 从本地构建和部署（推荐）

**macOS/Linux**:

```bash
./start-vm.sh
```

**Windows**:

```powershell
# 1. 配置 SSH 密钥（首次）
ssh-keygen -t rsa
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@10.211.55.11 "cat >> ~/.ssh/authorized_keys"

# 2. 启动服务
.\start-vm.ps1
```

### 方案 2: 直接在虚拟机上构建（仅限有 SSH 访问）

```bash
# 1. 上传项目到虚拟机
rsync -avz ./ root@10.211.55.11:~/CloudCom/

# 2. SSH 到虚拟机
ssh root@10.211.55.11

# 3. 部署
cd ~/CloudCom
chmod +x deploy-on-vm.sh
./deploy-on-vm.sh
```

## ⚙️ 配置环境变量

创建 `.env.local` 文件来覆盖默认配置：

```bash
# 虚拟机配置
VM_IP=10.211.55.11
VM_USER=root
VM_PASSWORD=747599qw@
VM_PROJECT_DIR=/root/CloudCom

# Docker Compose 配置文件
COMPOSE_FILE=docker-compose-opengauss-cluster-legacy.yml
```

## 📊 部署流程对比

### start-vm.sh / start-vm.ps1（从本地部署）

```
[Mac/Windows] → 构建镜像 → 传输到虚拟机 → 启动服务
     ↓              ↓              ↓           ↓
   本地          本地 Docker    SCP/SSH    VM Docker
```

**优点**：

- ✅ 利用本地强大的构建能力
- ✅ 网络条件好时更快
- ✅ 适合开发迭代

**缺点**：

- ❌ 需要传输大文件
- ❌ 本地需要 Docker

### deploy-on-vm.sh（虚拟机上部署）

```
[VM] → 拉取基础镜像 → 构建应用 → 启动服务
  ↓         ↓            ↓         ↓
内网     Docker Hub   VM Docker  VM Docker
```

**优点**：

- ✅ 不需要本地 Docker
- ✅ 不需要传输大文件
- ✅ 适合生产部署

**缺点**：

- ❌ 需要虚拟机有外网访问
- ❌ 构建时间较长

## 🔍 故障排查

### macOS/Linux 问题

**sshpass not found**:

```bash
brew install hudochenkov/sshpass/sshpass
```

**Permission denied**:

```bash
chmod +x *.sh
```

### Windows 问题

**脚本无法运行**:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**SSH 需要密码**:

```powershell
# 配置密钥认证（详见 WINDOWS-SETUP-GUIDE.md）
ssh-keygen -t rsa
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@10.211.55.11 "cat >> ~/.ssh/authorized_keys"
```

### 通用问题

**Docker Hub 连接超时**:

```bash
# 使用虚拟机部署方式
ssh root@10.211.55.11
cd ~/CloudCom
./fix-docker-network.sh  # 配置镜像源
./deploy-on-vm.sh
```

**虚拟机连接失败**:

```bash
# 测试连接
ping 10.211.55.11
ssh root@10.211.55.11 "echo OK"

# 检查 SSH 服务
ssh root@10.211.55.11 "systemctl status sshd"
```

## 📚 相关文档

- [WINDOWS-SETUP-GUIDE.md](WINDOWS-SETUP-GUIDE.md) - Windows 详细设置指南
- [VM-DEPLOY-README.md](VM-DEPLOY-README.md) - 虚拟机部署快速指南
- [NETWORK-FIX-GUIDE.md](NETWORK-FIX-GUIDE.md) - Docker 网络问题解决
- [docs/vm-deployment-guide.md](docs/vm-deployment-guide.md) - 完整部署文档

## 🎯 推荐方案

| 场景               | 推荐脚本                     | 平台              |
| ------------------ | ---------------------------- | ----------------- |
| 开发调试（网络好） | `start-vm.sh`                | macOS/Linux       |
| 开发调试（网络好） | `start-vm.ps1`               | Windows           |
| 生产部署（虚拟机） | `deploy-on-vm.sh`            | 任何（SSH 到 VM） |
| 网络受限           | `deploy-on-vm.sh` + 离线镜像 | 任何（SSH 到 VM） |

## ✅ 成功标志

部署成功后，你应该能访问：

- 前端：http://10.211.55.11:8080
- 后端 API：http://10.211.55.11:8082
- 健康检查：http://10.211.55.11:8082/actuator/health

## 🛟 获取帮助

根据你的操作系统查看相应文档：

- **Windows 用户**：[WINDOWS-SETUP-GUIDE.md](WINDOWS-SETUP-GUIDE.md)
- **网络问题**：[NETWORK-FIX-GUIDE.md](NETWORK-FIX-GUIDE.md)
- **虚拟机部署**：[VM-DEPLOY-README.md](VM-DEPLOY-README.md)

---

**选择适合你的平台开始部署！** 🚀
