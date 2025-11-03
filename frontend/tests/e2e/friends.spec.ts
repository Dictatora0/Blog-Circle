import { test, expect } from '@playwright/test'
import { loginUser } from './utils/helpers'

/**
 * E2E 测试：好友系统 - 严格验证版本
 * 
 * 测试原则：
 * 1. ✅ 必须验证API调用和数据变化，不能只验证UI
 * 2. ✅ 必须真实执行操作，不能取消
 * 3. ✅ 必须准备测试数据，不能跳过
 * 4. ✅ 每个断言都必须有意义
 */

test.describe('好友系统核心功能验证', () => {
  test.beforeEach(async ({ page }) => {
    await loginUser(page, 'admin', 'admin123')
    await page.waitForLoadState('domcontentloaded')
  })

  test('核心流程1：访问好友页面并验证API调用', async ({ page }) => {
    // 必须监听好友列表API和待处理请求API
    const friendListPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/list'),
      { timeout: 15000 }
    )
    
    const requestsPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/requests'),
      { timeout: 15000 }
    )

    // 访问页面
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')

    // 验证URL
    await expect(page).toHaveURL(/.*\/friends/)

    // 验证API调用
    const friendListResponse = await friendListPromise
    expect(friendListResponse.status()).toBe(200)
    const friendListData = await friendListResponse.json()
    expect(friendListData.code).toBe(200)
    expect(Array.isArray(friendListData.data)).toBeTruthy()
    console.log(`✓ 好友列表API返回 ${friendListData.data.length} 个好友`)

    const requestsResponse = await requestsPromise
    expect(requestsResponse.status()).toBe(200)
    const requestsData = await requestsResponse.json()
    expect(requestsData.code).toBe(200)
    expect(Array.isArray(requestsData.data)).toBeTruthy()
    console.log(`✓ 好友请求API返回 ${requestsData.data.length} 个待处理请求`)

    // 验证UI元素
    await expect(page.locator('h1:has-text("好友管理")').first()).toBeVisible()
    await expect(page.locator('.search-section')).toBeVisible()
    await expect(page.locator('.friends-section')).toBeVisible()
  })

  test('核心流程2：搜索用户 - 完整验证', async ({ page }) => {
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // 监听搜索API调用
    const searchResponsePromise = page.waitForResponse(
      response => response.url().includes('/api/friends/search'),
      { timeout: 10000 }
    )

    // 执行搜索
    const searchInput = page.locator('input[placeholder*="搜索"]')
    await searchInput.fill('test')
    
    const searchButton = page.locator('button:has-text("搜索")')
    await searchButton.click()

    // 验证API被调用
    const searchResponse = await searchResponsePromise
    expect(searchResponse.status()).toBe(200)
    console.log('✓ 搜索API调用成功')

    // 验证响应数据
    const responseData = await searchResponse.json()
    expect(responseData.code).toBe(200)
    expect(responseData).toHaveProperty('data')
    expect(Array.isArray(responseData.data)).toBeTruthy()
    console.log(`✓ 搜索返回 ${responseData.data.length} 个用户`)

    // 验证业务逻辑：搜索结果不应包含当前用户
    const hasCurrentUser = responseData.data.some((user: any) => user.username === 'admin')
    expect(hasCurrentUser).toBeFalsy()
    console.log('✓ 搜索结果正确排除了当前用户')

    // 验证UI更新（等待响应后UI应该更新）
    await page.waitForTimeout(1000)
  })

  test('核心流程3：空关键词搜索验证', async ({ page }) => {
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // 不输入关键词直接搜索
    const searchButton = page.locator('button:has-text("搜索")')
    
    // 不应该发起API调用（因为关键词为空）
    let apiCalled = false
    page.on('response', response => {
      if (response.url().includes('/api/friends/search')) {
        apiCalled = true
      }
    })

    await searchButton.click()
    await page.waitForTimeout(1500)

    // 应该显示警告消息，且不应该调用API
    const warningMessage = page.locator('.el-message--warning, .el-message')
    const hasWarning = await warningMessage.isVisible({ timeout: 2000 }).catch(() => false)
    
    expect(hasWarning).toBeTruthy()
    expect(apiCalled).toBeFalsy()
    console.log('✓ 空关键词搜索正确显示警告，未调用API')
  })

  test('核心流程4：获取好友列表验证数据结构', async ({ page }) => {
    // 监听好友列表API
    const friendListPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/list'),
      { timeout: 15000 }
    )

    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')

    // 验证API响应
    const friendListResponse = await friendListPromise
    const responseData = await friendListResponse.json()
    
    expect(responseData.code).toBe(200)
    console.log(`✓ 好友列表包含 ${responseData.data.length} 个好友`)

    // 验证数据结构（如果有好友）
    if (responseData.data.length > 0) {
      const firstFriend = responseData.data[0]
      expect(firstFriend).toHaveProperty('id')
      expect(firstFriend).toHaveProperty('username')
      expect(firstFriend).toHaveProperty('nickname')
      expect(firstFriend).toHaveProperty('email')
      expect(firstFriend.password).toBeUndefined() // 密码不应该返回
      console.log('✓ 好友数据结构验证通过，密码已正确过滤')

      // 验证UI显示
      await page.waitForTimeout(500)
      const friendCard = page.locator('.friends-section .friend-card').first()
      await expect(friendCard).toBeVisible()
      
      const avatar = friendCard.locator('.friend-avatar')
      await expect(avatar).toBeVisible()
      
      const name = friendCard.locator('.friend-name')
      await expect(name).toBeVisible()
      const nameText = await name.textContent()
      expect(nameText!.trim().length).toBeGreaterThan(0)
      console.log(`✓ 好友卡片UI显示正确: ${nameText}`)
    } else {
      // 验证空状态
      await page.waitForTimeout(500)
      const emptyState = page.locator('.friends-section .empty-state')
      await expect(emptyState).toBeVisible()
      console.log('✓ 空好友列表正确显示空状态')
    }
  })

  test('核心流程5：获取待处理请求验证', async ({ page }) => {
    // 监听待处理请求API
    const requestsPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/requests'),
      { timeout: 15000 }
    )

    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')

    // 验证API响应
    const requestsResponse = await requestsPromise
    const responseData = await requestsResponse.json()
    
    expect(responseData.code).toBe(200)
    console.log(`✓ 好友请求API返回 ${responseData.data.length} 个待处理请求`)

    // 验证数据结构（如果有请求）
    if (responseData.data.length > 0) {
      const firstRequest = responseData.data[0]
      expect(firstRequest).toHaveProperty('id')
      expect(firstRequest).toHaveProperty('requesterId')
      expect(firstRequest).toHaveProperty('receiverId')
      expect(firstRequest).toHaveProperty('status')
      expect(firstRequest.status).toBe('PENDING')
      
      // 验证关联的请求者信息
      expect(firstRequest).toHaveProperty('requester')
      if (firstRequest.requester) {
        expect(firstRequest.requester).toHaveProperty('nickname')
      }
      console.log('✓ 好友请求数据结构验证通过')

      // 验证UI显示
      await page.waitForTimeout(500)
      const requestsSection = page.locator('.requests-section')
      await expect(requestsSection).toBeVisible()
      
      const acceptButton = page.locator('button:has-text("同意")').first()
      const rejectButton = page.locator('button:has-text("拒绝")').first()
      await expect(acceptButton).toBeVisible()
      await expect(rejectButton).toBeVisible()
      console.log('✓ 好友请求UI显示正确')
    } else {
      console.log('✓ 当前无待处理请求（正常状态）')
    }
  })
})

