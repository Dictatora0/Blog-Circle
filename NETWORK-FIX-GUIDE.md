# Docker 网络问题解决指南

## 🔍 问题诊断

从错误信息 `Get "https://registry-1.docker.io/v2/": context deadline exceeded` 可以看出，虚拟机无法连接到 Docker Hub。

## 🛠️ 解决方案

### 方案 1: 配置 Docker 镜像源（推荐）

#### 步骤 1: 上传修复脚本

```bash
# 在 Mac 上执行
rsync -avz fix-docker-network.sh root@10.211.55.11:~/CloudCom/
rsync -avz deploy-on-vm.sh root@10.211.55.11:~/CloudCom/
```

#### 步骤 2: 在虚拟机上执行修复

```bash
# SSH 到虚拟机
ssh root@10.211.55.11

# 进入项目目录
cd ~/CloudCom

# 添加执行权限
chmod +x fix-docker-network.sh

# 运行修复脚本
./fix-docker-network.sh
```

#### 步骤 3: 测试网络

```bash
# 测试拉取镜像
docker pull enmotech/opengauss-lite:latest
docker pull maven:3.8.7-eclipse-temurin-17
docker pull node:18-alpine
```

#### 步骤 4: 重新部署

```bash
./deploy-on-vm.sh
```

### 方案 2: 手动配置 Docker 镜像源

如果自动脚本失败，可以手动配置：

```bash
# 1. 编辑 Docker 配置
sudo mkdir -p /etc/docker
sudo vi /etc/docker/daemon.json
```

添加以下内容：

```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com"
  ],
  "max-concurrent-downloads": 10
}
```

```bash
# 2. 重启 Docker 服务
sudo systemctl daemon-reload
sudo systemctl restart docker

# 3. 验证配置
sudo systemctl status docker
docker info | grep -A 5 "Registry Mirrors"
```

### 方案 3: 检查防火墙

```bash
# 检查防火墙状态
systemctl status firewalld

# 临时关闭防火墙测试（谨慎使用）
systemctl stop firewalld

# 或者添加规则允许 Docker
firewall-cmd --permanent --zone=public --add-masquerade
firewall-cmd --reload
```

### 方案 4: 使用代理

如果有 HTTP 代理可用：

```bash
# 创建 Docker 代理配置
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo vi /etc/systemd/system/docker.service.d/http-proxy.conf
```

添加：

```ini
[Service]
Environment="HTTP_PROXY=http://your-proxy:port"
Environment="HTTPS_PROXY=http://your-proxy:port"
Environment="NO_PROXY=localhost,127.0.0.1"
```

```bash
# 重启 Docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 方案 5: 离线部署（最可靠）

如果网络问题无法解决，可以使用离线镜像：

#### 在有网络的机器上导出镜像

```bash
# 拉取所需镜像
docker pull enmotech/opengauss-lite:latest
docker pull maven:3.8.7-eclipse-temurin-17
docker pull node:18-alpine

# 导出镜像
docker save enmotech/opengauss-lite:latest -o opengauss.tar
docker save maven:3.8.7-eclipse-temurin-17 -o maven.tar
docker save node:18-alpine -o node.tar
```

#### 上传到虚拟机并导入

```bash
# 在 Mac 上上传
scp opengauss.tar maven.tar node.tar root@10.211.55.11:~/

# 在虚拟机上导入
ssh root@10.211.55.11
docker load -i ~/opengauss.tar
docker load -i ~/maven.tar
docker load -i ~/node.tar

# 验证
docker images
```

## 🔄 修复后的部署流程

修复后的 `deploy-on-vm.sh` 脚本包含以下改进：

1. **网络检查**: 在构建前检查 Docker 配置和网络连接
2. **正确的错误检测**: 使用 `PIPESTATUS` 正确捕获构建失败
3. **清晰的错误提示**: 构建失败时显示退出码和提示信息
4. **自动重试**: 可以配置镜像源后自动重试

## 📝 常见错误和解决方法

### 错误 1: `context deadline exceeded`

**原因**: 网络超时，无法连接到 Docker Hub

**解决**: 使用方案 1 配置镜像源

### 错误 2: `connection refused`

**原因**: Docker 服务未运行

**解决**:

```bash
systemctl start docker
systemctl enable docker
```

### 错误 3: 镜像拉取成功但构建失败

**原因**: 基础镜像版本不兼容

**解决**: 检查 Dockerfile 中的基础镜像版本

## 🧪 验证步骤

### 1. 验证 Docker 配置

```bash
# 查看配置
cat /etc/docker/daemon.json

# 查看 Docker 信息
docker info | grep -A 5 "Registry Mirrors"
```

### 2. 验证网络连接

```bash
# 测试 Docker Hub
curl -I https://registry-1.docker.io

# 测试镜像源
curl -I https://docker.mirrors.ustc.edu.cn
```

### 3. 验证镜像拉取

```bash
# 拉取测试镜像
docker pull hello-world

# 查看已有镜像
docker images
```

## 🎯 成功标志

修复成功后，运行 `./deploy-on-vm.sh` 应该看到：

```
检查 Docker 配置...
  ✓ Docker 镜像源配置存在
测试网络连接...
  ✓ 国内镜像源连接正常

[4/7] 构建后端镜像...
  • 构建 Java 应用（这可能需要几分钟）...
    Step 1/14 : FROM maven:3.8.7-eclipse-temurin-17 AS builder
    ...
    Successfully built xxx
    Successfully tagged blogcircle-backend:vm
后端镜像构建成功

[5/7] 构建前端镜像...
  • 构建 Vue 应用（这可能需要几分钟）...
    Step 1/13 : FROM node:18-alpine AS builder
    ...
    Successfully built xxx
    Successfully tagged blogcircle-frontend:vm
前端镜像构建成功
```

## 📞 仍然有问题？

如果上述方法都无法解决：

1. 检查虚拟机的网络配置
2. 检查 DNS 设置: `cat /etc/resolv.conf`
3. 尝试更换 DNS: `echo "nameserver 8.8.8.8" >> /etc/resolv.conf`
4. 联系网络管理员检查防火墙规则
5. 考虑使用完全离线的部署方案

---

**下一步**: 修复网络后运行 `./deploy-on-vm.sh` 进行部署
