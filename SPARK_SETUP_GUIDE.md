# Spark 镜像拉取问题解决指南

如果遇到 Spark 镜像拉取失败的错误，请按照本指南解决。

## 问题症状

```
Error failed to resolve reference "docker.io/bitnami/spark:3.5.0"
或
Error failed to resolve reference "docker.io/apache/spark:3.5.0"
```

## 解决方案

### 方案 1：配置 Docker 镜像源（推荐）

编辑 Docker 配置文件 `/etc/docker/daemon.json`（Linux）或 Docker Desktop 设置（Mac/Windows）：

**Linux**

```bash
sudo nano /etc/docker/daemon.json
```

添加以下内容：

```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com",
    "https://registry.docker-cn.com"
  ]
}
```

保存后重启 Docker：

```bash
sudo systemctl restart docker
```

**macOS**

1. 打开 Docker Desktop
2. 点击菜单栏 Docker 图标 → Preferences
3. 选择 Docker Engine
4. 在 JSON 中添加上述 `registry-mirrors` 配置
5. 点击 Apply & Restart

**Windows**

1. 打开 Docker Desktop
2. 点击设置 → Docker Engine
3. 在 JSON 中添加上述 `registry-mirrors` 配置
4. 点击 Apply & Restart

### 方案 2：手动拉取镜像

如果配置镜像源后仍然失败，可以手动拉取镜像：

```bash
# 拉取 Spark 镜像
docker pull apache/spark:3.5.0

# 验证镜像
docker images | grep spark
```

然后重新启动 docker-compose：

```bash
docker-compose -f docker-compose-gaussdb.yml up -d
```

### 方案 3：跳过 Spark 服务

如果暂时不需要 Spark 功能，可以只启动其他服务：

```bash
# 启动 GaussDB 和后端（不启动 Spark）
docker-compose -f docker-compose-gaussdb.yml up -d gaussdb backend frontend

# 或使用标准 PostgreSQL 栈
docker-compose up -d
```

### 方案 4：使用本地 Spark

如果 Docker 镜像无法拉取，可以在本地运行 Spark：

```bash
# 1. 安装 Spark（如果未安装）
# macOS
brew install apache-spark

# Linux
# 从 https://spark.apache.org/downloads.html 下载

# 2. 构建分析模块
cd analytics
mvn clean package

# 3. 运行 Spark 任务
spark-submit \
  --class com.cloudcom.analytics.BlogAnalyticsJob \
  --master local[*] \
  target/blog-analytics-1.0.0-jar-with-dependencies.jar \
  jdbc:opengauss://localhost:5432/blog_db \
  bloguser \
  blogpass
```

## 网络诊断

### 检查 Docker 网络连接

```bash
# 测试 Docker Hub 连接
docker pull hello-world

# 如果失败，检查 DNS
docker run --rm alpine nslookup docker.io

# 检查代理设置
docker info | grep -i proxy
```

### 检查本地网络

```bash
# 测试网络连接
ping docker.io

# 测试 DNS 解析
nslookup docker.io

# 测试 HTTP 连接
curl -I https://docker.io
```

## 使用国内镜像源

如果在中国大陆，推荐使用以下镜像源：

```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com",
    "https://registry.aliyuncs.com"
  ]
}
```

## 常见问题

### Q: 配置镜像源后仍然无法拉取

**A**:

1. 确保 Docker 已重启
2. 尝试清理 Docker 缓存：`docker system prune -a`
3. 尝试手动拉取：`docker pull apache/spark:3.5.0`
4. 检查网络连接和防火墙设置

### Q: 拉取速度很慢

**A**:

1. 更换镜像源
2. 增加 Docker 下载超时时间
3. 使用代理（如果可用）

### Q: 镜像拉取成功但容器启动失败

**A**:

1. 检查容器日志：`docker logs blogcircle-spark-master`
2. 检查端口是否被占用：`lsof -i :8888`
3. 检查内存是否充足：`docker stats`

## 完全跳过 Spark 的方案

如果不需要 Spark 功能，可以使用简化的部署：

```bash
# 使用标准 PostgreSQL 栈（无 Spark）
docker-compose up -d

# 或仅启动 GaussDB 栈（无 Spark）
docker-compose -f docker-compose-gaussdb.yml up -d gaussdb backend frontend
```

此时系统仍然可以通过 SQL 进行数据分析，只是无法使用 Spark 的分布式处理能力。

## 后续步骤

一旦 Spark 镜像成功拉取，可以：

1. **查看 Spark UI**：http://localhost:8888
2. **运行分析任务**：
   ```bash
   curl -X POST http://localhost:8080/api/stats/analyze \
     -H "Authorization: Bearer <token>"
   ```
3. **查看统计结果**：
   ```bash
   curl http://localhost:8080/api/stats \
     -H "Authorization: Bearer <token>"
   ```

## 获取帮助

如果问题仍未解决，请：

1. 查看 `DEPLOYMENT_GUIDE.md` 的故障排查部分
2. 查看 Docker 官方文档：https://docs.docker.com/
3. 查看 Spark 官方文档：https://spark.apache.org/docs/latest/
4. 检查项目 Issue 和讨论
