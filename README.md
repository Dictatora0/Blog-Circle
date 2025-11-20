# Blog Circle 项目说明

Blog Circle 是一个基于 Spring Boot + Vue 3 的社交博客系统，仿照朋友圈交互方式，支持文章流展示、好友关系、评论互动以及统计分析。本仓库同时提供本地开发、Docker Compose 容器化和远程 GaussDB 部署脚本，可用于课程设计、演示或进一步二次开发。

---

## 1. 功能概览

- **用户认证**：注册、登录、JWT 鉴权、个人资料维护。
- **文章系统**：支持文字与多图发布、编辑、删除、浏览统计。
- **评论与互动**：文章评论、点赞、好友时间线。
- **好友系统**：搜索、申请、处理、好友动态。
- **统计分析**：内置 SQL 统计，支持 Spark 扩展任务。
- **GaussDB 支持**：兼容 PostgreSQL / openGauss，提供一主二备部署方案。

---

## 2. 技术栈

| 层级   | 技术                                      |
| ------ | ----------------------------------------- |
| 前端   | Vue 3、Vite、Element Plus、Pinia、Axios   |
| 后端   | Spring Boot 3、MyBatis、JWT、Maven、JDK17 |
| 数据库 | PostgreSQL 14 / GaussDB(openGauss)        |
| 测试   | Playwright、JUnit、Shell 测试脚本         |
| 部署   | Docker Compose、sshpass、rsync            |

---

## 3. 仓库结构

```
CloudCom/
├── backend/                  # Spring Boot 服务
├── frontend/                 # Vue 3 前端
├── analytics/                # Spark 统计任务
├── tests/                    # 统一自动化测试脚本
├── docker-compose*.yml       # 多种部署编排
├── start.sh / stop.sh        # 本地开发环境启动/停止
├── docker-compose-start.sh   # 开发/VM 场景一键脚本
├── deploy*.sh                # 各类远程部署脚本
├── README.md / DEPLOYMENT.md # 核心文档
└── … (GaussDB、诊断、测试等脚本)
```

> 详细部署方案请参阅 `DEPLOYMENT_GUIDE.md`、`SINGLE_VM_CLUSTER_GUIDE.md`、`SPARK_SETUP_GUIDE.md` 等文件。

---

## 4. 环境准备

| 角色       | 版本要求          |
| ---------- | ----------------- |
| Java       | OpenJDK 17+       |
| Maven      | 3.6+              |
| Node.js    | 18+               |
| PostgreSQL | 14+（或 GaussDB） |
| Docker     | 20+（Compose v2） |

macOS 可通过 Homebrew 快速安装：

```bash
brew install openjdk@17 maven node postgresql@14
```

---

## 5. 快速开始

### 5.1 本地开发（PostgreSQL）

```bash
# 启动（自动创建 blog_db 并初始化数据）
./start.sh

# 前端: http://localhost:5173
# 后端: http://localhost:8080

# 停止服务
./stop.sh
```

日志默认写入 `logs/backend.log`、`logs/frontend.log`。

### 5.2 Docker Compose（PostgreSQL）

```bash
./docker-compose-start.sh dev   # 或 docker-compose up -d
./docker-compose-stop.sh dev    # 或 docker-compose down
```

端口映射：前端 8080、后端 8081、数据库 5432。

### 5.3 GaussDB 集群模拟（本地容器）

```bash
./start-gaussdb-cluster.sh      # 清理并启动 1 主 2 备 + Spark
./start-standby-and-verify.sh   # 健康检查与复制验证
```

使用 `docker-compose-gaussdb-pseudo.yml` 启动 gaussdb-primary/standby1/standby2、Spark、后端与前端。

### 5.4 远程部署（VM 10.211.55.11）

```bash
./deploy-cluster.sh         # 一键部署至单机一主二备 GaussDB 集群
./deploy-to-vm.sh           # 上传代码并 docker-compose 启动
./verify-gaussdb-cluster.sh # 远程复制状态报告
```

VM 预设：root/747599qw@，GaussDB 位于 `/usr/local/opengauss`，端口 5432/5433/5434。

---

## 6. 配置说明

