# Windows 系统使用指南

本指南说明如何在 Windows 系统上使用 PowerShell 脚本部署和管理虚拟机服务。

## 📋 前提条件

### 1. 安装 OpenSSH 客户端

#### 方法 A: 通过 Windows 设置安装（推荐）

1. 打开 **设置** > **应用** > **可选功能**
2. 点击 **添加功能**
3. 搜索 **OpenSSH 客户端**
4. 点击 **安装**
5. 安装完成后重启 PowerShell

#### 方法 B: 通过 PowerShell 安装

以管理员身份运行 PowerShell：

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

#### 验证安装

```powershell
ssh -V
```

应该显示类似：`OpenSSH_for_Windows_8.1p1, LibreSSL 3.0.2`

### 2. 安装 Docker Desktop

1. 下载：https://www.docker.com/products/docker-desktop/
2. 安装并启动 Docker Desktop
3. 验证安装：

```powershell
docker --version
docker-compose --version
```

### 3. 配置 SSH 密钥认证

Windows PowerShell 的 SSH 不支持命令行密码输入，需要配置密钥认证。

#### 生成 SSH 密钥

```powershell
# 生成密钥（如果还没有）
ssh-keygen -t rsa -b 4096

# 密钥将保存在: C:\Users\你的用户名\.ssh\id_rsa
```

#### 复制公钥到虚拟机

**方法 1: 使用 type 命令（推荐）**

```powershell
# 替换为你的虚拟机信息
$VM_IP = "10.211.55.11"
$VM_USER = "root"

# 复制公钥
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh ${VM_USER}@${VM_IP} "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# 第一次会要求输入密码
```

**方法 2: 手动复制**

```powershell
# 1. 查看公钥内容
Get-Content $env:USERPROFILE\.ssh\id_rsa.pub

# 2. 手动 SSH 到虚拟机
ssh root@10.211.55.11
# 输入密码

# 3. 在虚拟机上执行
mkdir -p ~/.ssh
echo "粘贴你的公钥内容" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

**方法 3: 使用 WinSCP 或 PuTTY**

使用图形界面工具更方便地管理 SSH 密钥。

#### 测试密钥认证

```powershell
# 应该不需要密码即可连接
ssh root@10.211.55.11 "echo 'Success'"
```

## 🚀 快速开始

### 1. 配置环境变量（可选）

创建 `.env.local` 文件：

```powershell
# 创建配置文件
@"
VM_IP=10.211.55.11
VM_USER=root
VM_PASSWORD=747599qw@
VM_PROJECT_DIR=/root/CloudCom
COMPOSE_FILE=docker-compose-opengauss-cluster-legacy.yml
"@ | Out-File -Encoding UTF8 .env.local
```

### 2. 启动虚拟机服务

```powershell
# 在项目根目录打开 PowerShell
.\start-vm.ps1
```

### 3. 停止虚拟机服务

```powershell
.\stop-vm.ps1
```

## 📝 PowerShell 脚本说明

### start-vm.ps1

**功能**：

- ✅ 检查虚拟机连接
- ✅ 同步配置文件
- ✅ 在本地构建 Docker 镜像
- ✅ 传输镜像到虚拟机
- ✅ 启动所有服务
- ✅ 健康检查

**执行时间**：首次约 10-15 分钟

### stop-vm.ps1

**功能**：

- ✅ 停止所有服务
- ✅ 保留数据卷

## 🔧 常见问题

### 问题 1: 无法运行 PowerShell 脚本

**错误**: `无法加载文件，因为在此系统上禁止运行脚本`

**解决**:

```powershell
# 以管理员身份运行 PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 或者临时允许
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### 问题 2: SSH 连接需要密码

**原因**: SSH 密钥未配置

**解决**: 按照上面的 "配置 SSH 密钥认证" 部分操作

### 问题 3: Docker 命令不可用

**原因**: Docker Desktop 未启动

**解决**:

1. 启动 Docker Desktop
2. 等待 Docker 图标变为绿色
3. 验证: `docker version`

### 问题 4: SCP 传输文件失败

**原因**: SSH 认证问题或路径错误

**解决**:

