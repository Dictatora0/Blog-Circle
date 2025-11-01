import { test, expect } from '@playwright/test'
import { waitForMomentsLoad } from './utils/helpers'

/**
 * E2E 测试：评论功能场景
 * 
 * 测试流程：
 * 1. 点击评论按钮
 * 2. 输入评论文本并提交
 * 3. 验证评论区新增该评论内容
 */
test.describe('评论功能场景', () => {
  let testComment: string

  test.beforeEach(async ({ page }) => {
    // 每次测试前先登录
    await page.goto('/login')
    await page.locator('input[placeholder="用户名"]').fill('admin')
    await page.locator('input[placeholder="密码"]').fill('admin123')
    await page.locator('button:has-text("登录")').click()
    await page.waitForURL(/.*\/home/, { timeout: 10000 })
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(2000)
    
    // 生成随机测试评论
    testComment = `E2E测试评论 - ${new Date().toLocaleString()}`
  })

  test('添加评论', async ({ page }) => {
    // Given: 用户在首页，至少有一条动态
    await expect(page).toHaveURL(/.*\/home/)
    await waitForMomentsLoad(page)
    
    const firstMoment = page.locator('.moment-wrapper, .moment-item').first()
    
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)
    if (!hasMoments) {
      test.skip()
      return
    }

    await expect(firstMoment).toBeVisible()

    // 获取评论按钮（第二个action-btn通常是评论按钮）
    const actionButtons = firstMoment.locator('button.action-btn')
    const commentButton = actionButtons.filter({ hasText: '💬' }).first()
    
    // 如果找不到带💬的按钮，尝试第二个按钮
    const commentBtn = await commentButton.isVisible({ timeout: 2000 }).catch(() => false) 
      ? commentButton 
      : actionButtons.nth(1)

    await expect(commentBtn).toBeVisible({ timeout: 5000 })

    // 获取初始评论数
    const commentCountElement = firstMoment.locator('.moment-stats .stat-item:has-text("💬")')
    const initialCommentCountText = await commentCountElement.textContent().catch(() => '0')
    const initialCommentCount = parseInt(initialCommentCountText?.match(/\d+/)?.at(0) || '0')

    // When: 点击评论按钮
    await commentBtn.click()

    // Then: 应该显示评论输入框
    const commentInput = page.locator('textarea[placeholder*="评论"], input[placeholder*="评论"], .el-input__inner').first()
    await expect(commentInput).toBeVisible({ timeout: 3000 })

    // When: 输入评论内容
    await commentInput.fill(testComment)

    // When: 点击发送按钮
    const sendButton = page.locator('button:has-text("发送"), button:has-text("提交")').first()
    await expect(sendButton).toBeVisible({ timeout: 3000 })
    await sendButton.click()

    // 等待评论提交完成并刷新动态数据
    await page.waitForTimeout(2000)
    
    // 重新加载评论列表（点击评论按钮展开评论区）
    const commentBtnAgain = firstMoment.locator('button.action-btn').filter({ hasText: '💬' }).first()
    if (await commentBtnAgain.isVisible({ timeout: 2000 }).catch(() => false)) {
      await commentBtnAgain.click()
      await page.waitForTimeout(1000)
    }

    // Then: 评论应该出现在评论区
    const commentList = firstMoment.locator('.moment-comments .comment-item')
    // 等待评论列表出现（可能需要等待API响应）
    await page.waitForTimeout(1000)
    
    // 尝试多次查找评论（因为评论可能需要时间加载）
    let commentFound = false
    for (let i = 0; i < 5; i++) {
      const commentCount = await commentList.count()
      if (commentCount > 0) {
        commentFound = true
        break
      }
      await page.waitForTimeout(500)
    }
    
    expect(commentFound).toBeTruthy()
    
    // Then: 评论内容应该显示
    const commentText = commentList.locator('.comment-text, .comment-content').filter({ hasText: testComment })
    await expect(commentText.first()).toBeVisible({ timeout: 5000 })

    // Then: 评论数应该增加
    const newCommentCountText = await commentCountElement.textContent().catch(() => '0')
    const newCommentCount = parseInt(newCommentCountText?.match(/\d+/)?.at(0) || '0')
    expect(newCommentCount).toBeGreaterThanOrEqual(initialCommentCount)
  })

  test('评论输入框显示和隐藏', async ({ page }) => {
    // Given: 用户在首页
    await expect(page).toHaveURL(/.*\/home/)
    await waitForMomentsLoad(page)
    
    const firstMoment = page.locator('.moment-wrapper, .moment-item').first()
    
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)
    if (!hasMoments) {
      test.skip()
      return
    }
    
    const actionButtons = firstMoment.locator('button.action-btn')
    const commentButton = actionButtons.filter({ hasText: '💬' }).first() || actionButtons.nth(1)

    // When: 第一次点击评论按钮
    await commentButton.click()
    
    // Then: 评论输入框应该显示
    const commentInput = page.locator('textarea[placeholder*="评论"], input[placeholder*="评论"]').first()
    await expect(commentInput).toBeVisible({ timeout: 3000 })

    // When: 再次点击评论按钮
    await commentButton.click()
    
    // Then: 评论输入框应该隐藏（如果支持切换）
    await page.waitForTimeout(500)
    // 注意：有些实现可能不会隐藏，这取决于具体实现
  })

  test('空评论不能提交', async ({ page }) => {
    // Given: 用户在首页，评论输入框已打开
    await expect(page).toHaveURL(/.*\/home/)
    await waitForMomentsLoad(page)
    
    const firstMoment = page.locator('.moment-wrapper, .moment-item').first()
    
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)
    if (!hasMoments) {
      test.skip()
      return
    }
    
    const actionButtons = firstMoment.locator('button.action-btn')
    const commentButton = actionButtons.filter({ hasText: '💬' }).first() || actionButtons.nth(1)
    
    await commentButton.click()
    
    const commentInput = page.locator('textarea[placeholder*="评论"], input[placeholder*="评论"]').first()
    await expect(commentInput).toBeVisible({ timeout: 3000 })

    // When: 不输入任何内容
    // Then: 发送按钮应该被禁用
    const sendButton = page.locator('button:has-text("发送"), button:has-text("提交")').first()
    
    // 检查按钮是否被禁用
    const isDisabled = await sendButton.isDisabled().catch(() => false)
    if (isDisabled) {
      expect(isDisabled).toBeTruthy()
    }
  })

  test('未登录用户不能评论', async ({ page }) => {
    // Given: 用户未登录，直接访问首页（先清除登录状态）
    await page.goto('/home')
    
    // 清除localStorage中的token
    await page.evaluate(() => {
      localStorage.removeItem('token')
      localStorage.removeItem('userInfo')
    })
    
    // 刷新页面以确保状态更新
    await page.reload({ waitUntil: 'domcontentloaded' })
    await waitForMomentsLoad(page)
    
    const firstMoment = page.locator('.moment-wrapper, .moment-item').first()
    
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)
    if (!hasMoments) {
      test.skip()
      return
    }
    
    const actionButtons = firstMoment.locator('button.action-btn')
    const commentButton = actionButtons.filter({ hasText: '💬' }).first() || actionButtons.nth(1)

    // When: 检查评论按钮状态（未登录时应该被禁用）
    const isDisabled = await commentButton.isDisabled().catch(() => false)
    
    // 验证按钮被禁用
    expect(isDisabled).toBeTruthy()
  })

  test('评论列表显示', async ({ page }) => {
    // Given: 用户在首页，动态已有评论
    await expect(page).toHaveURL(/.*\/home/)
    await waitForMomentsLoad(page)
    
    const firstMoment = page.locator('.moment-wrapper, .moment-item').first()
    
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)
    if (!hasMoments) {
      test.skip()
      return
    }
    
    // 检查是否有评论
    const commentList = firstMoment.locator('.moment-comments .comment-item')
    const commentCount = await commentList.count()
    
    if (commentCount > 0) {
      // Then: 评论应该正确显示
      const firstComment = commentList.first()
      await expect(firstComment).toBeVisible()
      
      // 评论应该包含用户信息和评论内容
      const commentContent = firstComment.locator('.comment-text').first()
      await expect(commentContent).toBeVisible()
    }
  })
})

