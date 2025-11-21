# Blog Analytics - Spark 数据分析模块

本模块提供 Spark 作业，用于从 GaussDB 读取博客数据，执行统计分析，并将结果写回数据库。

## 功能

- 读取 `posts`、`comments`、`users` 表
- 统计用户发文数量
- 统计文章浏览次数
- 统计评论数量
- 将统计结果写入 `statistics` 表

## 前置条件

- Java 11+
- Maven 3.6+
- Spark 3.5.0+
- GaussDB/openGauss 数据库

## 本地构建

```bash
cd analytics
mvn clean package
```

生成的 JAR 文件：`target/blog-analytics-1.0.0-jar-with-dependencies.jar`

## 运行方式

### 方式 1：本地运行（需要 Spark 环境）

```bash
spark-submit \
  --class com.cloudcom.analytics.BlogAnalyticsJob \
  --master local[*] \
  target/blog-analytics-1.0.0-jar-with-dependencies.jar \
  jdbc:opengauss://localhost:5432/blog_db \
  bloguser \
  blogpass
```

### 方式 2：Spark Cluster 模式

```bash
spark-submit \
  --class com.cloudcom.analytics.BlogAnalyticsJob \
  --master spark://spark-master:7077 \
  --deploy-mode cluster \
  target/blog-analytics-1.0.0-jar-with-dependencies.jar \
  jdbc:opengauss://gaussdb:5432/blog_db \
  bloguser \
  blogpass
```

### 方式 3：Docker 容器运行

```bash
docker build -t blog-analytics:latest .

docker run \
  --network blogcircle-network \
  blog-analytics:latest \
  jdbc:opengauss://gaussdb:5432/blog_db \
  bloguser \
  blogpass
```

### 方式 4：通过 docker-compose 运行

```bash
docker-compose -f docker-compose-gaussdb.yml run --rm spark-analytics
```

## 参数说明

| 参数     | 说明             | 默认值                                    |
| -------- | ---------------- | ----------------------------------------- |
| JDBC URL | 数据库连接字符串 | `jdbc:opengauss://localhost:5432/blog_db` |
| Username | 数据库用户名     | `bloguser`                                |
| Password | 数据库密码       | `blogpass`                                |

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
