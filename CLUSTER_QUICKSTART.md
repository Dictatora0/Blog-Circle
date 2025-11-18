# GaussDB 集群快速启动指南

## 集群架构

- **主节点**: 10.211.55.11 (读写)
- **备节点 1**: 10.211.55.14 (只读)
- **备节点 2**: 10.211.55.13 (只读)

## 快速部署

### 1. 一键部署（推荐）

```bash
chmod +x deploy-cluster.sh
./deploy-cluster.sh
```

### 2. 手动部署

```bash
# 加载环境变量
source .env.cluster

# 启动容器
docker compose -f docker-compose-gaussdb-cluster.yml up -d

# 查看状态
docker compose -f docker-compose-gaussdb-cluster.yml ps

# 查看日志
docker compose -f docker-compose-gaussdb-cluster.yml logs -f backend
```

## 访问地址

- 前端: http://10.211.55.11:8080
- 后端: http://10.211.55.11:8081
- Spark UI: http://10.211.55.11:8888

## 运行 Spark 分析

```bash
cd analytics
mvn clean package

spark-submit \
  --class com.cloudcom.analytics.BlogAnalyticsClusterJob \
  --master spark://10.211.55.11:7077 \
  target/blog-analytics-1.0.0-jar-with-dependencies.jar
```

## 测试集群

```bash
cd tests
chmod +x run-all-tests.sh
./run-all-tests.sh
```

## 故障切换

如果主节点故障，系统会自动切换到备节点读取数据。写操作需要等待主节点恢复或手动提升备节点为主节点。

## 停止服务

```bash
docker compose -f docker-compose-gaussdb-cluster.yml down
```
