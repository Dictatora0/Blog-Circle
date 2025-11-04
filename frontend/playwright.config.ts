import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright 配置文件
 * 支持本地和容器环境的 E2E 测试
 */

// 从环境变量读取配置
const TEST_ENV = process.env.TEST_ENV || 'local';

const envConfig: Record<string, { baseURL: string; apiURL: string }> = {
  local: {
    baseURL: 'http://localhost:5173', // 开发服务器端口
    apiURL: 'http://localhost:8081',
  },
  docker: {
    baseURL: 'http://10.211.55.11:8080',
    apiURL: 'http://10.211.55.11:8081',
  }
};

const config = envConfig[TEST_ENV] || envConfig.local;

export default defineConfig({
  testDir: './tests/e2e',
  
  // 测试超时
  timeout: 30 * 1000,
  expect: {
    timeout: 5000
  },

  // 全局超时设置
  globalTimeout: 60 * 60 * 1000, // 1小时
  
  // 失败后重试次数
  retries: process.env.CI ? 2 : 0,
  
  // 并行worker数量
  workers: process.env.CI ? 1 : undefined,
  
  // 报告配置
  reporter: [
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
    ['list'],
  ],

  // 测试输出目录
  outputDir: 'test-results/',

  use: {
    // 基础 URL
    baseURL: config.baseURL,
    
    // 浏览器设置
    headless: true,
    viewport: { width: 1280, height: 720 },
    ignoreHTTPSErrors: true,
    
    // 视频和截图
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
    
    // 导航超时
    navigationTimeout: 30 * 1000,
    actionTimeout: 10 * 1000,
    
    // 环境变量
    extraHTTPHeaders: {
      'Accept': 'application/json',
    },
  },

  // 项目配置 - 多浏览器测试
  projects: [
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'],
      },
    },
  ],

  // 本地开发服务器配置（仅在本地环境使用）
  ...(TEST_ENV === 'local' && {
    webServer: {
      command: 'npm run dev',
      url: 'http://localhost:5173',
      reuseExistingServer: !process.env.CI,
      timeout: 120 * 1000,
    },
  }),
});
