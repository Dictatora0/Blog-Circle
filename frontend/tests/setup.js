import { expect, afterEach, beforeEach } from 'vitest'
import { cleanup } from '@testing-library/vue'
import '@testing-library/jest-dom'
import ElementPlus from 'element-plus'

// 每个测试后清理
afterEach(() => {
  cleanup()
})

// Mock localStorage
class LocalStorageMock {
  constructor() {
    this.store = {}
  }

  clear() {
    this.store = {}
  }

  getItem(key) {
    return this.store[key] || null
  }

  setItem(key, value) {
    this.store[key] = String(value)
  }

  removeItem(key) {
    delete this.store[key]
  }

  get length() {
    return Object.keys(this.store).length
  }

  key(index) {
    const keys = Object.keys(this.store)
    return keys[index] || null
  }
}

// 设置全局 localStorage
global.localStorage = new LocalStorageMock()

// 每个测试前清理 localStorage
beforeEach(() => {
  global.localStorage.clear()
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

