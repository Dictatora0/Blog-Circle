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
  
  // 测试超时时间（20秒，快速失败）
  timeout: 20000,
  
  // 每个测试用例期望超时时间
  expect: {
    timeout: 3000,
  },
  
  // 完全并行执行
  fullyParallel: true,
  
  // CI 环境禁止 test.only
  forbidOnly: !!process.env.CI,
  
  // 快速失败，不重试（加快测试速度）
  retries: 0,
  
  // 使用更多workers加快测试（6个worker）
  workers: process.env.CI ? 1 : 6,
  
  // 报告配置
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['list'],
  ],
  
  // 全局配置
  use: {
    baseURL: 'http://localhost:5173',
    headless: true,
    // 完全禁用所有录制功能
    video: 'off',
    screenshot: 'off',
    trace: 'off',
    // 减少超时时间
    navigationTimeout: 10000,
    actionTimeout: 5000,
    // 禁用自动等待
    waitForTimeout: 0,
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

