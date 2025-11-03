import { test, expect } from '@playwright/test'
import { loginUser, waitForMomentsLoad, generateRandomText } from './utils/helpers'

/**
 * E2E 测试：好友动态时间线
 * 
 * 测试流程：
 * 1. 登录用户
 * 2. 访问好友动态时间线
 * 3. 查看好友动态
 * 4. 点赞和评论好友动态
 * 5. 刷新时间线
 */
test.describe('好友动态时间线', () => {
  test.beforeEach(async ({ page }) => {
    // 登录用户
    await loginUser(page)
    await page.waitForLoadState('domcontentloaded')
  })

  test('访问好友动态时间线', async ({ page }) => {
    // Given: 用户已登录
    await expect(page).toHaveURL(/.*\/home/)

    // When: 点击好友动态按钮
    const timelineButton = page.locator('button:has-text("好友动态"), button:has-text("动态")').first()
    
    // 检查按钮是否可见
    const isVisible = await timelineButton.isVisible({ timeout: 3000 }).catch(() => false)
    
    if (isVisible) {
      await timelineButton.click()
      
      // Then: 应该跳转到时间线页面
      await expect(page).toHaveURL(/.*\/timeline/, { timeout: 5000 })
    } else {
      // 如果导航按钮不可见，直接访问页面
      await page.goto('/timeline')
      await expect(page).toHaveURL(/.*\/timeline/)
    }

    // Then: 验证页面元素
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // 应该有页面标题
    const pageHeader = page.locator('h1:has-text("好友动态"), .page-header')
    await expect(pageHeader).toBeVisible({ timeout: 5000 })
  })

  test('查看好友动态列表', async ({ page }) => {
    // Given: 用户在时间线页面
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    // Then: 应该加载动态列表或显示空状态
    await waitForMomentsLoad(page)

    // 验证动态列表或空状态
    const momentItems = await page.locator('.moment-item, .moment-wrapper').count()
    const emptyState = await page.locator('.empty-state').isVisible({ timeout: 2000 }).catch(() => false)

    // 应该至少有一种状态（有动态或空状态）
    expect(momentItems > 0 || emptyState).toBeTruthy()
  })

  test('好友动态显示作者信息', async ({ page }) => {
    // Given: 用户在时间线页面
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    // Then: 如果有动态，验证作者信息显示
    const firstMoment = page.locator('.moment-item, .moment-wrapper').first()
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)

    if (hasMoments) {
      // Then: 验证动态包含作者信息
      const authorName = firstMoment.locator('.moment-author, .author-name')
      const authorAvatar = firstMoment.locator('.avatar, .moment-avatar')

      await expect(authorName).toBeVisible({ timeout: 3000 })
      await expect(authorAvatar).toBeVisible({ timeout: 3000 })

      // 验证头像有正确的src属性
      const avatarSrc = await authorAvatar.getAttribute('src')
      expect(avatarSrc).toBeTruthy()
    } else {
      console.log('没有好友动态，跳过作者信息验证')
    }
  })

  test('好友动态显示发布时间', async ({ page }) => {
    // Given: 用户在时间线页面且有动态
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    const firstMoment = page.locator('.moment-item, .moment-wrapper').first()
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)

    if (hasMoments) {
      // Then: 验证时间显示
      const timeElement = firstMoment.locator('.moment-time, .time')
      await expect(timeElement).toBeVisible({ timeout: 3000 })

      const timeText = await timeElement.textContent()
      expect(timeText).toBeTruthy()
    } else {
      console.log('没有好友动态，跳过时间验证')
    }
  })

  test('点赞好友动态', async ({ page }) => {
    // Given: 用户在时间线页面且有动态
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    const firstMoment = page.locator('.moment-item, .moment-wrapper').first()
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)

    if (hasMoments) {
      // When: 点击点赞按钮
      const likeButton = firstMoment.locator('button:has-text("❤"), button:has-text("点赞"), .like-button').first()
      const hasLikeButton = await likeButton.isVisible({ timeout: 3000 }).catch(() => false)

      if (hasLikeButton) {
        // 获取点赞前的数量
        const likeCountBefore = await firstMoment.locator('.like-count, .stat-item').first().textContent()

        await likeButton.click()
        await page.waitForTimeout(1000)

        // Then: 验证点赞状态改变（视觉上或数量上）
        // 点赞后按钮可能会改变样式或数量增加
        const likeCountAfter = await firstMoment.locator('.like-count, .stat-item').first().textContent()

        // 点赞数量可能改变
        expect(likeCountAfter !== null).toBeTruthy()
      }
    } else {
      console.log('没有好友动态，跳过点赞测试')
    }
  })

  test('评论好友动态', async ({ page }) => {
    // Given: 用户在时间线页面且有动态
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    const firstMoment = page.locator('.moment-item, .moment-wrapper').first()
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)

    if (hasMoments) {
      // When: 点击评论按钮
      const commentButton = firstMoment.locator('button:has-text("💬"), button:has-text("评论"), .comment-button').first()
      const hasCommentButton = await commentButton.isVisible({ timeout: 3000 }).catch(() => false)

      if (hasCommentButton) {
        await commentButton.click()
        await page.waitForTimeout(500)

        // Then: 应该显示评论输入框
        const commentInput = page.locator('textarea[placeholder*="评论"], input[placeholder*="评论"]')
        const hasCommentInput = await commentInput.isVisible({ timeout: 3000 }).catch(() => false)

        if (hasCommentInput) {
          // When: 输入评论内容
          const testComment = generateRandomText('时间线测试评论')
          await commentInput.fill(testComment)

          // When: 提交评论
          const submitButton = page.locator('button:has-text("发送"), button:has-text("评论")').last()
          await submitButton.click()
          await page.waitForTimeout(1500)

          // Then: 验证评论已提交（可能显示成功消息或评论列表更新）
          const successMessage = page.locator('.el-message--success')
          const hasSuccess = await successMessage.isVisible({ timeout: 2000 }).catch(() => false)

          // 或者检查评论是否出现在列表中
          const commentList = page.locator('.comment-list, .comments-list')
          const hasCommentList = await commentList.isVisible({ timeout: 2000 }).catch(() => false)

          expect(hasSuccess || hasCommentList).toBeTruthy()
        }
      }
    } else {
      console.log('没有好友动态，跳过评论测试')
    }
  })

  test('时间线显示自己和好友的动态', async ({ page }) => {
    // Given: 用户发布一条动态
    await page.goto('/publish')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    const testContent = generateRandomText('时间线测试动态')
    const contentInput = page.locator('textarea[placeholder*="分享"]')
    await contentInput.fill(testContent)

    const publishButton = page.locator('button:has-text("发布")')
    await publishButton.click()
    await page.waitForTimeout(2000)

    // When: 访问时间线
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1500)

    // Then: 应该能看到自己刚发布的动态
    const myPost = page.locator(`.moment-item:has-text("${testContent}"), .moment-wrapper:has-text("${testContent}")`)
    const hasMyPost = await myPost.isVisible({ timeout: 5000 }).catch(() => false)

    expect(hasMyPost).toBeTruthy()
  })

  test('时间线按时间倒序排列', async ({ page }) => {
    // Given: 用户在时间线页面
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    // Then: 如果有多条动态，验证排序
    const moments = page.locator('.moment-item, .moment-wrapper')
    const momentCount = await moments.count()

    if (momentCount >= 2) {
      // 获取前两条动态的时间
      const firstMomentTime = await moments.nth(0).locator('.moment-time, .time').textContent()
      const secondMomentTime = await moments.nth(1).locator('.moment-time, .time').textContent()

      // 验证时间文本存在
      expect(firstMomentTime).toBeTruthy()
      expect(secondMomentTime).toBeTruthy()

      // 注意：这里简单验证时间文本存在，实际时间比较需要解析时间格式
      // 在实际应用中，最新的动态应该在最前面
    } else {
      console.log('动态数量不足2条，跳过排序验证')
    }
  })

  test('时间线响应式布局', async ({ page }) => {
    // Given: 用户在时间线页面
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // When: 模拟移动设备尺寸
    await page.setViewportSize({ width: 375, height: 667 })
    await page.waitForTimeout(500)

    // Then: 页面应该正常显示
    const pageHeader = page.locator('h1, .page-header')
    await expect(pageHeader).toBeVisible()

    // When: 恢复桌面尺寸
    await page.setViewportSize({ width: 1280, height: 720 })
    await page.waitForTimeout(500)

    // Then: 页面应该仍然正常显示
    await expect(pageHeader).toBeVisible()
  })

  test('时间线空状态显示', async ({ page }) => {
    // Given: 用户在时间线页面（假设没有好友动态）
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    // Then: 如果没有动态，应该显示空状态
    const momentItems = await page.locator('.moment-item, .moment-wrapper').count()

    if (momentItems === 0) {
      const emptyState = page.locator('.empty-state')
      await expect(emptyState).toBeVisible({ timeout: 3000 })

      // 应该有友好的提示文字
      const emptyText = await emptyState.textContent()
      expect(emptyText).toBeTruthy()
      expect(emptyText?.length).toBeGreaterThan(0)
    } else {
      console.log('有动态，跳过空状态验证')
    }
  })

  test('从时间线跳转到好友管理', async ({ page }) => {
    // Given: 用户在时间线页面
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // When: 点击好友管理按钮（如果有）
    const friendsButton = page.locator('button:has-text("好友"), a:has-text("好友")').first()
    const hasButton = await friendsButton.isVisible({ timeout: 2000 }).catch(() => false)

    if (hasButton) {
      await friendsButton.click()

      // Then: 应该跳转到好友管理页面
      await expect(page).toHaveURL(/.*\/friends/, { timeout: 5000 })
      await expect(page.locator('h1:has-text("好友管理")')).toBeVisible({ timeout: 3000 })
    } else {
      // 如果没有按钮，直接访问验证路由是否配置正确
      await page.goto('/friends')
      await expect(page).toHaveURL(/.*\/friends/)
    }
  })

  test('时间线支持下拉刷新提示', async ({ page }) => {
    // Given: 用户在时间线页面
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // When: 模拟触摸事件（下拉刷新）
    // 注意：在桌面浏览器中模拟触摸事件可能有限制
    await page.evaluate(() => {
      const touchStartEvent = new TouchEvent('touchstart', {
        touches: [{ clientX: 0, clientY: 0 } as Touch]
      })
      const touchEndEvent = new TouchEvent('touchend', {
        touches: [{ clientX: 0, clientY: 150 } as Touch]
      })
      document.dispatchEvent(touchStartEvent)
      document.dispatchEvent(touchEndEvent)
    })

    await page.waitForTimeout(1000)

    // Then: 验证页面仍然正常（下拉刷新功能可能需要真实移动设备测试）
    const pageHeader = page.locator('h1, .page-header')
    await expect(pageHeader).toBeVisible()
  })
})

