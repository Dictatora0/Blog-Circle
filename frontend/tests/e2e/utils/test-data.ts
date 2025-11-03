/**
 * 测试数据准备和清理工具
 */

import { Page } from '@playwright/test'
import { loginUser } from './helpers'

/**
 * 创建测试用户（通过注册）
 */
export async function createTestUser(
  page: Page,
  username: string,
  password: string = 'test123',
  email?: string
): Promise<void> {
  const testEmail = email || `${username}@test.com`
  
  await page.goto('/register')
  await page.waitForLoadState('domcontentloaded')
  
  // 填写注册表单
  await page.locator('input[placeholder*="用户名"]').fill(username)
  await page.locator('input[placeholder*="密码"]').first().fill(password)
  await page.locator('input[placeholder*="邮箱"], input[placeholder*="Email"]').fill(testEmail)
  
  // 提交注册
  const registerButton = page.locator('button:has-text("注册")')
  await registerButton.click()
  
  // 等待注册完成
  await page.waitForTimeout(2000)
}

/**
 * 发送好友请求（通过API）
 */
export async function sendFriendRequestViaUI(
  page: Page,
  targetUsername: string
): Promise<boolean> {
  await page.goto('/friends')
  await page.waitForLoadState('domcontentloaded')
  await page.waitForTimeout(500)
  
  // 搜索目标用户
  const searchInput = page.locator('input[placeholder*="搜索"]')
  await searchInput.fill(targetUsername)
  
  const searchButton = page.locator('button:has-text("搜索")')
  await searchButton.click()
  await page.waitForTimeout(2000)
  
  // 检查搜索结果
  const addButton = page.locator('button:has-text("添加好友")').first()
  const hasAddButton = await addButton.isVisible({ timeout: 3000 }).catch(() => false)
  
  if (hasAddButton) {
    await addButton.click()
    await page.waitForTimeout(1500)
    return true
  }
  
  return false
}

/**
 * 接受好友请求
 */
export async function acceptFriendRequest(page: Page): Promise<boolean> {
  await page.goto('/friends')
  await page.waitForLoadState('domcontentloaded')
  await page.waitForTimeout(1000)
  
  // 查找待处理的好友请求
  const acceptButton = page.locator('.requests-section button:has-text("同意")').first()
  const hasRequest = await acceptButton.isVisible({ timeout: 2000 }).catch(() => false)
  
  if (hasRequest) {
    await acceptButton.click()
    await page.waitForTimeout(1500)
    return true
  }
  
  return false
}

/**
 * 获取好友数量
 */
export async function getFriendCount(page: Page): Promise<number> {
  await page.goto('/friends')
  await page.waitForLoadState('domcontentloaded')
  await page.waitForTimeout(1000)
  
  return await page.locator('.friends-section .friend-card').count()
}

/**
 * 确保有至少一个好友（用于测试）
 */
export async function ensureHasFriend(
  page: Page,
  currentUsername: string = 'admin'
): Promise<boolean> {
  // 检查是否已有好友
  const friendCount = await getFriendCount(page)
  if (friendCount > 0) {
    return true
  }
  
  // 没有好友，尝试创建一个测试用户并添加为好友
  const testFriendUsername = `testfriend_${Date.now()}`
  
  // 登出当前用户
  await page.goto('/home')
  const userMenu = page.locator('.user-avatar-wrapper, .user-menu').first()
  if (await userMenu.isVisible({ timeout: 1000 }).catch(() => false)) {
    await userMenu.click()
    await page.waitForTimeout(300)
    const logoutButton = page.locator('text=/退出登录|登出/')
    if (await logoutButton.isVisible({ timeout: 1000 }).catch(() => false)) {
      await logoutButton.click()
      await page.waitForTimeout(1000)
    }
  }
  
  // 创建测试好友用户
  try {
    await createTestUser(page, testFriendUsername, 'test123')
  } catch (e) {
    console.log('创建测试用户可能失败:', e)
  }
  
  // 重新登录原用户
  await loginUser(page, currentUsername, 'admin123')
  
  // 发送好友请求
  await sendFriendRequestViaUI(page, testFriendUsername)
  
  // 登出并用测试好友登录
  await page.goto('/home')
  const userMenu2 = page.locator('.user-avatar-wrapper, .user-menu').first()
  if (await userMenu2.isVisible({ timeout: 1000 }).catch(() => false)) {
    await userMenu2.click()
    await page.waitForTimeout(300)
    const logoutButton = page.locator('text=/退出登录|登出/')
    if (await logoutButton.isVisible({ timeout: 1000 }).catch(() => false)) {
      await logoutButton.click()
      await page.waitForTimeout(1000)
    }
  }
  
  await loginUser(page, testFriendUsername, 'test123')
  
  // 接受好友请求
  await acceptFriendRequest(page)
  
  // 重新登录原用户
  await page.goto('/home')
  const userMenu3 = page.locator('.user-avatar-wrapper, .user-menu').first()
  if (await userMenu3.isVisible({ timeout: 1000 }).catch(() => false)) {
    await userMenu3.click()
    await page.waitForTimeout(300)
    const logoutButton = page.locator('text=/退出登录|登出/')
    if (await logoutButton.isVisible({ timeout: 1000 }).catch(() => false)) {
      await logoutButton.click()
      await page.waitForTimeout(1000)
    }
  }
  
  await loginUser(page, currentUsername, 'admin123')
  
  // 验证好友已添加
  const newFriendCount = await getFriendCount(page)
  return newFriendCount > 0
}