```powershell
# 测试 SCP
scp test.txt root@10.211.55.11:/tmp/

# 如果失败，检查 SSH 配置
ssh root@10.211.55.11 "ls -la ~/.ssh/authorized_keys"
```

### 问题 5: 镜像构建失败

**原因**: Docker 网络问题或资源不足

**解决**:

```powershell
# 检查 Docker Desktop 资源设置
# 设置 > Resources > Advanced
# 建议: CPU: 4核, Memory: 4GB

# 清理 Docker 缓存
docker system prune -a
```

## 🔍 调试技巧

### 查看详细输出

```powershell
# 启用详细日志
$VerbosePreference = "Continue"
.\start-vm.ps1
```

### 手动执行 SSH 命令

```powershell
# 连接到虚拟机
ssh root@10.211.55.11

# 查看服务状态
cd ~/CloudCom
docker-compose -f docker-compose-opengauss-cluster-legacy.yml ps

# 查看日志
docker-compose logs -f backend
```

### 测试网络连接

```powershell
# 测试 SSH 连接
Test-NetConnection -ComputerName 10.211.55.11 -Port 22

# 测试 HTTP 服务
Invoke-WebRequest -Uri http://10.211.55.11:8080 -UseBasicParsing
```

## 📊 PowerShell vs Bash 差异

| 功能     | Bash (Mac/Linux) | PowerShell (Windows)          |
| -------- | ---------------- | ----------------------------- |
| SSH 密码 | ✅ sshpass       | ❌ 需要密钥认证               |
| 颜色输出 | `\033[0;32m`     | `Write-Host -ForegroundColor` |
| 变量     | `$VAR`           | `$VAR`                        |
| 条件判断 | `if [ ]; then`   | `if () { }`                   |
| 命令替换 | `$(command)`     | `$(command)`                  |
| 文件测试 | `[ -f file ]`    | `Test-Path file`              |

## 🎯 高级用法

### 使用 PowerShell 配置文件

在 `$PROFILE` 中添加快捷函数：

```powershell
# 查看配置文件位置
$PROFILE

# 编辑配置文件
notepad $PROFILE

# 添加以下内容：
function Start-BlogVM {
    Set-Location "C:\path\to\CloudCom"
    .\start-vm.ps1
}

function Stop-BlogVM {
    Set-Location "C:\path\to\CloudCom"
    .\stop-vm.ps1
}
```

重新加载配置：

```powershell
. $PROFILE
```

然后可以在任何位置运行：

```powershell
Start-BlogVM
Stop-BlogVM
```

### 使用任务计划程序自动启动

```powershell
# 创建定时任务
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\path\to\CloudCom\start-vm.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "BlogVM-Start" -Action $action -Trigger $trigger -Description "启动 Blog 虚拟机服务"
```

## 🛠️ 替代工具

如果 PowerShell 脚本不适合你，可以考虑：

### Git Bash (推荐)

1. 安装 Git for Windows: https://git-scm.com/download/win
2. 使用 Git Bash 运行原始的 `.sh` 脚本
3. 需要安装 `sshpass`:
   ```bash
   # 在 Git Bash 中
   curl -L https://github.com/hudochenkov/sshpass/releases/download/1.06/sshpass-1.06.tar.gz -o sshpass.tar.gz
   tar xvzf sshpass.tar.gz
   cd sshpass-1.06
   ./configure
   make
   sudo make install
   ```

### WSL (Windows Subsystem for Linux)

1. 安装 WSL2
2. 在 Linux 环境中直接运行原始脚本
3. 完全兼容 bash 脚本

## 📞 获取帮助

如果遇到问题：

1. 检查 PowerShell 版本：`$PSVersionTable.PSVersion`（建议 5.1+）
2. 检查 SSH 配置：`ssh -v root@10.211.55.11`
3. 查看 Docker Desktop 日志
4. 检查防火墙设置

## ✅ 验证清单

部署前确认：

- [ ] OpenSSH 客户端已安装
- [ ] Docker Desktop 已安装并运行
- [ ] SSH 密钥已配置
- [ ] 可以无密码 SSH 到虚拟机
- [ ] PowerShell 执行策略已设置
- [ ] 虚拟机网络连接正常

---

**Windows 版本脚本已准备就绪！** 🎉

开始使用：`.\start-vm.ps1`
