#Requires -Version 5.1

###############################################################
# Blog Circle 虚拟机停止脚本 (Windows PowerShell 版本)
###############################################################

$ErrorActionPreference = "Stop"

# 颜色函数
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
}

# 虚拟机配置
$VM_IP = if ($env:VM_IP) { $env:VM_IP } else { "10.211.55.11" }
$VM_USER = if ($env:VM_USER) { $env:VM_USER } else { "root" }
$VM_PROJECT_DIR = if ($env:VM_PROJECT_DIR) { $env:VM_PROJECT_DIR } else { "/root/CloudCom" }
$COMPOSE_FILE = if ($env:COMPOSE_FILE) { $env:COMPOSE_FILE } else { "docker-compose-opengauss-cluster-legacy.yml" }

Write-Host ""
Write-Info "================================"
Write-Info "Blog Circle 虚拟机停止"
Write-Info "================================"
Write-Host ""

# SSH 命令封装
function Invoke-VMCommand {
    param([string]$Command)
    $result = ssh -o StrictHostKeyChecking=no "${VM_USER}@${VM_IP}" "$Command" 2>&1
    return $result
}

# 检查连接
Write-Blue "[1/3] 检查虚拟机连接..."
try {
    $testResult = Invoke-VMCommand "echo 'Connected'"
    if ($testResult -match "Connected") {
        Write-Success "✓ 虚拟机连接正常"
    } else {
        throw "连接失败"
    }
} catch {
    Write-Error-Custom "✗ 无法连接到虚拟机 ${VM_IP}"
    exit 1
}

# 检查服务状态
Write-Host ""
Write-Blue "[2/3] 检查服务状态..."
$psOutput = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} ps 2>/dev/null || echo 'No services running'"
Write-Host $psOutput

# 停止服务
Write-Host ""
Write-Blue "[3/3] 停止服务..."
Write-Host "  • 停止前端服务..."
$null = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} stop frontend 2>/dev/null || true"

Write-Host "  • 停止后端服务..."
$null = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} stop backend 2>/dev/null || true"

Write-Host "  • 停止数据库集群..."
$null = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} stop opengauss-standby2 2>/dev/null || true"
$null = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} stop opengauss-standby1 2>/dev/null || true"
$null = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} stop opengauss-primary 2>/dev/null || true"

Write-Host "  • 清理容器..."
$null = Invoke-VMCommand "cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} rm -f 2>/dev/null || true"

Write-Host ""
Write-Success "================================"
Write-Success "虚拟机服务已停止"
Write-Success "================================"
Write-Host ""
Write-Host "提示：" -ForegroundColor White
Write-Host "  • 数据已保留在虚拟机的 Docker volumes 中"
Write-Host "  • 重新启动：" -NoNewline; Write-Info ".\start-vm.ps1"
Write-Host "  • 查看数据卷：" -NoNewline; Write-Info "ssh ${VM_USER}@${VM_IP} 'docker volume ls'"
Write-Host ""
Write-Host "完全清理（删除所有数据）：" -ForegroundColor Yellow
Write-Info "  ssh ${VM_USER}@${VM_IP} 'cd ${VM_PROJECT_DIR} && docker-compose -f ${COMPOSE_FILE} down -v'"
Write-Host ""