/**
 * 好友系统交互功能验证
 */
test.describe('好友系统交互功能', () => {
  test.beforeEach(async ({ page }) => {
    await loginUser(page, 'admin', 'admin123')
    await page.waitForLoadState('domcontentloaded')
  })

  test('交互1：搜索并查看用户详情', async ({ page }) => {
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // 监听搜索API
    const searchResponsePromise = page.waitForResponse(
      response => response.url().includes('/api/friends/search'),
      { timeout: 10000 }
    )

    // 搜索用户（使用一个肯定存在的关键词）
    const searchInput = page.locator('input[placeholder*="搜索"]')
    await searchInput.fill('admin') // 搜索admin相关用户
    
    const searchButton = page.locator('button:has-text("搜索")')
    await searchButton.click()

    // 获取搜索结果
    const searchResponse = await searchResponsePromise
    const searchData = await searchResponse.json()
    
    expect(searchData.code).toBe(200)
    console.log(`✓ 搜索到 ${searchData.data.length} 个用户`)
    
    // 等待UI更新
    await page.waitForTimeout(1000)
  })

  test('交互2：页面响应式布局验证', async ({ page }) => {
    // 监听API确保页面完全加载
    const friendListPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/list'),
      { timeout: 15000 }
    )

    await page.goto('/friends')
    await friendListPromise // 等待数据加载

    // 桌面视图
    await page.setViewportSize({ width: 1280, height: 720 })
    await page.waitForTimeout(300)
    
    const title1 = page.locator('h1:has-text("好友管理")').first()
    await expect(title1).toBeVisible()
    
    const searchSection1 = page.locator('.search-section')
    await expect(searchSection1).toBeVisible()
    console.log('✓ 桌面布局正常')

    // 移动视图
    await page.setViewportSize({ width: 375, height: 667 })
    await page.waitForTimeout(300)
    
    const title2 = page.locator('h1:has-text("好友管理")').first()
    await expect(title2).toBeVisible()
    
    const searchInput = page.locator('input[placeholder*="搜索"]')
    await expect(searchInput).toBeVisible()
    console.log('✓ 移动布局正常')
  })
})

