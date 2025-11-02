/**
 * E2E 测试辅助函数
 * 
 * 提供通用的测试工具函数，如登录、等待等
 */

import { Page } from '@playwright/test'

/**
 * 等待服务器就绪（通过访问首页并检查响应）
 * @param page Playwright Page 对象
 * @param maxRetries 最大重试次数，默认 3
 * @param retryDelay 重试延迟（毫秒），默认 2000
 */
export async function waitForServerReady(
  page: Page,
  maxRetries: number = 3,
  retryDelay: number = 2000
): Promise<void> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await page.goto('/', { 
        waitUntil: 'domcontentloaded',
        timeout: 30000 
      })
      // 验证页面已加载（检查是否有基本元素）
      await page.waitForLoadState('domcontentloaded')
      return // 成功则返回
    } catch (error) {
      if (i === maxRetries - 1) {
        throw new Error(`服务器未就绪，已重试 ${maxRetries} 次: ${error}`)
      }
      // 等待后重试
      await page.waitForTimeout(retryDelay)
    }
  }
}

/**
 * 登录用户
 * @param page Playwright Page 对象
 * @param username 用户名，默认为 'admin'
 * @param password 密码，默认为 'admin123'
 */
export async function loginUser(
  page: Page,
  username: string = 'admin',
  password: string = 'admin123'
): Promise<void> {
  await page.goto('/login')
  await page.waitForLoadState('domcontentloaded')
  
  // 等待输入框可见
  await page.waitForSelector('input[placeholder="用户名"], input[placeholder*="用户名"]', { timeout: 5000 })
  await page.waitForSelector('input[placeholder="密码"], input[placeholder*="密码"]', { timeout: 5000 })
  
  await page.locator('input[placeholder="用户名"]').fill(username)
  await page.locator('input[placeholder="密码"]').fill(password)
  
  // 等待登录 API 响应（在点击按钮之前启动监听）
  const loginResponsePromise = page.waitForResponse(
    (response) => response.url().includes('/api/auth/login') && response.request().method() === 'POST',
    { timeout: 15000 }
  )
  
  await page.locator('button:has-text("登录")').click()
  
  // 等待登录 API 响应完成
  const loginResponse = await loginResponsePromise
  const status = loginResponse.status()
  
  // 读取响应数据（只能读取一次）
  const responseData = await loginResponse.json().catch(() => ({ code: -1, message: '无法解析响应数据' }))
  
  if (status !== 200) {
    throw new Error(`登录失败: HTTP ${status}, ${responseData.message || '未知错误'}`)
  }
  
  // 验证响应数据
  if (responseData.code !== 200 || !responseData.data?.token) {
    throw new Error(`登录失败: ${responseData.message || '响应数据格式错误'}`)
  }
  
  // 等待登录完成并跳转到首页（增加超时时间）
  await page.waitForURL(/.*\/home/, { timeout: 15000 })
  
  // 等待页面完全加载和状态更新
  await page.waitForLoadState('domcontentloaded')
  await page.waitForTimeout(1000)
  
  // 验证登录状态（检查localStorage）
  const token = await page.evaluate(() => localStorage.getItem('token'))
  if (!token) {
    throw new Error('登录失败：token未设置')
  }
}

/**
 * 等待动态列表加载完成
 * @param page Playwright Page 对象
 */
export async function waitForMomentsLoad(page: Page): Promise<void> {
  // 等待动态列表加载，使用更灵活的选择器
  try {
    // 先等待页面DOM加载完成
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)
    
    // 等待动态项或空状态出现（注意：实际DOM结构是 .moment-wrapper 包裹 .moment-item）
    await Promise.race([
      page.waitForSelector('.moment-wrapper, .moment-item', { timeout: 10000 }),
      page.waitForSelector('.empty-state', { timeout: 10000 })
    ])
  } catch (error) {
    // 如果超时，继续执行（可能是空列表）
    console.log('等待动态列表加载超时，继续执行')
  }
}

