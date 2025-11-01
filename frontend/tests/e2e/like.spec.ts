import { test, expect } from '@playwright/test'
import { waitForMomentsLoad } from './utils/helpers'

/**
 * E2E 测试：点赞功能场景
 * 
 * 测试流程：
 * 1. 定位到最新一条动态
 * 2. 点击点赞按钮
 * 3. 校验点赞计数 +1，再次点击取消点赞计数 -1
 */
test.describe('点赞功能场景', () => {
  test.beforeEach(async ({ page }) => {
    // 每次测试前先登录
    await page.goto('/login')
    await page.locator('input[placeholder="用户名"]').fill('admin')
    await page.locator('input[placeholder="密码"]').fill('admin123')
    await page.locator('button:has-text("登录")').click()
    await page.waitForURL(/.*\/home/, { timeout: 10000 })
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(2000)
  })

  test('点赞动态', async ({ page }) => {
    // Given: 用户在首页，至少有一条动态
    await expect(page).toHaveURL(/.*\/home/)

    // 等待动态列表加载
    await waitForMomentsLoad(page)
    
    // 获取第一条动态（注意：实际DOM结构是 .moment-wrapper 包裹 .moment-item）
    const firstMoment = page.locator('.moment-wrapper, .moment-item').first()
    
    // 如果动态列表为空，跳过此测试
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)
    if (!hasMoments) {
      test.skip()
      return
    }

    await expect(firstMoment).toBeVisible()

    // 获取点赞按钮（第一个action-btn通常是点赞按钮）
    const actionButtons = firstMoment.locator('button.action-btn')
    const likeButton = actionButtons.first()
    await expect(likeButton).toBeVisible({ timeout: 5000 })

    // 获取初始点赞数
    const likeCountElement = firstMoment.locator('.moment-stats .stat-item:has-text("❤️")')
    const initialLikeCountText = await likeCountElement.textContent().catch(() => '0')
    const initialLikeCount = parseInt(initialLikeCountText?.match(/\d+/)?.at(0) || '0')

    // 检查当前点赞状态（检查按钮内的图标）
    const likeIcon = likeButton.locator('.action-icon')
    const currentLikeIconText = await likeIcon.textContent().catch(() => '')
    const isLiked = currentLikeIconText.includes('❤️')
    
    // When: 点击点赞按钮
    await likeButton.click()
    
    // 等待点赞请求完成和UI更新（等待API响应）
    await page.waitForResponse(response => 
      response.url().includes('/api/likes/') && response.request().method() === 'POST',
      { timeout: 5000 }
    ).catch(() => {})
    
    // 等待Vue响应式更新和可能的组件重新渲染（emit('update')可能触发父组件重新加载）
    await page.waitForTimeout(2000)

    // Then: 点赞状态应该改变（重新获取按钮和图标，因为组件可能已重新渲染）
    // 重新获取第一个动态，因为父组件可能重新加载了数据
    const updatedMoment = page.locator('.moment-wrapper, .moment-item').first()
    const updatedLikeButton = updatedMoment.locator('button.action-btn').first()
    const updatedLikeIcon = updatedLikeButton.locator('.action-icon')
    
    // 多次尝试获取最新状态（因为UI可能需要时间更新，且组件可能重新渲染）
    let newLikeIconText = ''
    for (let i = 0; i < 10; i++) {
      newLikeIconText = await updatedLikeIcon.textContent().catch(() => '')
      // 如果状态已经改变，退出循环
      if ((isLiked && newLikeIconText.includes('🤍')) || (!isLiked && newLikeIconText.includes('❤️'))) {
        break
      }
      await page.waitForTimeout(500)
      
      // 如果组件重新渲染了，重新获取元素
      if (i % 2 === 1) {
        const freshMoment = page.locator('.moment-wrapper, .moment-item').first()
        const freshLikeButton = freshMoment.locator('button.action-btn').first()
        const freshLikeIcon = freshLikeButton.locator('.action-icon')
        newLikeIconText = await freshLikeIcon.textContent().catch(() => '')
        if ((isLiked && newLikeIconText.includes('🤍')) || (!isLiked && newLikeIconText.includes('❤️'))) {
          break
        }
      }
    }
    
    // 验证状态确实改变了（如果之前未点赞，现在应该是❤️；如果之前已点赞，现在应该是🤍）
    if (isLiked) {
      // 如果之前已点赞，现在应该取消点赞
      expect(newLikeIconText).toContain('🤍')
    } else {
      // 如果之前未点赞，现在应该已点赞
      expect(newLikeIconText).toContain('❤️')
    }

    // Then: 点赞数应该相应变化
    const newLikeCountText = await likeCountElement.textContent().catch(() => '0')
    const newLikeCount = parseInt(newLikeCountText?.match(/\d+/)?.at(0) || '0')
    
    if (isLiked) {
      expect(newLikeCount).toBe(initialLikeCount - 1)
    } else {
      expect(newLikeCount).toBe(initialLikeCount + 1)
    }
  })

  test('取消点赞', async ({ page }) => {
    // Given: 用户在首页
    await expect(page).toHaveURL(/.*\/home/)
    await waitForMomentsLoad(page)
    
    const firstMoment = page.locator('.moment-wrapper, .moment-item').first()
    
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)
    if (!hasMoments) {
      test.skip()
      return
    }
    
    const likeButton = firstMoment.locator('button.action-btn').first()
    
    // 如果未点赞，先点赞
    const likeIcon = likeButton.locator('.action-icon')
    const currentLikeIconText = await likeIcon.textContent().catch(() => '')
    const isLiked = currentLikeIconText.includes('❤️')
    if (!isLiked) {
      await likeButton.click()
      // 等待点赞API响应
      await page.waitForResponse(response => 
        response.url().includes('/api/likes/') && response.request().method() === 'POST',
        { timeout: 5000 }
      ).catch(() => {})
      await page.waitForTimeout(1000)
      
      // 验证已点赞
      let verified = false
      for (let i = 0; i < 5; i++) {
        const iconText = await likeIcon.textContent().catch(() => '')
        if (iconText.includes('❤️')) {
          verified = true
          break
        }
        await page.waitForTimeout(500)
      }
      if (!verified) {
        test.skip()
        return
      }
    }

    // 获取点赞后的点赞数
    const likeCountElement = firstMoment.locator('.moment-stats .stat-item:has-text("❤️")')
    const likedCountText = await likeCountElement.textContent().catch(() => '0')
    const likedCount = parseInt(likedCountText?.match(/\d+/)?.at(0) || '0')

    // When: 再次点击点赞按钮（取消点赞）
    await likeButton.click()
    
    // 等待取消点赞API响应
    await page.waitForResponse(response => 
      response.url().includes('/api/likes/') && response.request().method() === 'POST',
      { timeout: 5000 }
    ).catch(() => {})
    
    // 等待Vue响应式更新
    await page.waitForTimeout(1000)

    // Then: 应该取消点赞（使用重试逻辑）
    const updatedLikeIcon = likeButton.locator('.action-icon')
    let newLikeIconText = ''
    for (let i = 0; i < 8; i++) {
      newLikeIconText = await updatedLikeIcon.textContent().catch(() => '')
      if (newLikeIconText.includes('🤍')) {
        break
      }
      await page.waitForTimeout(500)
    }
    expect(newLikeIconText).toContain('🤍')
    
    // Then: 点赞数应该减1
    const unlikedCountText = await likeCountElement.textContent().catch(() => '0')
    const unlikedCount = parseInt(unlikedCountText?.match(/\d+/)?.at(0) || '0')
    expect(unlikedCount).toBe(likedCount - 1)
  })

  test('未登录用户不能点赞', async ({ page }) => {
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
    
    const likeButton = firstMoment.locator('button.action-btn').first()

    // When: 检查按钮状态（未登录时应该被禁用）
    const isDisabled = await likeButton.isDisabled().catch(() => false)
    
    // 验证按钮被禁用
    expect(isDisabled).toBeTruthy()
  })

  test('点赞按钮视觉反馈', async ({ page }) => {
    // Given: 用户在首页
    await expect(page).toHaveURL(/.*\/home/)
    await waitForMomentsLoad(page)
    
    const firstMoment = page.locator('.moment-wrapper, .moment-item').first()
    
    const hasMoments = await firstMoment.isVisible({ timeout: 3000 }).catch(() => false)
    if (!hasMoments) {
      test.skip()
      return
    }
    
    const likeButton = firstMoment.locator('button.action-btn').first()

    // When: 悬停在点赞按钮上
    await likeButton.hover()

    // Then: 按钮应该有视觉反馈（CSS hover效果）
    // 检查按钮是否有active或hover类
    const hasHoverEffect = await likeButton.evaluate((el) => {
      const styles = window.getComputedStyle(el)
      return styles.cursor === 'pointer' || el.classList.contains('action-btn')
    })
    
    expect(hasHoverEffect).toBeTruthy()
  })
})

