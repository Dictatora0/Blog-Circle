#Requires -Version 5.1

###############################################################
# Blog Circle 虚拟机启动脚本 (Windows PowerShell 版本)
###############################################################

# 设置错误处理
$ErrorActionPreference = "Stop"

# 颜色函数
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error-Custom { Write-Host $args -ForegroundColor Red }
function Write-Blue { Write-Host $args -ForegroundColor Blue }

# 加载环境变量配置
if (Test-Path ".env.local") {
    Get-Content ".env.local" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
    Write-Info "已加载 .env.local 配置"
} else {
    Write-Info "未找到 .env.local，使用默认配置"
}

# 虚拟机配置（支持环境变量覆盖）
$VM_IP = if ($env:VM_IP) { $env:VM_IP } else { "10.211.55.11" }
$VM_USER = if ($env:VM_USER) { $env:VM_USER } else { "root" }
$VM_PASSWORD = if ($env:VM_PASSWORD) { $env:VM_PASSWORD } else { "747599qw@" }
$VM_PROJECT_DIR = if ($env:VM_PROJECT_DIR) { $env:VM_PROJECT_DIR } else { "/root/CloudCom" }
$COMPOSE_FILE = if ($env:COMPOSE_FILE) { $env:COMPOSE_FILE } else { "docker-compose-opengauss-cluster-legacy.yml" }

Write-Host ""
Write-Info "================================"
Write-Info "Blog Circle 虚拟机启动"
Write-Info "VM System Startup"
Write-Info "================================"
Write-Host ""

# 检查 SSH
try {
    $null = Get-Command ssh -ErrorAction Stop
    Write-Success "SSH 客户端已安装"
} catch {
    Write-Error-Custom "SSH 客户端未安装"
    exit 1
}

# SSH 命令封装函数
function Invoke-VMCommand {
    param([string]$Command)
    
    # 使用 plink（PuTTY）或原生 SSH
    # 方法1: 使用 SSH 密钥（推荐）
    # ssh ${VM_USER}@${VM_IP} "$Command"
    
    # 方法2: 使用 Pexpect-like 方式（需要额外工具）
    # 方法3: 使用 SSH 密钥文件
    
    # 使用 SSH 调用
    $result = ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=yes "${VM_USER}@${VM_IP}" "$Command" 2>&1
    return $result
}

# 检查虚拟机连接
Write-Blue "[1/8] 检查虚拟机连接..."
try {
    $testResult = Invoke-VMCommand "echo 'Connected'"
    if ($testResult -match "Connected") {
        Write-Success "虚拟机连接正常"
    } else {
        throw "连接测试失败"
    }
} catch {
    Write-Error-Custom "无法连接到虚拟机 ${VM_IP}"
    Write-Host ""
    Write-Warning "提示：Windows SSH 不支持命令行密码输入"
    Write-Host "配置 SSH 密钥认证："
    Write-Host "  1. 生成密钥: ssh-keygen -t rsa"
    Write-Host "  2. 复制公钥到虚拟机: type `$env:USERPROFILE\.ssh\id_rsa.pub | ssh ${VM_USER}@${VM_IP} 'cat >> ~/.ssh/authorized_keys'"
    Write-Host "  3. 或使用 PuTTY/WinSCP 等工具"
    exit 1
}

# 检查项目目录
Write-Host ""
Write-Blue "[2/8] 检查项目目录..."
$dirCheck = Invoke-VMCommand "[ -d ${VM_PROJECT_DIR} ] && echo 'exists'"
if ($dirCheck -match "exists") {
    Write-Success "项目目录存在"
} else {
    Write-Error-Custom "项目目录不存在: ${VM_PROJECT_DIR}"
    Write-Host "请先部署项目到虚拟机"
    exit 1
}

# 同步配置文件
Write-Host ""
Write-Blue "[3/8] 同步配置文件到虚拟机..."
Write-Host "  • 同步 Docker Compose 配置..."

try {
    scp -o StrictHostKeyChecking=no "docker-compose-opengauss-cluster-legacy.yml" "${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/"
    
    Write-Host "  • 同步脚本文件..."
    $null = Invoke-VMCommand "mkdir -p ${VM_PROJECT_DIR}/scripts"
    
    if (Test-Path "scripts/full_verify.sh") {
        scp -o StrictHostKeyChecking=no "scripts/full_verify.sh" "${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/scripts/"
        $null = Invoke-VMCommand "chmod +x ${VM_PROJECT_DIR}/scripts/full_verify.sh"
    }
    
    Write-Success "配置文件同步完成"
} catch {
    Write-Error-Custom "文件同步失败: $_"
    exit 1
}

# 检查 Docker
Write-Host ""
Write-Blue "[4/8] 检查 Docker 环境..."
try {
    $null = Get-Command docker -ErrorAction Stop
    $dockerVersion = Invoke-VMCommand "docker --version"
    Write-Success "Docker 已安装"
    Write-Host "  VM Docker: $dockerVersion"
} catch {
    Write-Error-Custom "Docker 未安装"
    exit 1
}

# 停止已有服务并清理
Write-Host ""
Write-Blue "[5/8] 停止已有服务并清理旧容器..."
$null = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} down 2>/dev/null || true"
$null = Invoke-VMCommand "docker rm -f blogcircle-backend blogcircle-frontend 2>/dev/null || true"
$null = Invoke-VMCommand "docker rm -f opengauss-primary opengauss-standby1 opengauss-standby2 2>/dev/null || true"
$null = Invoke-VMCommand "docker rm -f gaussdb-primary gaussdb-standby1 gaussdb-standby2 2>/dev/null || true"
Write-Success "已清理旧容器"

