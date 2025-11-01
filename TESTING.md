# Blog Circle 测试框架使用指南

## 📋 目录结构

```
CloudCom/
├── backend/
│   ├── src/
│   │   └── test/
│   │       ├── java/com/cloudcom/blog/
│   │       │   ├── controller/      # Controller测试
│   │       │   ├── service/         # Service测试
│   │       │   └── util/            # Util测试
│   │       └── resources/
│   │           └── application-test.yml  # 测试配置
│   └── pom.xml
│
├── frontend/
│   ├── tests/
│   │   ├── setup.js                 # 测试环境配置
│   │   ├── unit/                    # 单元测试
│   │   │   └── components/
│   │   └── e2e/                     # E2E测试
│   │       └── blog-circle.spec.js
│   ├── playwright.config.js         # Playwright配置
│   └── package.json
│
└── .github/
    └── workflows/
        └── test.yml                  # CI/CD配置
```

## 🚀 快速开始

### 后端测试

1. **运行所有测试**
   ```bash
   cd backend
   mvn test
   ```

2. **运行特定测试类**
   ```bash
   mvn test -Dtest=AuthControllerTest
   ```

3. **查看测试覆盖率**
   ```bash
   mvn test jacoco:report
   ```

### 前端测试

1. **安装依赖**
   ```bash
   cd frontend
   npm install
   ```

2. **运行单元测试**
   ```bash
   npm run test
   ```

3. **运行测试并查看UI**
   ```bash
   npm run test:ui
   ```

4. **生成测试覆盖率报告**
   ```bash
   npm run test:coverage
   ```

5. **运行E2E测试**
   ```bash
   # 确保开发服务器正在运行
   npm run dev

   # 在另一个终端运行E2E测试
   npm run test:e2e
   ```

6. **运行E2E测试（UI模式）**
   ```bash
   npm run test:e2e:ui
   ```

## 📝 测试类型说明

### 后端测试

#### 1. Controller测试 (`AuthControllerTest`, `PostControllerTest`)
- 使用 `@SpringBootTest` 和 `@AutoConfigureMockMvc`
- 测试HTTP请求和响应
- Mock服务层依赖

#### 2. Service测试 (`UserServiceTest`)
- 使用 `@ExtendWith(MockitoExtension.class)`
- Mock数据访问层
- 测试业务逻辑

#### 3. Util测试 (`JwtUtilTest`)
- 测试工具类功能
- 验证JWT生成和解析

### 前端测试

#### 1. 单元测试 (`TopNavbar.spec.js`, `MomentItem.spec.js`)
- 使用 Vitest + Vue Testing Library
- 测试组件渲染和交互
- Mock路由和状态管理

#### 2. E2E测试 (`blog-circle.spec.js`)
- 使用 Playwright
- 测试完整用户流程
- 跨浏览器测试

## 🔧 配置说明

### 后端测试配置 (`application-test.yml`)
- 使用H2内存数据库
- 独立的JWT密钥
- 测试日志级别

### 前端测试配置 (`vite.config.js`)
- Vitest配置
- 覆盖率设置
- 测试环境设置

### CI/CD配置 (`.github/workflows/test.yml`)
- 自动运行后端和前端测试
- PostgreSQL服务容器
- 测试结果和覆盖率上传

## 📊 测试覆盖率

### 后端覆盖率目标
- 控制器: >80%
- 服务层: >85%
- 工具类: >90%

### 前端覆盖率目标
- 组件: >70%
- 工具函数: >80%

## 🐛 调试测试

### 后端调试
```bash
# 使用IDE调试
# 在测试类中设置断点，右键运行调试

# 查看详细日志
mvn test -X
```

### 前端调试
```bash
# 使用Vitest UI
npm run test:ui

# 使用Playwright Inspector
npm run test:e2e:ui
```

## 📚 最佳实践

1. **测试命名**: 使用 `场景描述` 格式
2. **测试结构**: Given-When-Then
3. **Mock数据**: 使用有意义的测试数据
4. **测试隔离**: 每个测试独立运行
5. **断言清晰**: 使用描述性的断言消息

## 🔍 常见问题

### 后端测试失败
- 检查数据库连接配置
- 确认测试数据正确
- 查看测试日志

### 前端测试失败
- 确认开发服务器运行
- 检查组件依赖
- 查看浏览器控制台

### CI/CD失败
- 检查GitHub Actions日志
- 确认环境变量设置
- 验证依赖安装

## 📞 支持

如有问题，请查看：
- 测试日志文件
- CI/CD运行日志
- 项目README文档

