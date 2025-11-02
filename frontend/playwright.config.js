import { defineConfig, devices } from '@playwright/test'

/**
 * Playwright E2E 测试配置
 * 
 * 配置说明：
 * - 使用 Chromium 浏览器
 * - 启用视频录制和截图
 * - 自动启动开发服务器
 * - 生成 HTML 测试报告
 */
export default defineConfig({
  testDir: './tests/e2e',
  
  // 测试超时时间（60秒，给首次启动更多时间）
  timeout: 60000,
  
  // 每个测试用例期望超时时间
  expect: {
    timeout: 10000,
  },
  
  // 完全并行执行
  fullyParallel: true,
  
  // CI 环境禁止 test.only
  forbidOnly: !!process.env.CI,
  
  // CI 环境重试次数（非 CI 环境也启用重试，处理 flaky 测试）
  retries: process.env.CI ? 2 : 1,
  
  // CI 环境串行执行
  workers: process.env.CI ? 1 : undefined,
  
  // 报告配置
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['list'],
  ],
  
  // 全局配置
  use: {
    baseURL: 'http://localhost:5173',
    headless: true,
    // 视频录制：失败时录制
    video: 'on-first-retry',
    // 截图：仅在失败时截图
    screenshot: 'only-on-failure',
    // 追踪：首次失败时追踪
    trace: 'on-first-retry',
    // 增加导航超时时间
    navigationTimeout: 60000,
  },

  // 项目配置（浏览器）
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    // 可选：添加 Firefox 和 WebKit
    // {
    //   name: 'firefox',
    //   use: { ...devices['Desktop Firefox'] },
    // },
    // {
    //   name: 'webkit',
    //   use: { ...devices['Desktop Safari'] },
    // },
  ],

  // Web 服务器配置（自动启动开发服务器）
  // 在 CI 环境中禁用自动启动，由 GitHub Actions 手动管理
  webServer: process.env.CI ? undefined : {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI, // 非 CI 环境复用服务器
    timeout: 120 * 1000, // 服务器启动超时 120 秒
    // 等待服务器响应后再开始测试
    stdout: 'pipe',
    stderr: 'pipe',
  },
})