# 在本地构建并准备所有镜像
Write-Host ""
Write-Blue "[6/8] 在本地构建应用镜像..."

# 检查 Docker Desktop
try {
    $null = docker version
} catch {
    Write-Error-Custom "本地 Docker 未运行"
    Write-Host "请启动 Docker Desktop"
    exit 1
}

# 检查并拉取基础镜像
Write-Host "  • 检查基础镜像..."
$baseImages = @(
    "maven:3.8.7-eclipse-temurin-17",
    "eclipse-temurin:17-jre",
    "node:18-alpine",
    "nginx:alpine"
)

foreach ($img in $baseImages) {
    $imgName = $img.Split(':')[0]
    $existing = docker images --format "{{.Repository}}" | Where-Object { $_ -eq $imgName }
    if (-not $existing) {
        Write-Host "    拉取 $img..."
        docker pull $img
    }
}

# 构建后端镜像
Write-Host "  • 构建后端镜像..."
docker build -t blogcircle-backend:vm ./backend
if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "后端镜像构建失败"
    exit 1
}

# 构建前端镜像
Write-Host "  • 构建前端镜像..."
docker build -t blogcircle-frontend:vm ./frontend
if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "前端镜像构建失败"
    exit 1
}

Write-Success "应用镜像构建完成"

# 传输镜像到虚拟机
Write-Host ""
Write-Blue "[7/8] 传输镜像到虚拟机..."

$tempDir = Join-Path $env:TEMP "vm-images"
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

Write-Host "  • 导出 openGauss 镜像..."
docker save -o "$tempDir/opengauss.tar" enmotech/opengauss-lite:latest

Write-Host "  • 导出后端镜像..."
docker save -o "$tempDir/backend.tar" blogcircle-backend:vm

Write-Host "  • 导出前端镜像..."
docker save -o "$tempDir/frontend.tar" blogcircle-frontend:vm

Write-Host "  • 传输镜像到虚拟机..."
scp -o StrictHostKeyChecking=no "$tempDir/*.tar" "${VM_USER}@${VM_IP}:/tmp/"

Write-Host "  • 在虚拟机上加载镜像..."
$loadCmd = "cd /tmp && docker load -i opengauss.tar && docker load -i backend.tar && docker load -i frontend.tar && rm -f *.tar"
$null = Invoke-VMCommand $loadCmd

# 清理本地临时文件
Remove-Item -Recurse -Force $tempDir

Write-Success "镜像传输完成"

# 启动服务
Write-Host ""
Write-Blue "[8/8] 启动服务..."
Write-Host "  • 启动 openGauss 三实例集群..."
Write-Host "  • 启动后端服务（使用预构建镜像）..."
Write-Host "  • 启动前端服务（使用预构建镜像）..."

$null = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} up -d --remove-orphans"

# 等待服务就绪
Write-Host ""
Write-Warning "等待服务就绪..."
Write-Host "  • 等待数据库初始化..."
Start-Sleep -Seconds 30
Write-Host "  • 等待后端服务启动..."
Start-Sleep -Seconds 30
Write-Host "  • 等待前端服务就绪..."
Start-Sleep -Seconds 20

# 检查服务状态
Write-Host ""
Write-Warning "服务状态"
$psOutput = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} ps"
Write-Host $psOutput

# 检查健康状态
Write-Host ""
Write-Warning "健康检查"

Write-Host -NoNewline "  • openGauss 主库: "
$dbCheck = Invoke-VMCommand "docker exec opengauss-primary su - omm -c '/usr/local/opengauss/bin/gsql -d postgres -c `"SELECT 1`"' 2>&1"
if ($dbCheck -match "1 row") {
    Write-Success "健康"
} else {
    Write-Warning "未就绪"
}

Write-Host -NoNewline "  • 后端服务: "
$beCheck = Invoke-VMCommand "curl -sf http://localhost:8082/actuator/health 2>&1"
if ($beCheck -match "UP") {
    Write-Success "健康"
} else {
    Write-Warning "未就绪（可能仍在初始化）"
}

Write-Host -NoNewline "  • 前端服务: "
$feCheck = Invoke-VMCommand "curl -sf http://localhost:8080 2>&1"
if ($feCheck -match "html" -or $feCheck -match "200") {
    Write-Success "健康"
} else {
    Write-Warning "未就绪"
}

# 完成
Write-Host ""
Write-Success "================================"
Write-Success "虚拟机服务启动完成"
Write-Success "================================"
Write-Host ""
Write-Host "访问地址：" -ForegroundColor White
Write-Info "  • 前端：http://${VM_IP}:8080"
Write-Info "  • 后端：http://${VM_IP}:8082"
Write-Info "  • 健康检查：http://${VM_IP}:8082/actuator/health"
Write-Host ""
Write-Host "数据库连接：" -ForegroundColor White
Write-Info "  • 主库：${VM_IP}:5432"
Write-Info "  • 备库1：${VM_IP}:5434"
Write-Info "  • 备库2：${VM_IP}:5436"
Write-Host ""
Write-Host "常用命令：" -ForegroundColor White
Write-Host "  • 停止服务：" -NoNewline; Write-Info "./stop-vm.ps1"
Write-Host "  • 查看日志：" -NoNewline; Write-Info "ssh ${VM_USER}@${VM_IP} 'cd ${VM_PROJECT_DIR} && docker-compose logs -f'"
Write-Host ""
