#Requires -Version 5.1

###############################################################
# Blog Circle 虚拟机启动脚本 - 可移植化版本
# 支持环境变量配置，提高跨环境兼容性
###############################################################

# 设置错误处理
$ErrorActionPreference = "Stop"

# 颜色函数
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error-Custom { Write-Host $args -ForegroundColor Red }
function Write-Blue { Write-Host $args -ForegroundColor Blue }

# ============================================
# 配置加载
# ============================================

function Load-Config {
    param([string]$ConfigFile)
    
    $config = @{}
    
    if (Test-Path $ConfigFile) {
        Get-Content $ConfigFile | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                $config[$name] = $value
            }
        }
        Write-Info "已加载配置文件: $ConfigFile"
    } else {
        Write-Warning "配置文件不存在: $ConfigFile"
    }
    
    return $config
}

# 加载配置
$config = Load-Config ".env.local"
$portableConfig = Load-Config ".env.opengauss"

# ============================================
# 环境变量配置（支持覆盖）
# ============================================

# 虚拟机配置
$VM_IP = $env:VM_IP ?? $config['VM_IP'] ?? $portableConfig['VM_IP'] ?? "10.211.55.11"
$VM_USER = $env:VM_USER ?? $config['VM_USER'] ?? $portableConfig['VM_USER'] ?? "root"
$VM_PASSWORD = $env:VM_PASSWORD ?? $config['VM_PASSWORD'] ?? $portableConfig['VM_PASSWORD'] ?? "747599qw@"
$VM_PROJECT_DIR = $env:VM_PROJECT_DIR ?? $config['VM_PROJECT_DIR'] ?? $portableConfig['VM_PROJECT_DIR'] ?? "/root/CloudCom"

# Compose 文件选择
$COMPOSE_FILE = $env:COMPOSE_FILE ?? $config['COMPOSE_FILE'] ?? "docker-compose-opengauss-cluster-portable.yml"
$ENV_FILE = $env:ENV_FILE ?? $config['ENV_FILE'] ?? ".env.opengauss"

# Docker 镜像配置
$OPENGAUSS_IMAGE = $env:OPENGAUSS_IMAGE ?? $portableConfig['OPENGAUSS_IMAGE'] ?? "enmotech/opengauss-lite:5.0.0"
$BACKEND_IMAGE_TAG = $env:BACKEND_IMAGE_TAG ?? $portableConfig['BACKEND_IMAGE_TAG'] ?? "vm"
$FRONTEND_IMAGE_TAG = $env:FRONTEND_IMAGE_TAG ?? $portableConfig['FRONTEND_IMAGE_TAG'] ?? "vm"

Write-Host ""
Write-Blue "================================"
Write-Blue "Blog Circle 虚拟机启动 (可移植化版本)"
Write-Blue "================================"
Write-Host ""

Write-Info "配置信息:"
Write-Host "  虚拟机 IP: $VM_IP"
Write-Host "  用户: $VM_USER"
Write-Host "  项目目录: $VM_PROJECT_DIR"
Write-Host "  Compose 文件: $COMPOSE_FILE"
Write-Host "  OpenGauss 镜像: $OPENGAUSS_IMAGE"
Write-Host ""

# ============================================
# 前置检查
# ============================================

Write-Blue "[1/9] 检查前置条件..."

# 检查 SSH
try {
    $null = Get-Command ssh -ErrorAction Stop
    Write-Success "SSH 客户端已安装"
} catch {
    Write-Error-Custom "SSH 客户端未安装"
    exit 1
}

# 检查 Docker
try {
    $null = docker version
    Write-Success "本地 Docker 已安装"
} catch {
    Write-Error-Custom "本地 Docker 未运行"
    Write-Host "请启动 Docker Desktop"
    exit 1
}

# 检查配置文件
if (-not (Test-Path $COMPOSE_FILE)) {
    Write-Error-Custom "Compose 文件不存在: $COMPOSE_FILE"
    exit 1
}
Write-Success "Compose 文件存在"

# ============================================
# SSH 命令函数
# ============================================

function Invoke-VMCommand {
    param([string]$Command)
    
    try {
        $result = ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=yes "${VM_USER}@${VM_IP}" "$Command" 2>&1
        return $result
    } catch {
        throw "SSH 命令执行失败: $_"
    }
}

# ============================================
# 虚拟机连接检查
# ============================================

Write-Host ""
Write-Blue "[2/9] 检查虚拟机连接..."

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
    Write-Warning "提示："
    Write-Host "  1. 检查虚拟机是否运行"
    Write-Host "  2. 检查 IP 地址是否正确"
    Write-Host "  3. 配置 SSH 密钥认证（推荐）："
    Write-Host "     ssh-keygen -t rsa"
    Write-Host "     type `$env:USERPROFILE\.ssh\id_rsa.pub | ssh ${VM_USER}@${VM_IP} 'cat >> ~/.ssh/authorized_keys'"
    exit 1
}

# ============================================
# 项目目录检查
# ============================================

Write-Host ""
Write-Blue "[3/9] 检查项目目录..."

$dirCheck = Invoke-VMCommand "[ -d ${VM_PROJECT_DIR} ] && echo 'exists'"
if ($dirCheck -match "exists") {
    Write-Success "项目目录存在"
} else {
    Write-Error-Custom "项目目录不存在: ${VM_PROJECT_DIR}"
    Write-Host "请先部署项目到虚拟机"
    exit 1
}

# ============================================
# 同步配置文件
# ============================================

Write-Host ""
Write-Blue "[4/9] 同步配置文件到虚拟机..."

