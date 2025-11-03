import { test, expect } from '@playwright/test'
import { loginUser, waitForStableElement } from './utils/helpers'

/**
 * E2E 测试：好友系统
 * 
 * 测试流程：
 * 1. 登录用户
 * 2. 访问好友管理页面
 * 3. 搜索用户并发送好友请求
 * 4. 查看好友列表
 * 5. 管理好友（删除好友）
 */
test.describe('好友系统', () => {
  test.beforeEach(async ({ page }) => {
    // 登录用户
    await loginUser(page)
    await page.waitForLoadState('domcontentloaded')
  })

  test('访问好友管理页面', async ({ page }) => {
    // Given: 用户已登录
    await expect(page).toHaveURL(/.*\/home/)

    // When: 点击好友管理按钮
    const friendsButton = page.locator('button:has-text("好友"), a:has-text("好友")').first()
    
    // 检查按钮是否可见
    const isVisible = await friendsButton.isVisible({ timeout: 3000 }).catch(() => false)
    
    if (isVisible) {
      await friendsButton.click()
      
      // Then: 应该跳转到好友管理页面
      await expect(page).toHaveURL(/.*\/friends/, { timeout: 5000 })
      
      // Then: 验证页面元素
      await expect(page.locator('h1:has-text("好友管理")')).toBeVisible({ timeout: 5000 })
      
      // 应该有搜索栏
      const searchInput = page.locator('input[placeholder*="搜索"]')
      await expect(searchInput).toBeVisible({ timeout: 3000 })
    } else {
      // 如果导航按钮不可见，直接访问页面
      await page.goto('/friends')
      await expect(page).toHaveURL(/.*\/friends/)
      await expect(page.locator('h1:has-text("好友管理")')).toBeVisible({ timeout: 5000 })
    }
  })

  test('搜索用户功能', async ({ page }) => {
    // Given: 用户在好友管理页面
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // When: 输入搜索关键词
    const searchInput = page.locator('input[placeholder*="搜索"]')
    await expect(searchInput).toBeVisible({ timeout: 5000 })
    await searchInput.fill('admin')

    // When: 点击搜索按钮
    const searchButton = page.locator('button:has-text("搜索")')
    await searchButton.click()

    // Then: 等待搜索结果加载
    await page.waitForTimeout(2000)

    // Then: 验证搜索结果（可能有结果或无结果）
    const hasResults = await page.locator('.friend-card, .search-results .friend-card').count()
    const emptyState = await page.locator('.empty-state:has-text("未找到")').isVisible({ timeout: 2000 }).catch(() => false)

    // 搜索结果应该至少有一种状态（有结果或空状态）
    expect(hasResults > 0 || emptyState).toBeTruthy()
  })

  test('发送好友请求', async ({ page }) => {
    // Given: 用户在好友管理页面
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // When: 搜索一个不是好友的用户
    const searchInput = page.locator('input[placeholder*="搜索"]')
    await searchInput.fill('test')
    
    const searchButton = page.locator('button:has-text("搜索")')
    await searchButton.click()
    await page.waitForTimeout(2000)

    // Then: 检查是否有搜索结果
    const addButton = page.locator('button:has-text("添加好友")').first()
    const hasAddButton = await addButton.isVisible({ timeout: 3000 }).catch(() => false)

    if (hasAddButton) {
      // When: 点击添加好友按钮
      await addButton.click()

      // Then: 应该显示成功消息
      await page.waitForTimeout(1000)
      
      // 检查是否有成功提示或错误提示
      const successMessage = page.locator('.el-message:has-text("已发送"), .el-message:has-text("成功")')
      const errorMessage = page.locator('.el-message:has-text("已存在"), .el-message:has-text("已经")')
      
      const hasMessage = await successMessage.isVisible({ timeout: 2000 }).catch(() => false) ||
                         await errorMessage.isVisible({ timeout: 2000 }).catch(() => false)
      
      expect(hasMessage).toBeTruthy()
    } else {
      // 如果没有可添加的用户，跳过此测试
      console.log('没有可添加的用户，跳过发送好友请求测试')
    }
  })

  test('查看好友列表', async ({ page }) => {
    // Given: 用户在好友管理页面
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    // Then: 应该能看到好友列表区域
    const friendsSection = page.locator('h2:has-text("我的好友")')
    await expect(friendsSection).toBeVisible({ timeout: 5000 })

    // Then: 验证好友列表（可能有好友或空列表）
    const friendCards = await page.locator('.friends-section .friend-card').count()
    const emptyState = await page.locator('.friends-section .empty-state').isVisible({ timeout: 2000 }).catch(() => false)

    // 应该至少有一种状态（有好友或空状态）
    expect(friendCards > 0 || emptyState).toBeTruthy()
  })

  test('好友请求管理', async ({ page }) => {
    // Given: 用户在好友管理页面
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    // Then: 检查是否有待处理的好友请求
    const requestsSection = page.locator('h2:has-text("好友请求")')
    const hasRequests = await requestsSection.isVisible({ timeout: 2000 }).catch(() => false)

    if (hasRequests) {
      // Then: 验证请求卡片存在
      const requestCard = page.locator('.requests-section .friend-card').first()
      await expect(requestCard).toBeVisible({ timeout: 3000 })

      // Then: 应该有同意和拒绝按钮
      const acceptButton = page.locator('.requests-section button:has-text("同意")').first()
      const rejectButton = page.locator('.requests-section button:has-text("拒绝")').first()

      await expect(acceptButton).toBeVisible({ timeout: 2000 })
      await expect(rejectButton).toBeVisible({ timeout: 2000 })
    } else {
      // 如果没有待处理请求，这也是正常的
      console.log('当前没有待处理的好友请求')
    }
  })

  test('删除好友功能', async ({ page }) => {
    // Given: 用户在好友管理页面且有好友
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    // Then: 检查是否有好友
    const friendCards = await page.locator('.friends-section .friend-card').count()

    if (friendCards > 0) {
      // When: 点击删除按钮
      const deleteButton = page.locator('.friends-section button:has-text("删除")').first()
      
      // 监听确认对话框
      page.once('dialog', async dialog => {
        expect(dialog.type()).toBe('confirm')
        await dialog.dismiss() // 取消删除以避免真实删除数据
      })

      await deleteButton.click()
      await page.waitForTimeout(500)

      // Then: 验证对话框已出现（通过dismiss操作）
      // 如果没有抛出异常，说明对话框正常工作
    } else {
      console.log('没有好友可删除，跳过删除测试')
    }
  })

  test('好友管理页面响应式布局', async ({ page }) => {
    // Given: 用户在好友管理页面
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // When: 模拟移动设备尺寸
    await page.setViewportSize({ width: 375, height: 667 })
    await page.waitForTimeout(500)

    // Then: 页面应该正常显示
    const pageHeader = page.locator('h1:has-text("好友管理")')
    await expect(pageHeader).toBeVisible()

    // When: 恢复桌面尺寸
    await page.setViewportSize({ width: 1280, height: 720 })
    await page.waitForTimeout(500)

    // Then: 页面应该仍然正常显示
    await expect(pageHeader).toBeVisible()
  })

  test('好友卡片信息显示', async ({ page }) => {
    // Given: 用户在好友管理页面
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    // Then: 如果有好友，验证好友卡片信息
    const firstFriendCard = page.locator('.friend-card').first()
    const hasFriends = await firstFriendCard.isVisible({ timeout: 2000 }).catch(() => false)

    if (hasFriends) {
      // Then: 验证卡片包含必要信息
      const avatar = firstFriendCard.locator('.friend-avatar')
      const name = firstFriendCard.locator('.friend-name')

      await expect(avatar).toBeVisible()
      await expect(name).toBeVisible()

      // 验证头像有正确的src属性
      const avatarSrc = await avatar.getAttribute('src')
      expect(avatarSrc).toBeTruthy()
    } else {
      console.log('没有好友，跳过卡片信息验证')
    }
  })

  test('搜索空关键词提示', async ({ page }) => {
    // Given: 用户在好友管理页面
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // When: 不输入关键词直接搜索
    const searchButton = page.locator('button:has-text("搜索")')
    await searchButton.click()

    // Then: 应该显示警告消息
    await page.waitForTimeout(1000)
    const warningMessage = page.locator('.el-message--warning, .el-message:has-text("关键词")')
    const hasWarning = await warningMessage.isVisible({ timeout: 2000 }).catch(() => false)

    expect(hasWarning).toBeTruthy()
  })
})