/**
 * 好友系统完整工作流测试
 * 这些测试验证实际的业务流程
 */
test.describe('好友系统完整工作流', () => {
  test.beforeEach(async ({ page }) => {
    await loginUser(page, 'admin', 'admin123')
    await page.waitForLoadState('domcontentloaded')
  })

  test('工作流：查看好友列表的完整数据流', async ({ page }) => {
    // Step 1: 监听API调用
    const friendListPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/list'),
      { timeout: 15000 }
    )

    // Step 2: 访问页面
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')

    // Step 3: 验证API返回的数据
    const friendListResponse = await friendListPromise
    const apiData = await friendListResponse.json()
    
    expect(apiData.code).toBe(200)
    const apiFriendCount = apiData.data.length
    console.log(`✓ API返回 ${apiFriendCount} 个好友`)

    // Step 4: 验证UI显示的数据与API一致
    await page.waitForTimeout(1000)
    const uiFriendCount = await page.locator('.friends-section .friend-card').count()
    
    expect(uiFriendCount).toBe(apiFriendCount)
    console.log(`✓ UI显示 ${uiFriendCount} 个好友，与API数据一致`)

    // Step 5: 验证好友数量显示
    const friendsHeader = page.locator('h2:has-text("我的好友")')
    const headerText = await friendsHeader.textContent()
    expect(headerText).toContain(apiFriendCount.toString())
    console.log(`✓ 页面标题显示正确的好友数量`)
  })

  test('工作流：搜索用户并验证数据过滤', async ({ page }) => {
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    // 监听搜索API
    const searchResponsePromise = page.waitForResponse(
      response => response.url().includes('/api/friends/search'),
      { timeout: 10000 }
    )

    // 搜索包含'a'的用户
    const searchInput = page.locator('input[placeholder*="搜索"]')
    await searchInput.fill('a')
    
    const searchButton = page.locator('button:has-text("搜索")')
    await searchButton.click()

    // 验证API响应
    const searchResponse = await searchResponsePromise
    const searchData = await searchResponse.json()
    
    expect(searchResponse.status()).toBe(200)
    expect(searchData.code).toBe(200)
    console.log(`✓ 搜索到 ${searchData.data.length} 个用户`)

    // 关键验证：搜索结果必须不包含当前登录用户
    const currentUserInResults = searchData.data.some((user: any) => user.username === 'admin')
    expect(currentUserInResults).toBeFalsy()
    console.log('✓ 搜索结果正确过滤了当前用户')

    // 验证每个搜索结果都不包含密码
    searchData.data.forEach((user: any) => {
      expect(user.password).toBeUndefined()
    })
    console.log('✓ 搜索结果正确隐藏了密码字段')
  })

  test('工作流：验证好友列表不返回密码', async ({ page }) => {
    // 监听好友列表API
    const friendListPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/list'),
      { timeout: 15000 }
    )

    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')

    // 获取API返回的数据
    const friendListResponse = await friendListPromise
    const friendListData = await friendListResponse.json()
    
    // 验证数据安全性：所有好友数据都不应包含密码
    friendListData.data.forEach((friend: any, index: number) => {
      expect(friend.password).toBeUndefined()
      console.log(`✓ 好友${index + 1}的密码已正确过滤`)
    })
    
    console.log('✓ 好友列表数据安全验证通过')
  })

  test('工作流：验证待处理请求数据结构', async ({ page }) => {
    // 监听待处理请求API
    const requestsPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/requests'),
      { timeout: 15000 }
    )

    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')

    // 获取API返回的数据
    const requestsResponse = await requestsPromise
    const requestsData = await requestsResponse.json()
    
    expect(requestsData.code).toBe(200)
    console.log(`✓ 收到 ${requestsData.data.length} 个好友请求`)

    // 验证每个请求的数据结构
    requestsData.data.forEach((request: any, index: number) => {
      expect(request).toHaveProperty('id')
      expect(request).toHaveProperty('requesterId')
      expect(request).toHaveProperty('receiverId')
      expect(request).toHaveProperty('status')
      expect(request.status).toBe('PENDING')
      
      // 验证关联的请求者信息
      if (request.requester) {
        expect(request.requester).toHaveProperty('nickname')
        expect(request.requester).toHaveProperty('username')
        console.log(`✓ 请求${index + 1}的发起人信息完整: ${request.requester.nickname}`)
      }
    })
  })
})

