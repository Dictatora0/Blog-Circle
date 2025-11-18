# GaussDB 一主二备集群配置总结

## 已生成的配置文件清单

### 1. 后端配置

| 文件                                                                   | 用途                 |
| ---------------------------------------------------------------------- | -------------------- |
| `backend/src/main/resources/application-gaussdb-cluster.yml`           | 主备数据源配置       |
| `backend/src/main/java/com/cloudcom/blog/config/DataSourceConfig.java` | 读写分离数据源配置类 |
| `backend/src/main/java/com/cloudcom/blog/annotation/ReadOnly.java`     | 只读注解             |
| `backend/src/main/java/com/cloudcom/blog/aspect/DataSourceAspect.java` | 数据源切换切面       |

### 2. Spark 配置

| 文件                                                                          | 用途                       |
| ----------------------------------------------------------------------------- | -------------------------- |
| `analytics/src/main/java/com/cloudcom/analytics/GaussDBClusterConfig.java`    | Spark 集群连接配置         |
| `analytics/src/main/java/com/cloudcom/analytics/BlogAnalyticsClusterJob.java` | Spark 分析任务（集群模式） |

### 3. 部署配置

| 文件                                 | 用途                    |
| ------------------------------------ | ----------------------- |
| `docker-compose-gaussdb-cluster.yml` | Docker Compose 集群模式 |
| `deploy-cluster.sh`                  | 一键部署脚本            |
| `.env.cluster`                       | 环境变量配置            |
| `CLUSTER_QUICKSTART.md`              | 快速启动指南            |

### 4. 测试脚本

| 文件                            | 用途           |
| ------------------------------- | -------------- |
| `tests/automated-test-suite.sh` | 系统自动化测试 |
| `tests/api-test-suite.sh`       | API 完整测试   |
| `tests/database-test-suite.sh`  | 数据库测试     |
| `tests/run-all-tests.sh`        | 运行所有测试   |

## 使用方式

### 方式 1：一键部署（推荐）

```bash
chmod +x deploy-cluster.sh
./deploy-cluster.sh
```

### 方式 2：Docker Compose

```bash
source .env.cluster
docker compose -f docker-compose-gaussdb-cluster.yml up -d
```

### 方式 3：手动配置

```bash
# 设置 Spring Profile
export SPRING_PROFILES_ACTIVE=gaussdb-cluster

# 启动后端
cd backend
mvn spring-boot:run

# 启动前端
cd frontend
npm run dev
```

## 读写分离使用

### 在 Service 层使用 @ReadOnly 注解

```java
@Service
public class PostService {

    // 写操作（使用主库）
    public Post createPost(Post post) {
        return postMapper.insert(post);
    }

    // 读操作（使用备库）
    @ReadOnly
    public List<Post> getAllPosts() {
        return postMapper.selectAll();
    }

    // 读操作（使用备库）
    @ReadOnly
    public Post getPostById(Long id) {
        return postMapper.selectById(id);
    }
}
```

## Spark 访问集群

```java
// 从备库读取（读操作）
Dataset<Row> posts = GaussDBClusterConfig.readFromReplica(spark, "posts");

// 写入主库（写操作）
GaussDBClusterConfig.writeToPrimary(statsData, "statistics", "append");
```

## 连接串格式

### 主库（写操作）

```
jdbc:opengauss://10.211.55.11:5432/blog_db
```

### 备库（读操作，负载均衡）

```
jdbc:opengauss://10.211.55.14:5432,10.211.55.13:5432/blog_db?targetServerType=slave&loadBalanceHosts=true
```

## 网络模式

- **后端容器**: 使用 `host` 网络模式，直接访问物理机上的 GaussDB
- **前端容器**: 使用 `bridge` 网络模式
- **Spark 容器**: 使用 `host` 网络模式

## 故障切换

系统自动支持读操作故障切换：

- 如果备节点 1 故障，自动切换到备节点 2
- 如果主节点故障，读操作继续使用备节点，写操作需要等待主节点恢复

## 性能优化

1. **连接池配置**

   - 主库：10 个连接
   - 备库：20 个连接（读操作更多）

2. **读写分离**

   - 所有查询操作使用 `@ReadOnly` 注解
   - 减轻主库压力

3. **负载均衡**
   - 备库使用 `loadBalanceHosts=true` 参数
   - 自动在两个备节点间负载均衡

## 监控检查

```bash
# 检查集群状态
./check_gaussdb_cluster.sh

# 查看容器日志
docker compose -f docker-compose-gaussdb-cluster.yml logs -f backend

# 运行测试
cd tests && ./run-all-tests.sh
```

## 常见问题

### 1. 连接超时

**原因**: 防火墙或网络配置问题

**解决**:

```bash
# 在主节点执行
firewall-cmd --add-port=5432/tcp --permanent
firewall-cmd --reload
```

### 2. 认证失败

**原因**: 用户权限或密码错误

**解决**:

```bash
# 在主节点执行
su - omm
gsql -d blog_db -p 5432
ALTER USER bloguser WITH PASSWORD 'blogpass';
GRANT ALL PRIVILEGES ON DATABASE blog_db TO bloguser;
```

### 3. 备库无法连接

**原因**: 备库未启动或主备同步问题

**解决**:

```bash
# 检查备库状态
gs_ctl query -D /gaussdb/data

# 重启备库
gs_ctl restart -D /gaussdb/data
```

## 下一步

1. 运行测试: `cd tests && ./run-all-tests.sh`
2. 查看文档: `CLUSTER_QUICKSTART.md`
3. 部署应用: `./deploy-cluster.sh`
