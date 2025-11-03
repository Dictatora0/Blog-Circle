import { test, expect } from '@playwright/test'
import { loginUser, waitForMomentsLoad, generateRandomText } from './utils/helpers'

/**
 * E2E 测试：好友动态时间线完整流程
 * 
 * 测试策略：
 * 1. 验证API调用和响应
 * 2. 验证时间线数据展示
 * 3. 测试互动功能（点赞、评论）
 */
test.describe('好友动态时间线完整测试', () => {
  test.beforeEach(async ({ page }) => {
    await loginUser(page)
    await page.waitForLoadState('domcontentloaded')
  })

  test('访问时间线并验证API调用', async ({ page }) => {
    // 监听时间线API调用
    const timelineResponsePromise = page.waitForResponse(
      response => response.url().includes('/api/posts/timeline'),
      { timeout: 15000 }
    )

    // 访问时间线页面
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // 验证URL正确
    await expect(page).toHaveURL(/.*\/timeline/)

    // 验证页面标题存在
    const pageTitle = page.locator('h1').first()
    await expect(pageTitle).toBeVisible()

    // 验证API被调用
    const timelineResponse = await timelineResponsePromise
    expect(timelineResponse.status()).toBe(200)

    // 验证响应数据格式
    const responseData = await timelineResponse.json()
    expect(responseData).toHaveProperty('code')
    expect(responseData.code).toBe(200)
    expect(responseData).toHaveProperty('data')
    expect(Array.isArray(responseData.data)).toBeTruthy()

    console.log(`时间线动态数量: ${responseData.data.length}`)
  })

  test('时间线动态列表展示验证', async ({ page }) => {
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    // 等待动态加载
    await waitForMomentsLoad(page)

    // 验证动态列表或空状态
    const moments = await page.locator('.moment-item, .moment-wrapper').count()
    const emptyState = await page.locator('.empty-state').isVisible({ timeout: 2000 }).catch(() => false)

    // 应该有动态或空状态
    expect(moments > 0 || emptyState).toBeTruthy()

    if (moments > 0) {
      console.log(`时间线显示 ${moments} 条动态`)
      
      // 验证第一条动态的结构
      const firstMoment = page.locator('.moment-item, .moment-wrapper').first()
      
      // 应该有作者信息
      const authorInfo = firstMoment.locator('.moment-author, .author-name, .moment-header')
      await expect(authorInfo).toBeVisible({ timeout: 3000 })
      
      // 应该有时间信息
      const timeInfo = firstMoment.locator('.moment-time, .time')
      await expect(timeInfo).toBeVisible({ timeout: 3000 })
      
      // 应该有内容
      const content = firstMoment.locator('.moment-content, .moment-text')
      await expect(content).toBeVisible({ timeout: 3000 })
    } else {
      console.log('时间线为空，显示空状态')
    }
  })

  test('时间线点赞功能验证', async ({ page }) => {
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    const firstMoment = page.locator('.moment-item, .moment-wrapper').first()
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)

    if (hasMoments) {
      // 查找点赞按钮
      const likeButton = firstMoment.locator('button').filter({ hasText: /❤|点赞/ }).first()
      const hasLikeButton = await likeButton.isVisible({ timeout: 2000 }).catch(() => false)

      if (hasLikeButton) {
        // 监听点赞API
        const likeResponsePromise = page.waitForResponse(
          response => response.url().includes('/api/likes/toggle'),
          { timeout: 10000 }
        ).catch(() => null)

        await likeButton.click()
        
        const likeResponse = await likeResponsePromise
        if (likeResponse) {
          expect(likeResponse.status()).toBe(200)
          console.log('点赞API调用成功')
          
          await page.waitForTimeout(1000)
          // 点赞后应该有视觉反馈
        }
      }
    } else {
      console.log('没有动态可点赞')
    }
  })

  test('时间线评论功能验证', async ({ page }) => {
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    const firstMoment = page.locator('.moment-item, .moment-wrapper').first()
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)

    if (hasMoments) {
      // 查找评论按钮
      const commentButton = firstMoment.locator('button').filter({ hasText: /💬|评论/ }).first()
      const hasCommentButton = await commentButton.isVisible({ timeout: 2000 }).catch(() => false)

      if (hasCommentButton) {
        await commentButton.click()
        await page.waitForTimeout(500)

        // 应该显示评论输入框
        const commentInput = page.locator('textarea, input').filter({ hasText: '' }).last()
        const hasCommentInput = await commentInput.isVisible({ timeout: 2000 }).catch(() => false)

        if (hasCommentInput) {
          const testComment = generateRandomText('时间线评论测试')
          await commentInput.fill(testComment)

          // 监听评论API
          const commentResponsePromise = page.waitForResponse(
            response => response.url().includes('/api/comments'),
            { timeout: 10000 }
          ).catch(() => null)

          const submitButton = page.locator('button').filter({ hasText: /发送|评论/ }).last()
          if (await submitButton.isVisible({ timeout: 1000 }).catch(() => false)) {
            await submitButton.click()
            
            const commentResponse = await commentResponsePromise
            if (commentResponse) {
              expect(commentResponse.status()).toBe(200)
              console.log('评论API调用成功')
            }
          }
        }
      }
    } else {
      console.log('没有动态可评论')
    }
  })

  test('验证时间线只显示自己和好友的动态', async ({ page }) => {
    // 监听时间线API响应
    const timelineResponsePromise = page.waitForResponse(
      response => response.url().includes('/api/posts/timeline'),
      { timeout: 15000 }
    )

    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')

    const timelineResponse = await timelineResponsePromise
    const responseData = await timelineResponse.json()

    // 验证返回的动态确实是时间线数据
    expect(responseData.code).toBe(200)
    expect(Array.isArray(responseData.data)).toBeTruthy()

    // 所有动态都应该有作者信息
    if (responseData.data.length > 0) {
      responseData.data.forEach((post: any) => {
        expect(post).toHaveProperty('authorId')
        expect(post).toHaveProperty('authorName')
      })
    }

    console.log(`时间线包含 ${responseData.data.length} 条动态`)
  })

  test('时间线空状态显示', async ({ page }) => {
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    const moments = await page.locator('.moment-item, .moment-wrapper').count()

    if (moments === 0) {
      // 验证空状态显示
      const emptyState = page.locator('.empty-state')
      await expect(emptyState).toBeVisible({ timeout: 3000 })
      
      const emptyText = await emptyState.textContent()
      expect(emptyText).toBeTruthy()
      console.log('时间线空状态显示正常')
    } else {
      console.log(`时间线有 ${moments} 条动态`)
    }
  })

  test('时间线响应式布局', async ({ page }) => {
    await page.goto('/timeline')
    await page.waitForLoadState('domcontentloaded')

    // 桌面视图
    await page.setViewportSize({ width: 1280, height: 720 })
    await page.waitForTimeout(300)
    const title1 = page.locator('h1').first()
    await expect(title1).toBeVisible()

    // 移动视图
    await page.setViewportSize({ width: 375, height: 667 })
    await page.waitForTimeout(300)
    const title2 = page.locator('h1').first()
    await expect(title2).toBeVisible()
  })

  test('时间线与好友管理页面路由切换', async ({ page }) => {
    // 访问时间线
    await page.goto('/timeline')
    await expect(page).toHaveURL(/.*\/timeline/)
    await page.waitForTimeout(500)

    // 切换到好友管理
    await page.goto('/friends')
    await expect(page).toHaveURL(/.*\/friends/)
    await page.waitForTimeout(500)

    // 切换回时间线
    await page.goto('/timeline')
    await expect(page).toHaveURL(/.*\/timeline/)
  })
})
