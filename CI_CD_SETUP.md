# CI/CD 设置说明

## 📋 概述

本项目已配置完整的 CI/CD 流程，使用 GitHub Actions 自动运行测试。

---

## 🚀 快速开始

### 1. 提交新功能

```bash
# 使用提交脚本（推荐）
./commit-new-features.sh "feat: 添加头像上传功能"

# 或手动提交
git add .
git commit -m "feat: 添加头像上传和个人主页优化功能"
git push origin dev
```

### 2. 查看CI/CD状态

推送代码到 `dev` 或 `main` 分支后，访问 GitHub Actions 页面查看测试状态：
- `https://github.com/YOUR_REPO/actions`

**注意**: 本项目仅使用 `main` 和 `dev` 两个分支，不创建功能分支。

---

## 📊 CI/CD 流程

### 工作流文件

- **位置**: `.github/workflows/test.yml`
- **触发**: 
  - Push 到 `main` 或 `dev` 分支
  - Pull Request 到 `main` 或 `dev` 分支

### 测试阶段

#### 1. **后端测试** (`backend-test`)
- ✅ 设置 PostgreSQL 数据库
- ✅ 运行数据库迁移
- ✅ 编译后端代码
- ✅ 运行单元测试

#### 2. **前端测试** (`frontend-test`)
- ✅ 初始化数据库（包括 `cover_image` 字段迁移）
- ✅ 启动后端服务
- ✅ 启动前端服务
- ✅ 运行单元测试
- ✅ 运行E2E测试（包括新功能测试）

#### 3. **测试总结** (`test-summary`)
- ✅ 汇总测试结果
- ✅ 在PR中自动评论测试结果
- ✅ 上传测试报告和截图

---

## 🧪 测试覆盖

### 新功能测试

| 测试文件 | 测试内容 | 状态 |
|---------|---------|------|
| `avatar.spec.ts` | 头像上传功能 | ✅ |
| `profile.spec.ts` | 个人主页功能 | ✅ |

### 测试用例详情

#### 头像上传 (`avatar.spec.ts`)
- ✅ 成功上传头像
- ✅ 头像hover显示上传提示
- ✅ 点击头像触发文件选择
- ✅ 文件类型验证
- ✅ 文件大小验证
- ✅ 头像上传后更新显示
- ✅ 头像上传loading状态

#### 个人主页 (`profile.spec.ts`)
- ✅ 封面上传功能
- ✅ 封面hover显示上传提示
- ✅ 个人主页布局正确显示
- ✅ 动态列表正确显示
- ✅ 用户信息正确显示
- ✅ 点击头像跳转到个人主页
- ✅ 个人主页响应式布局

---

## 📦 测试报告

### 自动上传的Artifacts

每次测试运行后，以下内容会自动上传：

1. **Playwright报告** (`playwright-report/`)
   - HTML格式的详细测试报告
   - 保留30天

2. **测试截图** (`test-results/`)
   - 失败测试的截图
   - 保留7天

3. **测试视频** (`test-results/**/*.webm`)
   - 失败测试的视频录制
   - 保留7天

4. **服务器日志** (`backend.log`, `frontend.log`)
   - 后端和前端服务日志
   - 用于调试

### 查看报告

1. 访问 GitHub Actions 页面
2. 点击失败的测试运行
3. 在 Artifacts 部分下载报告
4. 解压并打开 `playwright-report/index.html`

---

## 🔧 本地运行测试

### 运行新功能测试

```bash
cd frontend

# 运行头像上传测试
npx playwright test tests/e2e/avatar.spec.ts

# 运行个人主页测试
npx playwright test tests/e2e/profile.spec.ts

# 运行所有新功能测试
npx playwright test tests/e2e/avatar.spec.ts tests/e2e/profile.spec.ts

# 查看测试报告
npx playwright show-report
```

### 使用测试脚本

```bash
# 运行头像上传测试
./test-avatar-upload.sh
```

---

## 🐛 调试失败的测试

### 1. 查看日志

CI/CD运行失败时，检查：
- **服务器日志**: `backend.log`, `frontend.log`
- **测试输出**: GitHub Actions 的日志输出

### 2. 本地复现

```bash
# 启动服务
./start.sh

# 运行失败的测试
cd frontend
npx playwright test tests/e2e/avatar.spec.ts --debug
```

### 3. 常见问题

#### 数据库连接失败
- 检查 PostgreSQL 服务是否运行
- 验证数据库连接配置

#### 服务启动超时
- 检查端口是否被占用
- 查看服务日志

#### 测试超时
- 增加超时时间
- 检查网络连接

---

## 📝 提交规范

### Commit Message 格式

```
feat: 添加新功能
fix: 修复bug
test: 添加或修改测试
docs: 更新文档
refactor: 代码重构
style: 代码格式调整
chore: 构建过程或辅助工具的变动
```

### 示例

```bash
git commit -m "feat: 添加头像上传和个人主页优化功能

- 添加头像上传功能
- 优化个人主页布局
- 添加封面上传功能
- 修复动态数据统计问题
- 添加E2E测试覆盖"
```

---

## 🔄 工作流程

### 开发流程

1. **切换到dev分支**
   ```bash
   git checkout dev
   git pull origin dev
   ```

2. **开发功能**
   - 编写代码
   - 添加测试
   - 本地测试

3. **提交代码到dev分支**
   ```bash
   ./commit-new-features.sh "feat: 添加头像上传功能"
   git push origin dev
   ```

4. **CI/CD自动运行测试**
   - 推送到dev分支后，CI/CD自动触发
   - 查看GitHub Actions测试结果

5. **合并到main分支**
   - 测试通过后，从dev合并到main
   ```bash
   git checkout main
   git pull origin main
   git merge dev
   git push origin main
   ```

### 分支策略

- **dev分支**: 开发分支，用于日常开发和测试
- **main分支**: 主分支，包含稳定可发布的代码
- **不创建功能分支**: 直接在dev分支上开发，保持分支结构简单

---

## 📊 CI/CD 状态徽章

在 README.md 中添加状态徽章：

```markdown
![CI/CD Status](https://github.com/YOUR_REPO/workflows/Blog%20Circle%20Test%20CI/badge.svg)
```

---

## ⚙️ 配置说明

### 环境变量

CI/CD中使用的环境变量：

- `SPRING_DATASOURCE_URL`: `jdbc:postgresql://localhost:5432/blog_db`
- `SPRING_DATASOURCE_USERNAME`: `lying`
- `SPRING_DATASOURCE_PASSWORD`: `456789`
- `CI`: `true` (禁用Playwright自动启动服务器)

### 数据库迁移

CI/CD会自动运行数据库迁移：
1. `init.sql` - 初始化数据库
2. `migration_add_cover_image.sql` - 添加封面字段

---

## 🎯 测试最佳实践

1. **每次提交前运行测试**
   ```bash
   ./test-avatar-upload.sh
   ```

2. **保持测试独立**
   - 每个测试应该独立运行
   - 不依赖其他测试的状态

3. **使用有意义的测试名称**
   - 描述测试的内容
   - 使用中文描述（本项目）

4. **添加适当的等待**
   - 等待API响应
   - 等待DOM更新
   - 等待动画完成

---

## 📚 相关文档

- [Playwright文档](https://playwright.dev/)
- [GitHub Actions文档](https://docs.github.com/en/actions)
- [测试文档](./frontend/tests/e2e/README.md)

---

**最后更新**: 2025-11-03

