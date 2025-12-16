# Blog Analytics - Spark 数据分析模块

本模块提供 Spark 作业，用于从 openGauss 容器化集群读取博客数据，执行统计分析，并将结果写回数据库。

⚠️ **注意**: 后端已集成内嵌式 Spark（local[*] 模式）+ SQL 降级方案，此独立模块仅作为参考实现。

## 功能

- 读取 `posts`、`comments`、`users` 表
- 统计用户发文数量
- 统计文章浏览次数
- 统计评论数量
- 将统计结果写入 `statistics` 表

## 架构说明

### 当前部署架构（单虚拟机容器化）

- **虚拟机**: 10.211.55.11
- **主库**: 10.211.55.11:5432
- **备库 1**: 10.211.55.11:5434
- **备库 2**: 10.211.55.11:5436
- **数据库**: blog_db
- **用户**: bloguser / Blog@2025

所有 openGauss 实例运行在同一虚拟机的 Docker 容器中。

## 前置条件

- Java 11+
- Maven 3.6+
- Spark 3.5.0+
- openGauss 容器化集群（已通过 docker-compose 部署）

## 本地构建

```bash
cd analytics
mvn clean package
```

生成的 JAR 文件：`target/blog-analytics-1.0.0-jar-with-dependencies.jar`

## 运行方式

### 方式 1：连接虚拟机容器化集群

```bash
# 使用集群配置类（推荐）
spark-submit \
  --class com.cloudcom.analytics.BlogAnalyticsClusterJob \
  --master local[*] \
  --conf spark.driver.memory=1g \
  --conf spark.executor.memory=1g \
  target/blog-analytics-1.0.0-jar-with-dependencies.jar
```

环境变量配置：

```bash
export GAUSSDB_HOST=10.211.55.11
export GAUSSDB_PRIMARY_PORT=5432
export GAUSSDB_STANDBY1_PORT=5434
export GAUSSDB_STANDBY2_PORT=5436
export GAUSSDB_DATABASE=blog_db
export GAUSSDB_USERNAME=bloguser
export GAUSSDB_PASSWORD=Blog@2025
```

### 方式 2：直接指定 JDBC URL

```bash
spark-submit \
  --class com.cloudcom.analytics.BlogAnalyticsJob \
  --master local[*] \
  target/blog-analytics-1.0.0-jar-with-dependencies.jar \
  jdbc:postgresql://10.211.55.11:5432/blog_db \
  bloguser \
  Blog@2025
```

### 方式 3：Docker 容器运行（需访问虚拟机）

```bash
docker build -t blog-analytics:latest .

docker run \
  -e GAUSSDB_HOST=10.211.55.11 \
  -e GAUSSDB_PASSWORD=Blog@2025 \
  blog-analytics:latest
```

## 配置说明

### 集群配置（GaussDBClusterConfig）

| 环境变量                | 说明        | 默认值       |
| ----------------------- | ----------- | ------------ |
| `GAUSSDB_HOST`          | 虚拟机 IP   | 10.211.55.11 |
| `GAUSSDB_PRIMARY_PORT`  | 主库端口    | 5432         |
| `GAUSSDB_STANDBY1_PORT` | 备库 1 端口 | 5434         |
| `GAUSSDB_STANDBY2_PORT` | 备库 2 端口 | 5436         |
| `GAUSSDB_DATABASE`      | 数据库名    | blog_db      |
| `GAUSSDB_USERNAME`      | 用户名      | bloguser     |
| `GAUSSDB_PASSWORD`      | 密码        | Blog@2025    |

## 输出示例

```
启动 Spark 分析任务
JDBC URL: jdbc:opengauss://gaussdb:5432/blog_db
读取 posts 表...
+----+-----+-------+---------+----------+----------+
| id |title|content|author_id|view_count|created_at|
+----+-----+-------+---------+----------+----------+
|  1 | ... |  ...  |    1    |    10    |   ...    |
+----+-----+-------+---------+----------+----------+

统计用户发文数量...
+---------+----------+
|author_id|post_count|
+---------+----------+
|    1    |    5     |
|    2    |    3     |
+---------+----------+

写回统计结果到 statistics 表...
分析任务完成
```

## 故障排查

### 连接超时

确保 GaussDB 服务已启动，且网络连接正常：

```bash
# 测试连接
gsql -h gaussdb -p 5432 -U bloguser -d blog_db
```

### 权限错误

检查数据库用户权限：

```sql
-- 在 GaussDB 中执行
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO bloguser;
```

### Spark 内存不足

增加 Spark 内存配置：

```bash
spark-submit \
  --driver-memory 2g \
  --executor-memory 2g \
  ...
```

## 与后端集成

后端服务可通过以下方式触发 Spark 分析：

1. **HTTP 接口**：调用 `POST /api/stats/analyze`
2. **定时任务**：配置 Spring Scheduler 定期运行
3. **手动触发**：通过 CLI 或 Spark UI 提交任务

## 扩展

可根据需求扩展分析功能：

- 添加更多统计维度（如用户活跃度、内容热度等）
- 集成机器学习模型（推荐、分类等）
- 导出分析结果到外部系统（BI 工具、数据仓库等）

## 许可证

MIT
