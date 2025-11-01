import { expect, afterEach } from 'vitest'
import { cleanup } from '@testing-library/vue'
import '@testing-library/jest-dom'
import ElementPlus from 'element-plus'

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

// 全局注册 Element Plus（用于单元测试）
import { config } from '@vue/test-utils'
config.global.plugins = [ElementPlus]

