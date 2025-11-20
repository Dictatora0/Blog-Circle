# 部署与测试脚本说明

本目录包含项目的所有部署、验证和测试脚本。

## 脚本列表

### GaussDB 集群相关

#### `verify-gaussdb-cluster.sh`

验证 GaussDB 一主二备集群状态

**功能**：

- 检查主库、备库 1、备库 2 运行状态
- 验证主备复制连接
- 测试主库写入功能
- 测试备库读取功能
- 验证数据同步
- 显示复制延迟统计

**使用方法**：

```bash
# 在虚拟机上执行
./scripts/verify-gaussdb-cluster.sh
```

**前置条件**：

- GaussDB 集群已部署（使用 `setup-gaussdb-single-vm-cluster.sh`）
- 三个实例正在运行（端口 5432, 5433, 5434）

---

#### `test-gaussdb-readwrite.sh`

测试 GaussDB 读写功能

**功能**：

- 测试主库和备库连接
- 测试主库写入
- 测试备库读取
- 验证主备数据一致性
- 测试业务表读写

**使用方法**：

```bash
# 默认配置
./scripts/test-gaussdb-readwrite.sh

# 自定义配置
./scripts/test-gaussdb-readwrite.sh <主库IP> <主库端口> <备库端口>
```

**示例**：

```bash
./scripts/test-gaussdb-readwrite.sh 127.0.0.1 5432 5433
```

---

### Spark 集成相关

#### `test-spark-gaussdb.sh`

测试 Spark 访问 GaussDB 集群

**功能**：

- 编译 Spark 项目
- 运行 Spark 任务
- 测试 Spark 读写 GaussDB
- 验证主备库访问

**使用方法**：

```bash
# 默认配置
./scripts/test-spark-gaussdb.sh

# 自定义 GaussDB 地址
./scripts/test-spark-gaussdb.sh 10.211.55.11 5432
```

**前置条件**：

- 已安装 Spark
- GaussDB 集群正在运行
- analytics 模块已编译

---

### API 验证相关

#### `verify-api-mapping.sh`

验证前后端 API 映射关系

**功能**：

- 检查前端 API 定义
- 验证后端 Controller 接口
- 自动匹配前后端 API
- 生成验证报告

**使用方法**：

```bash
./scripts/verify-api-mapping.sh
```

**验证的 API**：

- 认证 API（登录、注册）
- 用户 API（获取信息、更新）
- 帖子 API（CRUD、列表、时间线）
- 评论 API（CRUD、查询）
- 好友 API（请求、接受、拒绝、列表、搜索）
- 点赞 API（点赞、取消、检查、计数）
- 上传 API（图片上传）
- 统计 API（Spark 分析、数据查询）

---

### 服务启动相关

#### `start-backend.sh`

启动后端服务

**功能**：

- 编译后端项目
- 启动 Spring Boot 应用
- 支持开发和生产模式

**使用方法**：

```bash
# 开发模式（默认）
./scripts/start-backend.sh

# 生产模式（使用 GaussDB 集群配置）
./scripts/start-backend.sh prod

# 自定义端口
./scripts/start-backend.sh dev 8081
```

**配置说明**：

- `dev` 模式：使用 `application.yml`
- `prod` 或 `gaussdb-cluster` 模式：使用 `application-gaussdb-cluster.yml`

---

#### `start-frontend.sh`

启动前端服务

**功能**：

- 安装前端依赖
- 启动开发服务器
- 构建生产版本

**使用方法**：

```bash
# 开发模式（默认）
./scripts/start-frontend.sh

# 构建生产版本
./scripts/start-frontend.sh build

# 自定义端口
./scripts/start-frontend.sh dev 3000
```

---

### 端到端测试

#### `test-e2e.sh`

完整的端到端功能测试

**功能**：

- 健康检查
- 用户注册和登录
- 获取用户信息
- 创建和查询帖子
- 点赞功能
- 评论功能
- 统计数据查询

**使用方法**：

```bash
# 测试本地服务
./scripts/test-e2e.sh

# 测试远程服务
./scripts/test-e2e.sh http://10.211.55.11:8080
```

**测试流程**：

1. 健康检查
2. 注册新用户
3. 用户登录获取 Token
4. 获取当前用户信息
5. 创建测试帖子
6. 获取帖子列表和详情
7. 点赞帖子
8. 创建评论
9. 获取评论列表
10. 查询统计数据

---

## 完整部署流程

### 1. 部署 GaussDB 集群（虚拟机）

```bash
# 在虚拟机上执行
cd /Users/lifulin/Desktop/CloudCom
./setup-gaussdb-single-vm-cluster.sh

# 验证集群状态
./scripts/verify-gaussdb-cluster.sh

# 测试读写功能
./scripts/test-gaussdb-readwrite.sh
```

### 2. 启动后端服务

```bash
# 本地开发
./scripts/start-backend.sh dev

# 或使用 GaussDB 集群配置
./scripts/start-backend.sh gaussdb-cluster
```

### 3. 启动前端服务

```bash
./scripts/start-frontend.sh dev
```

### 4. 运行测试

```bash
# API 映射验证
./scripts/verify-api-mapping.sh

# 端到端测试
./scripts/test-e2e.sh

# Spark 测试（可选）
./scripts/test-spark-gaussdb.sh
```

---

## Docker 部署

使用项目根目录的部署脚本：

```bash
# 本地 Docker Compose 部署
./deploy.sh local

# 虚拟机部署
./deploy.sh vm

# GaussDB 集群部署
./deploy.sh cluster
```

---

## 故障排查

### GaussDB 集群问题

**问题**：备库无法连接到主库

**解决方法**：

1. 检查主库 `pg_hba.conf` 配置
2. 验证复制用户权限
3. 检查复制槽状态：
   ```bash
   su - omm -c "gsql -d postgres -p 5432 -c 'SELECT * FROM pg_replication_slots;'"
   ```

**问题**：数据未同步到备库

**解决方法**：

1. 检查主库复制状态
2. 查看备库日志
3. 验证网络连接

### API 测试失败

**问题**：无法获取 Token

**解决方法**：

1. 确保后端服务正在运行
2. 检查数据库连接
3. 验证用户是否存在

**问题**：API 返回 500 错误

**解决方法**：

1. 查看后端日志
2. 检查数据库表结构
3. 验证 SQL 语法兼容性

---

## 环境要求

### GaussDB 集群

- openGauss 9.2.4
- omm 用户
- 端口：5432, 5433, 5434

### 后端

- JDK 17
- Maven 3.8+
- Spring Boot 3.1.5

### 前端

- Node.js 18+
- npm 或 yarn

### Spark（可选）

- Apache Spark 3.5.0
- Scala 2.12

---

## 相关文档

- [项目 README](../README.md)
- [实验报告](../实验报告.md)
- [部署指南](../DEPLOYMENT_GUIDE.md)
