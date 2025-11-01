import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src')
    }
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true
      }
    }
  },
  test: {
    globals: true,
    environment: 'happy-dom',
    setupFiles: ['./tests/setup.js'],
    // 排除 E2E 测试文件，避免 Vitest 加载 Playwright 测试
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      '**/playwright-report/**',
      '**/test-results/**',
      '**/tests/e2e/**',
      '**/*.e2e.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'
    ],
    include: [
      '**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'
    ],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'tests/',
        '*.config.js',
        'dist/'
      ]
    }
  }
})