/**
 * 好友系统API端点完整性测试
 */
test.describe('好友系统API端点验证', () => {
  test.beforeEach(async ({ page }) => {
    await loginUser(page, 'admin', 'admin123')
  })

  test('API端点1：GET /api/friends/list', async ({ page }) => {
    const responsePromise = page.waitForResponse(
      response => response.url().includes('/api/friends/list'),
      { timeout: 15000 }
    )

    await page.goto('/friends')
    
    const response = await responsePromise
    expect(response.status()).toBe(200)
    expect(response.request().method()).toBe('GET')
    
    const data = await response.json()
    expect(data.code).toBe(200)
    expect(Array.isArray(data.data)).toBeTruthy()
    console.log('✓ GET /api/friends/list 端点正常')
  })

  test('API端点2：GET /api/friends/requests', async ({ page }) => {
    const responsePromise = page.waitForResponse(
      response => response.url().includes('/api/friends/requests'),
      { timeout: 15000 }
    )

    await page.goto('/friends')
    
    const response = await responsePromise
    expect(response.status()).toBe(200)
    expect(response.request().method()).toBe('GET')
    
    const data = await response.json()
    expect(data.code).toBe(200)
    expect(Array.isArray(data.data)).toBeTruthy()
    console.log('✓ GET /api/friends/requests 端点正常')
  })

  test('API端点3：GET /api/friends/search', async ({ page }) => {
    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    const searchResponsePromise = page.waitForResponse(
      response => response.url().includes('/api/friends/search'),
      { timeout: 10000 }
    )

    const searchInput = page.locator('input[placeholder*="搜索"]')
    await searchInput.fill('test')
    
    const searchButton = page.locator('button:has-text("搜索")')
    await searchButton.click()

    const response = await searchResponsePromise
    expect(response.status()).toBe(200)
    expect(response.request().method()).toBe('GET')
    
    const data = await response.json()
    expect(data.code).toBe(200)
    expect(Array.isArray(data.data)).toBeTruthy()
    console.log('✓ GET /api/friends/search 端点正常')
  })
})
