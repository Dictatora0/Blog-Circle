import { expect, afterEach } from 'vitest'
import { cleanup } from '@testing-library/vue'
import '@testing-library/jest-dom'

// 每个测试后清理
afterEach(() => {
  cleanup()
})

// 全局 mock
global.ResizeObserver = class ResizeObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
}

