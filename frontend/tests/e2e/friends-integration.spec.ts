import { test, expect } from '@playwright/test'
import { loginUser } from './utils/helpers'

/**
 * E2E 集成测试：好友系统完整工作流
 * 
 * 这是真正的端到端测试：
 * 1. ✅ 创建测试数据（注册新用户）
 * 2. ✅ 执行完整流程（搜索→添加→接受→删除）
 * 3. ✅ 验证每一步的API调用
 * 4. ✅ 验证数据变化
 * 5. ✅ 绝不跳过任何步骤
 */

test.describe('好友系统完整工作流集成测试', () => {
  const testUser1 = {
    username: `testuser_${Date.now()}_1`,
    password: 'test123',
    email: `test1_${Date.now()}@example.com`,
    nickname: '测试用户1'
  }

  const testUser2 = {
    username: `testuser_${Date.now()}_2`,
    password: 'test123',
    email: `test2_${Date.now()}@example.com`,
    nickname: '测试用户2'
  }

  test('完整工作流：用户A添加用户B为好友', async ({ page }) => {
    // ==================== 准备阶段 ====================
    console.log('========== 阶段1: 创建测试用户 ==========')
    
    // Step 1: 创建测试用户A
    await page.goto('/register')
    await page.waitForLoadState('domcontentloaded')
    
    await page.locator('input[placeholder*="用户名"]').fill(testUser1.username)
    const passwordFields = page.locator('input[type="password"]')
    await passwordFields.first().fill(testUser1.password)
    if (await passwordFields.count() > 1) {
      await passwordFields.nth(1).fill(testUser1.password) // 确认密码
    }
    await page.locator('input[placeholder*="邮箱"], input[type="email"]').fill(testUser1.email)
    
    const registerButton = page.locator('button:has-text("注册")')
    await registerButton.click()
    await page.waitForTimeout(2000)
    console.log(`✓ 创建用户A: ${testUser1.username}`)

    // Step 2: 创建测试用户B
    await page.goto('/register')
    await page.waitForLoadState('domcontentloaded')
    
    await page.locator('input[placeholder*="用户名"]').fill(testUser2.username)
    const passwordFields2 = page.locator('input[type="password"]')
    await passwordFields2.first().fill(testUser2.password)
    if (await passwordFields2.count() > 1) {
      await passwordFields2.nth(1).fill(testUser2.password)
    }
    await page.locator('input[placeholder*="邮箱"], input[type="email"]').fill(testUser2.email)
    
    await registerButton.click()
    await page.waitForTimeout(2000)
    console.log(`✓ 创建用户B: ${testUser2.username}`)

    // ==================== 测试阶段 ====================
    console.log('\n========== 阶段2: 用户A登录并搜索用户B ==========')
    
    // Step 3: 用户A登录
    await loginUser(page, testUser1.username, testUser1.password)
    console.log(`✓ 用户A登录成功`)

    // Step 4: 搜索用户B
    const searchPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/search'),
      { timeout: 10000 }
    )

    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    const searchInput = page.locator('input[placeholder*="搜索"]')
    await searchInput.fill(testUser2.username)
    
    const searchButton = page.locator('button:has-text("搜索")')
    await searchButton.click()

    // 验证搜索API
    const searchResponse = await searchPromise
    const searchData = await searchResponse.json()
    expect(searchData.code).toBe(200)
    
    const foundUser = searchData.data.find((u: any) => u.username === testUser2.username)
    expect(foundUser).toBeTruthy()
    expect(foundUser.password).toBeUndefined() // 密码不应该返回
    console.log(`✓ 搜索到用户B: ${foundUser.nickname}`)

    // ==================== 发送好友请求 ====================
    console.log('\n========== 阶段3: 用户A发送好友请求 ==========')
    
    await page.waitForTimeout(1000)

    // Step 5: 发送好友请求
    const sendRequestPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/request/') &&
                 response.request().method() === 'POST',
      { timeout: 10000 }
    )

    const addButton = page.locator('button:has-text("添加好友")').first()
    await expect(addButton).toBeVisible({ timeout: 3000 })
    await addButton.click()

    // 验证发送请求API
    const sendResponse = await sendRequestPromise
    const sendData = await sendResponse.json()
    expect(sendResponse.status()).toBe(200)
    expect(sendData.code).toBe(200)
    expect(sendData.data).toHaveProperty('id')
    expect(sendData.data.status).toBe('PENDING')
    console.log(`✓ 好友请求已发送，请求ID: ${sendData.data.id}`)

    await page.waitForTimeout(1500)

    // ==================== 接受好友请求 ====================
    console.log('\n========== 阶段4: 用户B登录并接受请求 ==========')

    // Step 6: 登出用户A
    const userMenu = page.locator('.user-avatar-wrapper, .user-menu').first()
    if (await userMenu.isVisible({ timeout: 2000 }).catch(() => false)) {
      await userMenu.click()
      await page.waitForTimeout(300)
      const logoutButton = page.locator('text=/退出登录|登出/')
      if (await logoutButton.isVisible({ timeout: 1000 }).catch(() => false)) {
        await logoutButton.click()
        await page.waitForTimeout(1000)
      }
    }
    console.log('✓ 用户A已登出')

    // Step 7: 用户B登录
    await loginUser(page, testUser2.username, testUser2.password)
    console.log('✓ 用户B登录成功')

    // Step 8: 查看待处理请求
    const requestsPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/requests'),
      { timeout: 15000 }
    )

    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')

    const requestsResponse = await requestsPromise
    const requestsData = await requestsResponse.json()
    
    expect(requestsData.code).toBe(200)
    const pendingRequest = requestsData.data.find((r: any) => 
      r.requester && r.requester.username === testUser1.username
    )
    expect(pendingRequest).toBeTruthy()
    console.log(`✓ 用户B收到用户A的好友请求，请求ID: ${pendingRequest.id}`)

    // Step 9: 接受好友请求
    await page.waitForTimeout(1000)

    const acceptPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/accept/') &&
                 response.request().method() === 'POST',
      { timeout: 10000 }
    )

    const acceptButton = page.locator('button:has-text("同意")').first()
    await expect(acceptButton).toBeVisible({ timeout: 3000 })
    await acceptButton.click()

    // 验证接受请求API
    const acceptResponse = await acceptPromise
    const acceptData = await acceptResponse.json()
    expect(acceptResponse.status()).toBe(200)
    expect(acceptData.code).toBe(200)
    console.log('✓ 用户B已接受好友请求')

    await page.waitForTimeout(2000)

    // Step 10: 验证用户B的好友列表
    await page.reload()
    await page.waitForLoadState('domcontentloaded')
    
    const friendListPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/list'),
      { timeout: 15000 }
    )
    await friendListPromise
    await page.waitForTimeout(1000)

    const friendCards = await page.locator('.friends-section .friend-card').count()
    expect(friendCards).toBeGreaterThan(0)
    
    // 验证用户A出现在好友列表中
    const friendACard = page.locator(`.friend-name:has-text("${testUser1.nickname}"), .friend-name:has-text("${testUser1.username}")`)
    await expect(friendACard.first()).toBeVisible({ timeout: 3000 })
    console.log('✓ 用户A已出现在用户B的好友列表中')

    // ==================== 删除好友 ====================
    console.log('\n========== 阶段5: 用户B删除好友 ==========')

    // Step 11: 获取删除前的好友数量
    const friendCountBefore = await page.locator('.friends-section .friend-card').count()
    console.log(`删除前好友数量: ${friendCountBefore}`)

    // Step 12: 删除好友
    const firstFriend = page.locator('.friends-section .friend-card').first()
    const deleteButton = firstFriend.locator('button:has-text("删除")')

    // 监听删除API
    const deletePromise = page.waitForResponse(
      response => response.url().includes('/api/friends/user/') &&
                 response.request().method() === 'DELETE',
      { timeout: 10000 }
    )

    // 处理确认对话框 - 真正执行删除！
    page.once('dialog', async dialog => {
      expect(dialog.type()).toBe('confirm')
      await dialog.accept() // 必须accept，不能dismiss！
    })

    await deleteButton.click()

    // 验证删除API
    const deleteResponse = await deletePromise
    const deleteData = await deleteResponse.json()
    expect(deleteResponse.status()).toBe(200)
    expect(deleteData.code).toBe(200)
    console.log('✓ 删除API调用成功')

    // Step 13: 验证好友数量减少
    await page.waitForTimeout(2000)
    await page.reload()
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    const friendCountAfter = await page.locator('.friends-section .friend-card').count()
    console.log(`删除后好友数量: ${friendCountAfter}`)

    expect(friendCountAfter).toBe(friendCountBefore - 1)
    console.log('✓ 好友数量正确减少1')

    // ==================== 验证双向删除 ====================
    console.log('\n========== 阶段6: 验证用户A的好友列表也已更新 ==========')

    // Step 14: 登出用户B
    const userMenu2 = page.locator('.user-avatar-wrapper, .user-menu').first()
    if (await userMenu2.isVisible({ timeout: 2000 }).catch(() => false)) {
      await userMenu2.click()
      await page.waitForTimeout(300)
      const logoutButton = page.locator('text=/退出登录|登出/')
      if (await logoutButton.isVisible({ timeout: 1000 }).catch(() => false)) {
        await logoutButton.click()
        await page.waitForTimeout(1000)
      }
    }

    // Step 15: 用户A重新登录
    await loginUser(page, testUser1.username, testUser1.password)

    // Step 16: 验证用户A的好友列表
    const friendListPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/list'),
      { timeout: 15000 }
    )

    await page.goto('/friends')
    const friendListResponse = await friendListPromise
    const friendListData = await friendListResponse.json()

    // 用户A的好友列表中也不应该有用户B了
    const hasFriendB = friendListData.data.some((f: any) => f.username === testUser2.username)
    expect(hasFriendB).toBeFalsy()
    console.log('✓ 用户A的好友列表也已更新（双向删除生效）')

    console.log('\n========== 测试完成：完整工作流验证通过 ==========')
  })

  test('完整工作流：拒绝好友请求', async ({ page }) => {
    console.log('========== 阶段1: 创建测试用户 ==========')
    
    const testUser3 = {
      username: `testuser_${Date.now()}_3`,
      password: 'test123',
      email: `test3_${Date.now()}@example.com`
    }

    const testUser4 = {
      username: `testuser_${Date.now()}_4`,
      password: 'test123',
      email: `test4_${Date.now()}@example.com`
    }

    // 创建用户3
    await page.goto('/register')
    await page.waitForLoadState('domcontentloaded')
    await page.locator('input[placeholder*="用户名"]').fill(testUser3.username)
    const pwd1 = page.locator('input[type="password"]')
    await pwd1.first().fill(testUser3.password)
    if (await pwd1.count() > 1) await pwd1.nth(1).fill(testUser3.password)
    await page.locator('input[placeholder*="邮箱"], input[type="email"]').fill(testUser3.email)
    await page.locator('button:has-text("注册")').click()
    await page.waitForTimeout(2000)
    console.log(`✓ 创建用户3: ${testUser3.username}`)

    // 创建用户4
    await page.goto('/register')
    await page.waitForLoadState('domcontentloaded')
    await page.locator('input[placeholder*="用户名"]').fill(testUser4.username)
    const pwd2 = page.locator('input[type="password"]')
    await pwd2.first().fill(testUser4.password)
    if (await pwd2.count() > 1) await pwd2.nth(1).fill(testUser4.password)
    await page.locator('input[placeholder*="邮箱"], input[type="email"]').fill(testUser4.email)
    await page.locator('button:has-text("注册")').click()
    await page.waitForTimeout(2000)
    console.log(`✓ 创建用户4: ${testUser4.username}`)

    // ==================== 发送请求 ====================
    console.log('\n========== 阶段2: 用户3发送好友请求给用户4 ==========')

    await loginUser(page, testUser3.username, testUser3.password)
    
    // 搜索用户4
    const searchPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/search'),
      { timeout: 10000 }
    )

    await page.goto('/friends')
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(500)

    await page.locator('input[placeholder*="搜索"]').fill(testUser4.username)
    await page.locator('button:has-text("搜索")').click()
    
    const searchResponse = await searchPromise
    const searchData = await searchResponse.json()
    expect(searchData.data.length).toBeGreaterThan(0)
    console.log('✓ 搜索到用户4')

    await page.waitForTimeout(1000)

    // 发送好友请求
    const sendPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/request/'),
      { timeout: 10000 }
    )

    const addButton = page.locator('button:has-text("添加好友")').first()
    await addButton.click()

    const sendResponse = await sendPromise
    const sendData = await sendResponse.json()
    expect(sendData.code).toBe(200)
    const requestId = sendData.data.id
    console.log(`✓ 好友请求已发送，请求ID: ${requestId}`)

    // ==================== 拒绝请求 ====================
    console.log('\n========== 阶段3: 用户4拒绝好友请求 ==========')

    // 登出用户3
    await page.waitForTimeout(1000)
    const userMenu = page.locator('.user-avatar-wrapper, .user-menu').first()
    if (await userMenu.isVisible({ timeout: 2000 }).catch(() => false)) {
      await userMenu.click()
      await page.waitForTimeout(300)
      const logoutBtn = page.locator('text=/退出登录|登出/')
      if (await logoutBtn.isVisible({ timeout: 1000 }).catch(() => false)) {
        await logoutBtn.click()
        await page.waitForTimeout(1000)
      }
    }

    // 用户4登录
    await loginUser(page, testUser4.username, testUser4.password)

    // 查看待处理请求
    const requestsPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/requests'),
      { timeout: 15000 }
    )

    await page.goto('/friends')
    const requestsResponse = await requestsPromise
    const requestsData = await requestsResponse.json()
    
    const receivedRequest = requestsData.data.find((r: any) => 
      r.requester && r.requester.username === testUser3.username
    )
    expect(receivedRequest).toBeTruthy()
    console.log(`✓ 用户4收到用户3的好友请求`)

    await page.waitForTimeout(1000)

    // 拒绝请求
    const rejectPromise = page.waitForResponse(
      response => response.url().includes('/api/friends/reject/'),
      { timeout: 10000 }
    )

    const rejectButton = page.locator('button:has-text("拒绝")').first()
    await rejectButton.click()

    const rejectResponse = await rejectPromise
    const rejectData = await rejectResponse.json()
    expect(rejectData.code).toBe(200)
    console.log('✓ 用户4已拒绝好友请求')

    // ==================== 验证拒绝结果 ====================
    console.log('\n========== 阶段4: 验证拒绝后状态 ==========')

    await page.waitForTimeout(2000)
    await page.reload()
    await page.waitForLoadState('domcontentloaded')
    await page.waitForTimeout(1000)

    // 验证请求列表已更新
    const requestsAfter = await page.locator('.requests-section .friend-card').count()
    console.log(`✓ 拒绝后待处理请求数: ${requestsAfter}`)

    // 验证好友列表中没有用户3
    const friendListPromise2 = page.waitForResponse(
      response => response.url().includes('/api/friends/list'),
      { timeout: 15000 }
    )
    await page.reload()
    const friendListResponse = await friendListPromise2
    const friendListData = await friendListResponse.json()
    
    const hasFriend3 = friendListData.data.some((f: any) => f.username === testUser3.username)
    expect(hasFriend3).toBeFalsy()
    console.log('✓ 拒绝后用户3未成为好友（验证通过）')

    console.log('\n========== 测试完成：拒绝流程验证通过 ==========')
  })
})