- **后端**：`backend/src/main/resources/`
  - `application.yml`：默认 PostgreSQL。
  - `application-gaussdb*.yml`：连接 GaussDB（单库/集群）。
  - `DataSourceConfig.java` / `DataSourceAspect.java`：读写分离实现。
- **前端**：`.env.*` & `src/config` 控制 API 地址、镜像文件路径。
- **Docker**：
  - `docker-compose.yml`：PostgreSQL + backend + frontend。
  - `docker-compose-gaussdb-lite.yml`：连接已有 GaussDB，仅启动前后端。
  - `docker-compose-gaussdb.yml`：外部 GaussDB + Spark。
  - `docker-compose-gaussdb-cluster.yml`：VM 内部集群场景。

---

## 7. 测试

- `tests/run-all-tests.sh`：统一入口，会在 Docker 可用时启动 GaussDB 容器、导入数据、运行 Backend 集成测试、Spark API、复制校验。无 Docker 时退化为后端单元测试。
- `tests/api-test-suite.sh` / `database-test-suite.sh` / `automated-test-suite.sh`：拆分子集。
- `frontend/tests`：包含 Playwright E2E、单元测试示例。

运行示例：

```bash
./run-tests.sh           # 聚合脚本
bash tests/run-all-tests.sh
npm run test --prefix frontend
```

---

## 8. 常用脚本

| 脚本                           | 说明                                            |
| ------------------------------ | ----------------------------------------------- |
| `start.sh` / `stop.sh`         | 本地环境启停（PostgreSQL + Spring Boot + Vite） |
| `docker-compose-start/stop.sh` | dev/vm 模式的一键脚本                           |
| `deploy*.sh`                   | VM / 集群 部署、同步与验证                      |
| `fix-*.sh`                     | Docker 网络、镜像、CORS 等常见问题修复          |
| `check_gaussdb_cluster.sh`     | 输出 GaussDB 节点状态与复制详情                 |
| `run-spark-job.sh`             | 构建并提交 Spark 统计任务                       |

---

## 9. 常见问题

1. **后端连接数据库失败**：确认 PostgreSQL/GaussDB 运行、账号正确、`application*.yml` 配置匹配。
2. **前端 404 或跨域**：检查 Vite 代理、Nginx `nginx.conf`、后端 CORS 配置 (`WebConfig.java`)。
3. **GaussDB 复制异常**：运行 `verify-gaussdb-cluster.sh` 或 `check_gaussdb_cluster.sh` 获取日志并根据 `GAUSSDB_CLUSTER_DEPLOYMENT_SUCCESS.md` 排查。
4. **Spark 镜像拉取慢**：修改 `/etc/docker/daemon.json` 镜像源或参考 `SPARK_SETUP_GUIDE.md`。
5. **VM 部署冲突**：脚本默认关闭系统 PostgreSQL/Nginx，并释放 5432/8080/8081/8088/8888 端口。

---

## 10. 参考文档

- `DEPLOYMENT_GUIDE.md`：完整部署流程与命令手册。
- `SINGLE_VM_CLUSTER_GUIDE.md`：10.211.55.11 GaussDB 集群搭建记录。
- `GAUSSDB_*` 系列：复制配置、成功快照、参数说明。
- `SPARK_SETUP_GUIDE.md`：Spark 环境、镜像、作业调度注意事项。
- `TESTING_*` 系列：交付测试报告、自动化说明。

---

## 11. 支持信息

- 默认测试账号：`admin / admin123`。
- GaussDB 连接信息（VM / Docker 集群）：
  - 数据库：`blog_db`
  - 用户：`bloguser`
  - 密码：`blogpass` 或 `OpenGauss@123`（视脚本而定）
  - 端口：主库 5432，备库 5433/5434

如需进一步问题排查，可结合 `QUICK_FIX_GUIDE.md`、`diagnose.sh`、`test-local-services.sh` 等工具定位。

---

**提示**：提交前请运行 `run-tests.sh` 或至少执行后端/前端基本测试，确保主要功能与 GaussDB 集群脚本稳定。欢迎在此基础上扩展更多社交玩法或接入其它国产数据库方案。
