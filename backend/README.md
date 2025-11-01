# 博客系统后端

基于 Spring Boot + MyBatis + GaussDB 的博客系统后端服务。

## 项目结构

```
backend/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/cloudcom/blog/
│   │   │       ├── BlogApplication.java          # 主启动类
│   │   │       ├── common/                       # 公共类
│   │   │       │   └── Result.java              # 统一响应结果
│   │   │       ├── config/                       # 配置类
│   │   │       │   └── WebConfig.java           # Web配置
│   │   │       ├── controller/                   # 控制器
│   │   │       │   ├── AuthController.java      # 认证控制器
│   │   │       │   ├── UserController.java      # 用户控制器
│   │   │       │   ├── PostController.java      # 文章控制器
│   │   │       │   ├── CommentController.java   # 评论控制器
│   │   │       │   └── StatisticsController.java # 统计控制器
│   │   │       ├── entity/                       # 实体类
│   │   │       │   ├── User.java
│   │   │       │   ├── Post.java
│   │   │       │   ├── Comment.java
│   │   │       │   ├── AccessLog.java
│   │   │       │   └── Statistic.java
│   │   │       ├── interceptor/                  # 拦截器
│   │   │       │   └── JwtInterceptor.java      # JWT拦截器
│   │   │       ├── mapper/                       # Mapper接口
│   │   │       │   ├── UserMapper.java
│   │   │       │   ├── PostMapper.java
│   │   │       │   ├── CommentMapper.java
│   │   │       │   ├── AccessLogMapper.java
│   │   │       │   └── StatisticMapper.java
│   │   │       ├── service/                      # 服务类
│   │   │       │   ├── UserService.java
│   │   │       │   ├── PostService.java
│   │   │       │   ├── CommentService.java
│   │   │       │   └── SparkAnalyticsService.java
│   │   │       └── util/                         # 工具类
│   │   │           ├── JwtUtil.java             # JWT工具
│   │   │           └── PasswordUtil.java        # 密码工具
│   │   └── resources/
│   │       ├── application.yml                   # 应用配置
│   │       ├── db/
│   │       │   └── init.sql                     # 数据库初始化脚本
│   │       └── mapper/                          # MyBatis XML映射
│   │           ├── UserMapper.xml
│   │           ├── PostMapper.xml
│   │           ├── CommentMapper.xml
│   │           ├── AccessLogMapper.xml
│   │           └── StatisticMapper.xml
│   └── test/                                     # 测试代码
└── pom.xml                                       # Maven配置

```

## 核心依赖

- Spring Boot 3.1.5
- MyBatis 3.0.3
- PostgreSQL Driver 42.6.0
- JWT 0.11.5
- Apache Spark 3.5.0
- Lombok

## 配置说明

### 数据库配置

编辑 `src/main/resources/application.yml`：

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/blog_db
    username: your_username
    password: your_password
```

### JWT 配置

```yaml
jwt:
  secret: your-secret-key # 建议使用强随机字符串
  expiration: 86400000 # Token有效期（毫秒）
```

## 运行方式

### 开发环境

```bash
# 使用 Maven
mvn spring-boot:run

# 或者使用 IDE 运行 BlogApplication.java
```

### 生产环境

```bash
# 打包
mvn clean package

# 运行
java -jar target/blog-system-1.0.0.jar
```

## API 测试

可以使用 Postman、curl 或其他 API 测试工具进行测试。

### 测试用户登录

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }'
```

## Spark 分析

SparkAnalyticsService 提供了数据分析功能：

- 从 access_logs 表读取访问日志
- 统计用户发文数量
- 统计文章浏览次数
- 统计文章评论数量
- 结果写入 statistics 表

触发分析：

```bash
curl -X POST http://localhost:8080/api/stats/analyze \
  -H "Authorization: Bearer your-token"
```

## 注意事项

1. 首次运行前需执行数据库初始化脚本
2. JWT Token 需要在请求头中携带
3. Spark 分析需要较多系统资源，建议定期执行
4. 生产环境请修改 JWT 密钥