/**
 * 生成随机测试文本
 * @param prefix 前缀
 * @returns 随机文本
 */
export function generateRandomText(prefix: string = 'E2E测试'): string {
  return `${prefix} - ${new Date().toLocaleString()}`
}

/**
 * 获取第一条动态
 * @param page Playwright Page 对象
 * @returns 第一条动态的定位器
 */
export function getFirstMoment(page: Page) {
  return page.locator('.moment-wrapper, .moment-item').first()
}

/**
 * 等待元素可见并稳定
 * @param page Playwright Page 对象
 * @param selector 选择器
 * @param timeout 超时时间（毫秒）
 */
export async function waitForStableElement(
  page: Page,
  selector: string,
  timeout: number = 5000
): Promise<void> {
  await page.waitForSelector(selector, { timeout, state: 'visible' })
  // 等待一小段时间确保元素稳定
  await page.waitForTimeout(200)
}

/**
 * 检查元素是否存在（不抛出异常）
 * @param page Playwright Page 对象
 * @param selector 选择器
 * @returns 是否存在
 */
export async function elementExists(page: Page, selector: string): Promise<boolean> {
  try {
    const element = page.locator(selector).first()
    return await element.isVisible({ timeout: 1000 })
  } catch {
    return false
  }
}

/**
 * 滚动到页面底部
 * @param page Playwright Page 对象
 */
export async function scrollToBottom(page: Page): Promise<void> {
  await page.evaluate(() => {
    window.scrollTo(0, document.body.scrollHeight)
  })
  await page.waitForTimeout(1000)
}

/**
 * 等待API请求完成
 * @param page Playwright Page 对象
 * @param urlPattern URL模式
 * @param timeout 超时时间（毫秒）
 */
export async function waitForApiRequest(
  page: Page,
  urlPattern: string | RegExp,
  timeout: number = 5000
): Promise<void> {
  await page.waitForResponse(
    (response) => {
      const url = response.url()
      if (typeof urlPattern === 'string') {
        return url.includes(urlPattern)
      } else {
        return urlPattern.test(url)
      }
    },
    { timeout }
  )
}

/**
 * 创建一条测试动态（用于确保测试数据存在）
 * @param page Playwright Page 对象
 * @param content 动态内容，默认为随机内容
 * @returns 创建的动态ID（如果有）
 */
export async function createTestPost(
  page: Page,
  content?: string
): Promise<void> {
  const testContent = content || generateRandomText('测试动态')
  
  // 导航到发布页面
  await page.goto('/publish')
  await page.waitForLoadState('domcontentloaded')
  await page.waitForTimeout(500)
  
  // 输入内容
  const contentInput = page.locator('textarea[placeholder="分享你的想法..."]')
  await contentInput.waitFor({ state: 'visible', timeout: 5000 })
  await contentInput.fill(testContent)
  
  // 等待发布 API 响应
  const publishResponsePromise = page.waitForResponse(
    (response) => response.url().includes('/api/posts') && response.request().method() === 'POST',
    { timeout: 15000 }
  )
  
  // 点击发布按钮
  const submitButton = page.locator('button:has-text("发布")')
  await submitButton.waitFor({ state: 'visible', timeout: 5000 })
  await submitButton.click()
  
  // 等待 API 响应
  const publishResponse = await publishResponsePromise
  const status = publishResponse.status()
  
  if (status !== 200) {
    const responseData = await publishResponse.json().catch(() => ({ code: -1, message: '无法解析响应数据' }))
    throw new Error(`创建测试动态失败: HTTP ${status}, ${responseData.message || '未知错误'}`)
  }
  
  // 等待跳转回首页
  await page.waitForURL(/.*\/home/, { timeout: 15000 })
  await page.waitForLoadState('domcontentloaded')
  await page.waitForTimeout(1000)
}

