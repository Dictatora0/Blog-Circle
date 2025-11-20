# Blog Circle E2E 测试文档

## 概述

本项目使用 **Playwright** 作为端到端（E2E）测试框架，覆盖了 Blog Circle 的核心功能流程。

## 快速开始

### 安装依赖

```bash
# 安装项目依赖
npm install

# 安装 Playwright 浏览器
npx playwright install
```

### 运行测试

```bash
# 运行所有 E2E 测试
npm run test:e2e

# 运行测试并显示 UI（可视化模式）
npm run test:e2e:ui

# 运行特定测试文件
npx playwright test tests/e2e/login.spec.ts

# 运行特定测试用例
npx playwright test tests/e2e/login.spec.ts -g "成功登录"
```

### 查看测试报告

测试完成后，会自动生成 HTML 报告：

```bash
# 打开测试报告
npx playwright show-report
```

报告位置：`playwright-report/index.html`

## 测试文件结构

```
tests/e2e/
├── login.spec.ts          # 登录场景测试
├── post.spec.ts           # 发布动态测试（文字+图片）
├── like.spec.ts           # 点赞功能测试
├── comment.spec.ts        # 评论功能测试
├── image.spec.ts          # 图片预览测试
├── utils/
│   └── helpers.ts         # 测试辅助函数
└── fixtures/
    └── README.md          # 测试数据说明
```

## 测试场景覆盖

### 1. 用户登录场景 (`login.spec.ts`)

- 成功登录并跳转到主页
- 登录失败：用户名或密码错误
- 从注册页跳转到登录页
- 登录后显示用户信息

### 2. 发布动态场景 (`post.spec.ts`)

- 发布纯文字动态
- 发布带图片的动态
- 发布动态时字数统计
- 发布动态时删除已上传的图片
- 空内容不能发布

### 3. 点赞功能场景 (`like.spec.ts`)

- 点赞动态
- 取消点赞
- 未登录用户不能点赞
- 点赞按钮视觉反馈

### 4. 评论功能场景 (`comment.spec.ts`)

- 添加评论
- 评论输入框显示和隐藏
- 空评论不能提交
- 未登录用户不能评论
- 评论列表显示

### 5. 图片展示交互场景 (`image.spec.ts`)

- 点击图片打开预览
- 关闭图片预览
- 图片预览导航（多张图片）
- 图片加载状态
- 图片九宫格布局

## 配置说明

### Playwright 配置 (`playwright.config.js`)

- **baseURL**: `http://localhost:5173`
- **timeout**: 30 秒
- **浏览器**: Chromium（默认）
- **视频录制**: 失败时自动录制
- **截图**: 失败时自动截图
- **报告**: HTML 报告

### 测试账户

默认测试账户：

- **用户名**: `admin`
- **密码**: `admin123`

可在测试文件中修改，或使用环境变量配置。

## 测试辅助函数

### `loginUser(page, username, password)`

快速登录用户：

```typescript
import { loginUser } from "./utils/helpers";

await loginUser(page, "admin", "admin123");
```

### `waitForMomentsLoad(page)`

等待动态列表加载完成：

```typescript
import { waitForMomentsLoad } from "./utils/helpers";

await waitForMomentsLoad(page);
```

### `generateRandomText(prefix)`

生成随机测试文本：

```typescript
import { generateRandomText } from "./utils/helpers";

const testText = generateRandomText("测试动态");
```

更多辅助函数请查看 `tests/e2e/utils/helpers.ts`

## 调试测试

### 使用 Playwright Inspector

```bash
# 以调试模式运行测试
npx playwright test tests/e2e/login.spec.ts --debug
```

### 使用 Playwright Codegen（录制测试）

```bash
# 启动代码生成器
npx playwright codegen http://localhost:5173
```

### 查看测试追踪

```bash
# 打开测试追踪（trace）
npx playwright show-trace trace.zip
```

## CI/CD 集成

### GitHub Actions

项目已配置 GitHub Actions，在 `.github/workflows/test.yml` 中：

```yaml
- name: Run Frontend E2E Tests
  run: npm run test:e2e
  working-directory: ./frontend
```

### 本地 CI 模拟

```bash
# 模拟 CI 环境运行测试
CI=true npm run test:e2e
```

## 最佳实践

1. **测试隔离**: 每个测试用例应该是独立的，不依赖其他测试的状态
2. **等待策略**: 使用 `waitFor` 而不是固定的 `waitForTimeout`
3. **选择器**: 优先使用稳定的选择器（如 `data-testid`），避免使用易变的 CSS 类
4. **断言**: 每个操作后都应该有明确的断言
5. **清理**: 测试完成后清理测试数据（如果需要）

## 编写新测试

### 模板

```typescript
import { test, expect } from "@playwright/test";
import { loginUser, waitForMomentsLoad } from "./utils/helpers";

test.describe("功能场景", () => {
  test.beforeEach(async ({ page }) => {
    // 前置准备：登录、访问页面等
    await loginUser(page);
    await waitForMomentsLoad(page);
  });

  test("测试用例描述", async ({ page }) => {
    // Given: 初始状态
    await expect(page).toHaveURL(/.*\/home/);

    // When: 执行操作
    await page.click('button:has-text("操作")');

    // Then: 验证结果
    await expect(page.locator(".result")).toBeVisible();
  });
});
```

## 常见问题

### Q: 测试失败，提示找不到元素？

A: 检查元素选择器是否正确，使用 Playwright Inspector 调试：

```bash
npx playwright test --debug
```

### Q: 测试超时？

A: 增加超时时间或检查网络请求是否完成：

```typescript
await page.waitForResponse((response) => response.url().includes("/api/"));
```

### Q: 如何跳过某些测试？

A: 使用 `test.skip()`:

```typescript
test("跳过此测试", async ({ page }) => {
  test.skip();
  // ...
});
```

### Q: 测试图片上传失败？

A: 确保 `tests/e2e/fixtures/test-image.jpg` 文件存在，或修改测试使用其他图片路径。

## 参考资源

- [Playwright 官方文档](https://playwright.dev/)
- [Playwright API 文档](https://playwright.dev/docs/api/class-playwright)
- [Playwright 最佳实践](https://playwright.dev/docs/best-practices)

## 贡献指南

添加新测试时，请确保：

1. 测试用例命名清晰
2. 包含必要的注释
3. 遵循现有的代码风格
4. 更新本文档
