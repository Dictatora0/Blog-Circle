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
  
  // 测试超时时间（30秒）
  timeout: 30000,
  
  // 每个测试用例期望超时时间
  expect: {
    timeout: 5000,
  },
  
  // 完全并行执行
  fullyParallel: true,
  
  // CI 环境禁止 test.only
  forbidOnly: !!process.env.CI,
  
  // CI 环境重试次数
  retries: process.env.CI ? 2 : 0,
  
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
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
})

