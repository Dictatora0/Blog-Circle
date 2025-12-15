# 数据库连接架构说明

## 当前实际运行状态

### 1. 数据库容器状态

**运行中的三个 openGauss 容器：**

| 容器名               | 端口映射   | 角色   | 实际状态                |
| -------------------- | ---------- | ------ | ----------------------- |
| `opengauss-primary`  | 5432:5432  | 主库   | ✅ 运行中，应用正在使用 |
| `opengauss-standby1` | 5434:15432 | 备库 1 | ✅ 运行中，**但未连接** |
| `opengauss-standby2` | 5436:25432 | 备库 2 | ✅ 运行中，**但未连接** |

### 2. 应用实际连接情况

**当前应用只连接到一个数据库：**

```
应用 (blogcircle-backend)
    ↓
    └── HikariCP 连接池 (HikariPool-1)
            ↓
            └── opengauss-primary:5432/blog_db
                (主库，读写操作都在这里)
```

**验证命令：**

```bash
# 查看环境变量
docker exec blogcircle-backend env | grep DATASOURCE

# 输出：
# SPRING_DATASOURCE_URL=jdbc:opengauss://opengauss-primary:5432/blog_db
# SPRING_DATASOURCE_USERNAME=bloguser
# SPRING_DATASOURCE_PASSWORD=Blog@2025
```

## 配置文件 vs 实际运行

### 配置文件中的定义

虽然 `application-opengauss-cluster.yml` 定义了三个数据源：

```yaml
spring:
  datasource:
    # 主库配置（写操作）
    primary:
      jdbc-url: jdbc:opengauss://opengauss-primary:5432/blog_db

    # 备库1配置（读操作）
    replica1:
      jdbc-url: jdbc:opengauss://opengauss-standby1:5432/blog_db

    # 备库2配置（读操作）
    replica2:
      jdbc-url: jdbc:opengauss://opengauss-standby2:5432/blog_db
```

### 实际运行情况

**Docker Compose 通过环境变量覆盖了配置：**

```yaml
# docker-compose-opengauss-cluster.yml
backend:
  environment:
    SPRING_PROFILES_ACTIVE: opengauss-cluster
    SPRING_DATASOURCE_URL: jdbc:opengauss://opengauss-primary:5432/blog_db # 直接覆盖
    SPRING_DATASOURCE_USERNAME: bloguser
    SPRING_DATASOURCE_PASSWORD: "Blog@2025"
```

**结果：** 应用使用 Spring Boot 的默认单数据源配置，只连接到 `opengauss-primary`。

## 读写分离配置状态

### DataSourceConfig.java 分析

项目中有读写分离的配置代码：

```java
@Configuration
@ConditionalOnProperty(name = "spring.profiles.active", havingValue = "gaussdb-cluster")
// ⚠️ 注意：只在 profile = "gaussdb-cluster" 时激活
public class DataSourceConfig {
    // 主库数据源
    @Bean(name = "primaryDataSource")
    public DataSource primaryDataSource() { ... }

    // 备库数据源
    @Bean(name = "replicaDataSource")
    public DataSource replicaDataSource() { ... }

    // 动态路由数据源
    @Bean(name = "routingDataSource")
    public DataSource routingDataSource() { ... }
}
```

**问题：**

- 当前使用的 profile 是 `opengauss-cluster`
- 但 `DataSourceConfig` 只在 profile = `gaussdb-cluster` 时才激活
- 所以读写分离功能 **当前未生效**

## 三个数据库的关系

### 现状：独立实例

```
┌─────────────────────┐
│ opengauss-primary   │  ◄──── 应用连接（读写）
│ (独立实例)          │
└─────────────────────┘

┌─────────────────────┐
│ opengauss-standby1  │  ◄──── 未使用（独立实例）
│ (独立实例)          │
└─────────────────────┘

┌─────────────────────┐
│ opengauss-standby2  │  ◄──── 未使用（独立实例）
│ (独立实例)          │
└─────────────────────┘
```

**特点：**

- ❌ 没有配置主备复制关系
- ❌ 没有数据同步
- ❌ 没有读写分离
- ✅ 三个独立的数据库实例
- ✅ 只有 primary 在使用

### 理想的主备复制架构（未实现）

```
┌─────────────────────┐
│ opengauss-primary   │  ◄──── 应用写操作
│ (主库)              │
└──────────┬──────────┘
           │ 复制流 (Streaming Replication)
           ├────────────────┬────────────────┐
           ↓                ↓                ↓
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ standby1        │  │ standby2        │  │ 应用读操作      │
│ (从库/只读)     │  │ (从库/只读)     │  │ (负载均衡)      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

## 为什么这样设计？

### 当前设计的优点

1. **简单可靠**：单数据源，无复杂的同步问题
2. **易于维护**：不需要管理主备复制
3. **兼容性好**：适用于所有环境
4. **快速部署**：无需额外的复制配置

### 当前设计的局限

1. **无高可用**：主库宕机，服务不可用
2. **无读写分离**：所有读写压力在主库
3. **无负载均衡**：无法分散读取负载
4. **资源浪费**：standby1 和 standby2 闲置

## 如何启用读写分离？

如果要启用三个数据库的读写分离，需要以下步骤：

### 方案 1：修改环境变量（推荐）

修改 `docker-compose-opengauss-cluster.yml`：

```yaml
backend:
  environment:
    SPRING_PROFILES_ACTIVE: gaussdb-cluster # 改为 gaussdb-cluster
    # 移除这些环境变量覆盖，让应用使用配置文件
    # SPRING_DATASOURCE_URL: ...
    # SPRING_DATASOURCE_USERNAME: ...
    # SPRING_DATASOURCE_PASSWORD: ...
```

### 方案 2：配置真正的主备复制

需要额外的初始化脚本配置 openGauss 主备复制关系（较复杂）。

## 验证命令

### 检查应用连接池

```bash
# 查看 HikariCP 日志
ssh root@10.211.55.11 "docker logs blogcircle-backend 2>&1 | grep -i hikari"

# 当前只会看到一个连接池：HikariPool-1
```

### 检查数据库连接

```bash
# 查看主库连接
ssh root@10.211.55.11 "docker exec opengauss-primary bash -c 'su - omm -c \"gsql -d blog_db -c \\\"SELECT COUNT(*) FROM pg_stat_activity WHERE datname='\''blog_db'\'';\\\"\""

# 查看备库连接（应该是 0）
ssh root@10.211.55.11 "docker exec opengauss-standby1 bash -c 'su - omm -c \"gsql -d blog_db -c \\\"SELECT COUNT(*) FROM pg_stat_activity WHERE datname='\''blog_db'\'';\\\"\""
```

## 总结

### 当前架构

✅ **简单单库模式**

- 只使用 `opengauss-primary` 一个数据库
- 所有读写操作都在主库
- 备库容器运行但未使用
- 适合中小规模应用

### 未来扩展

如需高可用和负载均衡，可以：

1. 配置 openGauss 主备复制
2. 启用应用层读写分离
3. 使用负载均衡器分发读请求

**当前状态完全满足开发和测试需求，生产环境可根据实际负载考虑扩展。**