try {
    # 同步 Compose 文件
    Write-Host "  • 同步 Docker Compose 配置..."
    scp -o StrictHostKeyChecking=no "$COMPOSE_FILE" "${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/"
    
    # 同步环境配置文件
    if (Test-Path $ENV_FILE) {
        Write-Host "  • 同步环境配置..."
        scp -o StrictHostKeyChecking=no "$ENV_FILE" "${VM_USER}@${VM_IP}:${VM_PROJECT_DIR}/"
    }
    
    # 同步脚本文件
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

# ============================================
# 构建本地镜像
# ============================================

Write-Host ""
Write-Blue "[5/9] 构建本地应用镜像..."

try {
    # 检查 Dockerfile
    if (-not (Test-Path "backend/Dockerfile")) {
        Write-Error-Custom "后端 Dockerfile 不存在"
        exit 1
    }
    
    if (-not (Test-Path "frontend/Dockerfile")) {
        Write-Error-Custom "前端 Dockerfile 不存在"
        exit 1
    }
    
    # 构建后端镜像
    Write-Host "  • 构建后端镜像..."
    docker build -t "blogcircle-backend:${BACKEND_IMAGE_TAG}" ./backend
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "后端镜像构建失败"
        exit 1
    }
    
    # 构建前端镜像
    Write-Host "  • 构建前端镜像..."
    docker build -t "blogcircle-frontend:${FRONTEND_IMAGE_TAG}" ./frontend
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "前端镜像构建失败"
        exit 1
    }
    
    Write-Success "应用镜像构建完成"
} catch {
    Write-Error-Custom "镜像构建失败: $_"
    exit 1
}

# ============================================
# 准备镜像传输
# ============================================

Write-Host ""
Write-Blue "[6/9] 准备镜像传输..."

$tempDir = Join-Path $env:TEMP "vm-images-$(Get-Random)"
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    # 导出 OpenGauss 镜像
    Write-Host "  • 导出 OpenGauss 镜像..."
    docker pull "$OPENGAUSS_IMAGE"
    docker save -o "$tempDir/opengauss.tar" "$OPENGAUSS_IMAGE"
    
    # 导出应用镜像
    Write-Host "  • 导出后端镜像..."
    docker save -o "$tempDir/backend.tar" "blogcircle-backend:${BACKEND_IMAGE_TAG}"
    
    Write-Host "  • 导出前端镜像..."
    docker save -o "$tempDir/frontend.tar" "blogcircle-frontend:${FRONTEND_IMAGE_TAG}"
    
    Write-Success "镜像导出完成"
} catch {
    Write-Error-Custom "镜像导出失败: $_"
    Remove-Item -Recurse -Force $tempDir
    exit 1
}

# ============================================
# 传输镜像到虚拟机
# ============================================

Write-Host ""
Write-Blue "[7/9] 传输镜像到虚拟机..."

try {
    Write-Host "  • 传输镜像文件..."
    scp -o StrictHostKeyChecking=no "$tempDir/*.tar" "${VM_USER}@${VM_IP}:/tmp/"
    
    Write-Host "  • 在虚拟机上加载镜像..."
    $loadCmd = "cd /tmp && docker load -i opengauss.tar && docker load -i backend.tar && docker load -i frontend.tar && rm -f *.tar"
    $null = Invoke-VMCommand $loadCmd
    
    Write-Success "镜像传输完成"
} catch {
    Write-Error-Custom "镜像传输失败: $_"
    exit 1
} finally {
    # 清理本地临时文件
    Remove-Item -Recurse -Force $tempDir
}

# ============================================
# 清理旧容器
# ============================================

Write-Host ""
Write-Blue "[8/9] 清理旧容器..."

$null = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} down 2>/dev/null || true"
$null = Invoke-VMCommand "docker rm -f blogcircle-backend blogcircle-frontend 2>/dev/null || true"
$null = Invoke-VMCommand "docker rm -f opengauss-primary opengauss-standby1 opengauss-standby2 2>/dev/null || true"

Write-Success "旧容器已清理"

# ============================================
# 启动服务
# ============================================

Write-Host ""
Write-Blue "[9/9] 启动服务..."

try {
    $composeCmd = "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE}"
    
    # 如果存在环境文件，添加到命令中
    if ($ENV_FILE) {
        $composeCmd += " --env-file ${ENV_FILE}"
    }
    
    $composeCmd += " up -d --remove-orphans"
    
    $null = Invoke-VMCommand $composeCmd
    
    Write-Success "服务已启动"
} catch {
    Write-Error-Custom "服务启动失败: $_"
    exit 1
}

# ============================================
# 等待服务就绪
# ============================================

Write-Host ""
Write-Warning "等待服务初始化..."
Write-Host "  • 等待数据库初始化... (30秒)"
Start-Sleep -Seconds 30

Write-Host "  • 等待后端服务启动... (30秒)"
Start-Sleep -Seconds 30

Write-Host "  • 等待前端服务就绪... (20秒)"
Start-Sleep -Seconds 20

# ============================================
# 验证部署
# ============================================

Write-Host ""
Write-Blue "服务状态"

$psOutput = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} ps"
Write-Host $psOutput

# ============================================
# 健康检查
# ============================================

Write-Host ""
Write-Blue "健康检查"

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

# ============================================
# 完成
# ============================================

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
Write-Host "  • 查看日志：" -NoNewline; Write-Info "ssh ${VM_USER}@${VM_IP} 'cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} logs -f'"
Write-Host "  • 停止服务：" -NoNewline; Write-Info "ssh ${VM_USER}@${VM_IP} 'cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} down'"
Write-Host "  • 重启服务：" -NoNewline; Write-Info "ssh ${VM_USER}@${VM_IP} 'cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} restart'"

Write-Host ""
