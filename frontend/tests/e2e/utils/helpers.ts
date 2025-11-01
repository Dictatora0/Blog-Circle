/**
 * E2E 测试辅助函数
 * 
 * 提供通用的测试工具函数，如登录、等待等
 */

import { Page } from '@playwright/test'

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
  await page.locator('input[placeholder="用户名"]').fill(username)
  await page.locator('input[placeholder="密码"]').fill(password)
  await page.locator('button:has-text("登录")').click()
  
  // 等待登录完成（成功或失败）
  await page.waitForURL(/.*\/home/, { timeout: 10000 })
  
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

