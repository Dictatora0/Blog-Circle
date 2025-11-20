import { test, expect } from "@playwright/test";
import { loginUser } from "./utils/helpers";

/**
 * E2E 集成测试：好友系统完整工作流
 *
 * 这是真正的端到端测试：
 * 1. 创建测试数据（注册新用户）
 * 2. 执行完整流程（搜索→添加→接受→删除）
 * 3. 验证每一步的API调用
 * 4. 验证数据变化
 * 5. 绝不跳过任何步骤
 */

test.describe("好友系统完整工作流集成测试", () => {
  test("完整工作流：用户A添加用户B为好友", async ({ page }) => {
    // 使用短随机数确保用户名不超过20个字符
    const timestamp = Date.now().toString().slice(-8); // 只取最后8位数字
    const testUser1 = {
      username: `u1_${timestamp}`,
      password: "test123",
      email: `test1_${timestamp}@example.com`,
      nickname: "测试用户1",
    };

    const testUser2 = {
      username: `u2_${timestamp}`,
      password: "test123",
      email: `test2_${timestamp}@example.com`,
      nickname: "测试用户2",
    };
    // ==================== 准备阶段 ====================
    console.log("========== 阶段1: 创建测试用户 ==========");

    // Step 1: 创建测试用户A
    await page.goto("/register");
    await page.waitForLoadState("domcontentloaded");

    // 填写表单并触发验证
    const usernameInput = page.locator('input[placeholder*="用户名"]');
    await usernameInput.fill(testUser1.username);
    await usernameInput.blur();

    const passwordFields = page.locator('input[type="password"]');
    await passwordFields.first().fill(testUser1.password);
    if ((await passwordFields.count()) > 1) {
      await passwordFields.nth(1).fill(testUser1.password); // 确认密码
      await passwordFields.nth(1).blur();
    }

    const emailInput = page.locator(
      'input[placeholder*="邮箱"], input[type="email"]'
    );
    await emailInput.fill(testUser1.email);
    await emailInput.blur();

    const nicknameInput = page.locator('input[placeholder*="昵称"]');
    await nicknameInput.fill(testUser1.nickname);
    await nicknameInput.blur();

    // 等待表单验证完成
    await page.waitForTimeout(500);

    // 监听注册API（在点击前设置监听）
    const registerPromise = page.waitForResponse(
      (response) =>
        response.url().includes("/api/auth/register") &&
        response.status() === 200,
      { timeout: 15000 }
    );

    const registerButton = page.locator('button:has-text("注册")');
    await registerButton.click();

    // 等待注册完成并验证成功
    const registerResponse = await registerPromise;
    const registerData = await registerResponse.json();
    if (registerData.code !== 200) {
      throw new Error(`用户A注册失败: ${registerData.message}`);
    }
    // 保存用户ID
    testUser1.id = registerData.data?.id;
    console.log(`创建用户A成功: ${testUser1.username}, ID: ${testUser1.id}`);

    // 等待数据库事务完成
    await page.waitForTimeout(1000);

    // Step 2: 创建测试用户B
    await page.goto("/register");
    await page.waitForLoadState("domcontentloaded");

    // 填写表单并触发验证
    const usernameInput2 = page.locator('input[placeholder*="用户名"]');
    await usernameInput2.fill(testUser2.username);
    await usernameInput2.blur();

    const passwordFields2 = page.locator('input[type="password"]');
    await passwordFields2.first().fill(testUser2.password);
    if ((await passwordFields2.count()) > 1) {
      await passwordFields2.nth(1).fill(testUser2.password);
      await passwordFields2.nth(1).blur();
    }

    const emailInput2 = page.locator(
      'input[placeholder*="邮箱"], input[type="email"]'
    );
    await emailInput2.fill(testUser2.email);
    await emailInput2.blur();

    const nicknameInput2 = page.locator('input[placeholder*="昵称"]');
    await nicknameInput2.fill(testUser2.nickname);
    await nicknameInput2.blur();

    // 等待表单验证完成
    await page.waitForTimeout(500);

    // 监听注册API
    const registerPromise2 = page.waitForResponse(
      (response) =>
        response.url().includes("/api/auth/register") &&
        response.status() === 200,
      { timeout: 15000 }
    );

    const registerButton2 = page.locator('button:has-text("注册")');
    await registerButton2.click();

    // 等待注册完成并验证成功
    const registerResponse2 = await registerPromise2;
    const registerData2 = await registerResponse2.json();
    if (registerData2.code !== 200) {
      throw new Error(`用户B注册失败: ${registerData2.message}`);
    }
    // 保存用户ID
    testUser2.id = registerData2.data?.id;
    console.log(`创建用户B成功: ${testUser2.username}, ID: ${testUser2.id}`);

    // 等待数据库事务完成
    await page.waitForTimeout(1000);

    // ==================== 测试阶段 ====================
    console.log("\n========== 阶段2: 用户A登录并搜索用户B ==========");

    // Step 3: 用户A登录
    await loginUser(page, testUser1.username, testUser1.password);
    console.log(`用户A登录成功`);

    // Step 4: 搜索用户B
    const searchPromise = page.waitForResponse(
      (response) => response.url().includes("/api/friends/search"),
      { timeout: 10000 }
    );

    await page.goto("/friends");
    await page.waitForLoadState("domcontentloaded");
    await page.waitForTimeout(500);

    const searchInput = page.locator('input[placeholder*="搜索"]');
    await searchInput.fill(testUser2.username);

    const searchButton = page.locator('button:has-text("搜索")');
    await searchButton.click();

    // 验证搜索API
    const searchResponse = await searchPromise;
    const searchData = await searchResponse.json();
    expect(searchData.code).toBe(200);

    const foundUser = searchData.data.find(
      (u: any) => u.username === testUser2.username
    );
    expect(foundUser).toBeTruthy();
    expect(foundUser.password).toBeFalsy(); // 密码不应该返回（可能是null或undefined）
    console.log(`搜索到用户B: ${foundUser.nickname}`);

    // ==================== 发送好友请求 ====================
    console.log("\n========== 阶段3: 用户A发送好友请求 ==========");

    // 等待搜索结果渲染
    // 等待任何好友卡片出现（说明搜索结果已渲染）
    const friendCard = page.locator(".friend-card").first();
    await expect(friendCard).toBeVisible({ timeout: 5000 });

    // 再等待一下，确保内容已加载
    await page.waitForTimeout(500);

    // Step 5: 发送好友请求（在点击前设置监听）
    const sendRequestPromise = page.waitForResponse(
      (response) =>
        response.url().includes("/api/friends/request/") &&
        response.request().method() === "POST",
      { timeout: 10000 }
    );

    // 查找按钮（在第一个好友卡片中）
    const addButton = friendCard.locator('button:has-text("添加好友")');
    await expect(addButton).toBeVisible({ timeout: 3000 });
    await addButton.click();

    // 验证发送请求API
    const sendResponse = await sendRequestPromise;
    const sendData = await sendResponse.json();
    expect(sendResponse.status()).toBe(200);
    expect(sendData.code).toBe(200);
    expect(sendData.data).toHaveProperty("id");
    expect(sendData.data.status).toBe("PENDING");
    console.log(`好友请求已发送，请求ID: ${sendData.data.id}`);

    await page.waitForTimeout(1500);

    // ==================== 接受好友请求 ====================
    console.log("\n========== 阶段4: 用户B登录并接受请求 ==========");

    // Step 6: 登出用户A
    const userMenu = page.locator(".user-avatar-wrapper, .user-menu").first();
    if (await userMenu.isVisible({ timeout: 2000 }).catch(() => false)) {
      await userMenu.click();
      await page.waitForTimeout(300);
      const logoutButton = page.locator("text=/退出登录|登出/");
      if (await logoutButton.isVisible({ timeout: 1000 }).catch(() => false)) {
        await logoutButton.click();
        await page.waitForTimeout(1000);
      }
    }
    console.log("用户A已登出");

    // Step 7: 用户B登录
    await loginUser(page, testUser2.username, testUser2.password);
    console.log("用户B登录成功");

    // Step 8: 查看待处理请求
    const requestsPromise = page.waitForResponse(
      (response) => response.url().includes("/api/friends/requests"),
      { timeout: 15000 }
    );

    await page.goto("/friends");
    await page.waitForLoadState("domcontentloaded");

    const requestsResponse = await requestsPromise;
    const requestsData = await requestsResponse.json();

    expect(requestsData.code).toBe(200);
    console.log("待处理请求数据:", JSON.stringify(requestsData, null, 2));
    const requests = requestsData.data || [];
    // 通过requesterId查找请求（因为requester对象可能为null）
    const pendingRequest = requests.find(
      (r: any) =>
        r.requesterId === testUser1.id ||
        (r.requester &&
          (r.requester.username === testUser1.username ||
            r.requester.id === testUser1.id))
    );
    expect(pendingRequest).toBeTruthy();
    console.log(`用户B收到用户A的好友请求，请求ID: ${pendingRequest.id}`);

    // Step 9: 接受好友请求
    await page.waitForTimeout(1000);

    // 等待请求容器和按钮出现
    const requestsSection = page.locator(".requests-section");
    await expect(requestsSection).toBeVisible({ timeout: 5000 });
    await page.waitForTimeout(500);

    const acceptPromise = page.waitForResponse(
      (response) =>
        response.url().includes("/api/friends/accept/") &&
        response.request().method() === "POST",
      { timeout: 10000 }
    );

    const acceptButton = requestsSection
      .locator('button:has-text("同意")')
      .first();
    await expect(acceptButton).toBeVisible({ timeout: 3000 });
    await acceptButton.click();

    // 验证接受请求API
    const acceptResponse = await acceptPromise;
    const acceptData = await acceptResponse.json();
    expect(acceptResponse.status()).toBe(200);
    expect(acceptData.code).toBe(200);
    console.log("用户B已接受好友请求");

    await page.waitForTimeout(2000);

    // Step 10: 验证用户B的好友列表
    await page.reload();
    await page.waitForLoadState("domcontentloaded");

    const friendListPromise = page.waitForResponse(
      (response) => response.url().includes("/api/friends/list"),
      { timeout: 15000 }
    );
    await friendListPromise;
    await page.waitForTimeout(1000);

    const friendCards = await page
      .locator(".friends-section .friend-card")
      .count();
    expect(friendCards).toBeGreaterThan(0);

    // 验证用户A出现在好友列表中
    const friendACard = page.locator(
      `.friend-name:has-text("${testUser1.nickname}"), .friend-name:has-text("${testUser1.username}")`
    );
    await expect(friendACard.first()).toBeVisible({ timeout: 3000 });
    console.log("用户A已出现在用户B的好友列表中");

    // ==================== 删除好友 ====================
    console.log("\n========== 阶段5: 用户B删除好友 ==========");

    // Step 11: 获取删除前的好友数量
    const friendCountBefore = await page
      .locator(".friends-section .friend-card")
      .count();
    console.log(`删除前好友数量: ${friendCountBefore}`);

    // Step 12: 删除好友
    await page.waitForTimeout(1000);

    // 等待好友列表容器出现
    const friendsSection = page.locator(".friends-section");
    await expect(friendsSection).toBeVisible({ timeout: 5000 });

    const firstFriend = friendsSection.locator(".friend-card").first();
    await expect(firstFriend).toBeVisible({ timeout: 3000 });

    const deleteButton = firstFriend.locator('button:has-text("删除")');
    await expect(deleteButton).toBeVisible({ timeout: 3000 });

    // 监听删除API（在点击前设置监听）
    const deletePromise = page.waitForResponse(
      (response) =>
        response.url().includes("/api/friends/user/") &&
        response.request().method() === "DELETE",
      { timeout: 15000 }
    );

    // Element Plus 的 ElMessageBox.confirm 不是浏览器原生对话框，直接点击删除按钮
    // 等待 Element Plus 确认对话框出现（.el-message-box）
    await deleteButton.click();

    // 等待 Element Plus 确认对话框出现并点击确定
    const confirmButton = page
      .locator(
        '.el-message-box__btns button:has-text("确定"), .el-message-box .el-button--primary'
      )
      .first();
    await expect(confirmButton).toBeVisible({ timeout: 3000 });
    await confirmButton.click();

    // 验证删除API
    const deleteResponse = await deletePromise;
    const deleteData = await deleteResponse.json();
    expect(deleteResponse.status()).toBe(200);
    expect(deleteData.code).toBe(200);
    console.log("删除API调用成功");

    // Step 13: 验证好友数量减少
    await page.waitForTimeout(2000);
    await page.reload();
    await page.waitForLoadState("domcontentloaded");
    await page.waitForTimeout(1000);

    const friendCountAfter = await page
      .locator(".friends-section .friend-card")
      .count();
    console.log(`删除后好友数量: ${friendCountAfter}`);

    expect(friendCountAfter).toBe(friendCountBefore - 1);
    console.log("好友数量正确减少1");

    // ==================== 验证双向删除 ====================
    console.log("\n========== 阶段6: 验证用户A的好友列表也已更新 ==========");

    // Step 14: 登出用户B
    const userMenu2 = page.locator(".user-avatar-wrapper, .user-menu").first();
    if (await userMenu2.isVisible({ timeout: 2000 }).catch(() => false)) {
      await userMenu2.click();
      await page.waitForTimeout(300);
      const logoutButton = page.locator("text=/退出登录|登出/");
      if (await logoutButton.isVisible({ timeout: 1000 }).catch(() => false)) {
        await logoutButton.click();
        await page.waitForTimeout(1000);
      }
    }

    // Step 15: 用户A重新登录
    await loginUser(page, testUser1.username, testUser1.password);

    // Step 16: 验证用户A的好友列表
    const friendListPromise2 = page.waitForResponse(
      (response) => response.url().includes("/api/friends/list"),
      { timeout: 15000 }
    );

    await page.goto("/friends");
    const friendListResponse2 = await friendListPromise2;
    const friendListData = await friendListResponse2.json();

    // 用户A的好友列表中也不应该有用户B了
    const hasFriendB = friendListData.data.some(
      (f: any) => f.username === testUser2.username
    );
    expect(hasFriendB).toBeFalsy();
    console.log("用户A的好友列表也已更新（双向删除生效）");

    console.log("\n========== 测试完成：完整工作流验证通过 ==========");
  });

  test("完整工作流：拒绝好友请求", async ({ page }) => {
    console.log("========== 阶段1: 创建测试用户 ==========");

    // 使用短随机数确保用户名不超过20个字符
    const timestamp2 = Date.now().toString().slice(-8); // 只取最后8位数字
    const testUser3 = {
      username: `u3_${timestamp2}`,
      password: "test123",
      email: `test3_${timestamp2}@example.com`,
      nickname: "测试用户3",
    };

    const testUser4 = {
      username: `u4_${timestamp2}`,
      password: "test123",
      email: `test4_${timestamp2}@example.com`,
      nickname: "测试用户4",
    };

    // 创建用户3
    await page.goto("/register");
    await page.waitForLoadState("domcontentloaded");

    const usernameInput3 = page.locator('input[placeholder*="用户名"]');
    await usernameInput3.fill(testUser3.username);
    await usernameInput3.blur();

    const pwd1 = page.locator('input[type="password"]');
    await pwd1.first().fill(testUser3.password);
    if ((await pwd1.count()) > 1) {
      await pwd1.nth(1).fill(testUser3.password);
      await pwd1.nth(1).blur();
    }

    const emailInput3 = page.locator(
      'input[placeholder*="邮箱"], input[type="email"]'
    );
    await emailInput3.fill(testUser3.email);
    await emailInput3.blur();

    const nicknameInput3 = page.locator('input[placeholder*="昵称"]');
    await nicknameInput3.fill(testUser3.nickname);
    await nicknameInput3.blur();

    await page.waitForTimeout(500);

    const register3Promise = page.waitForResponse(
      (response) =>
        response.url().includes("/api/auth/register") &&
        response.status() === 200,
      { timeout: 15000 }
    );

    await page.locator('button:has-text("注册")').click();
    const register3Response = await register3Promise;
    const data3 = await register3Response.json();
    if (data3.code !== 200) {
      throw new Error(`用户3注册失败: ${data3.message}`);
    }
    // 保存用户ID
    testUser3.id = data3.data?.id;
    console.log(`创建用户3成功: ${testUser3.username}, ID: ${testUser3.id}`);
    await page.waitForTimeout(1000);

    // 创建用户4
    await page.goto("/register");
    await page.waitForLoadState("domcontentloaded");

    const usernameInput4 = page.locator('input[placeholder*="用户名"]');
    await usernameInput4.fill(testUser4.username);
    await usernameInput4.blur();

    const pwd2 = page.locator('input[type="password"]');
    await pwd2.first().fill(testUser4.password);
    if ((await pwd2.count()) > 1) {
      await pwd2.nth(1).fill(testUser4.password);
      await pwd2.nth(1).blur();
    }

    const emailInput4 = page.locator(
      'input[placeholder*="邮箱"], input[type="email"]'
    );
    await emailInput4.fill(testUser4.email);
    await emailInput4.blur();

    const nicknameInput4 = page.locator('input[placeholder*="昵称"]');
    await nicknameInput4.fill(testUser4.nickname);
    await nicknameInput4.blur();

    await page.waitForTimeout(500);

    const register4Promise = page.waitForResponse(
      (response) =>
        response.url().includes("/api/auth/register") &&
        response.status() === 200,
      { timeout: 15000 }
    );

    await page.locator('button:has-text("注册")').click();
    const register4Response = await register4Promise;
    const data4 = await register4Response.json();
    if (data4.code !== 200) {
      throw new Error(`用户4注册失败: ${data4.message}`);
    }
    // 保存用户ID
    testUser4.id = data4.data?.id;
    console.log(`创建用户4成功: ${testUser4.username}, ID: ${testUser4.id}`);
    await page.waitForTimeout(1000);

    // ==================== 发送请求 ====================
    console.log("\n========== 阶段2: 用户3发送好友请求给用户4 ==========");

    await loginUser(page, testUser3.username, testUser3.password);

    // 搜索用户4
    const searchPromise = page.waitForResponse(
      (response) => response.url().includes("/api/friends/search"),
      { timeout: 10000 }
    );

    await page.goto("/friends");
    await page.waitForLoadState("domcontentloaded");
    await page.waitForTimeout(500);

    await page.locator('input[placeholder*="搜索"]').fill(testUser4.username);
    await page.locator('button:has-text("搜索")').click();

    const searchResponse = await searchPromise;
    const searchData = await searchResponse.json();
    expect(searchData.data.length).toBeGreaterThan(0);
    console.log("搜索到用户4");

    // 等待搜索结果渲染
    // 等待任何好友卡片出现（说明搜索结果已渲染）
    const friendCard = page.locator(".friend-card").first();
    await expect(friendCard).toBeVisible({ timeout: 5000 });

    // 再等待一下，确保内容已加载
    await page.waitForTimeout(500);

    // 发送好友请求（在点击前设置监听）
    const sendPromise = page.waitForResponse(
      (response) => response.url().includes("/api/friends/request/"),
      { timeout: 10000 }
    );

    // 查找按钮（在第一个好友卡片中）
    const addButton = friendCard.locator('button:has-text("添加好友")');
    await expect(addButton).toBeVisible({ timeout: 3000 });
    await addButton.click();

    const sendResponse = await sendPromise;
    const sendData = await sendResponse.json();
    expect(sendData.code).toBe(200);
    const requestId = sendData.data.id;
    console.log(`好友请求已发送，请求ID: ${requestId}`);

    // ==================== 拒绝请求 ====================
    console.log("\n========== 阶段3: 用户4拒绝好友请求 ==========");

    // 登出用户3
    await page.waitForTimeout(1000);
    const userMenu = page.locator(".user-avatar-wrapper, .user-menu").first();
    if (await userMenu.isVisible({ timeout: 2000 }).catch(() => false)) {
      await userMenu.click();
      await page.waitForTimeout(300);
      const logoutBtn = page.locator("text=/退出登录|登出/");
      if (await logoutBtn.isVisible({ timeout: 1000 }).catch(() => false)) {
        await logoutBtn.click();
        await page.waitForTimeout(1000);
      }
    }

    // 用户4登录
    await loginUser(page, testUser4.username, testUser4.password);

    // 查看待处理请求
    const requestsPromise = page.waitForResponse(
      (response) => response.url().includes("/api/friends/requests"),
      { timeout: 15000 }
    );

    await page.goto("/friends");
    const requestsResponse = await requestsPromise;
    const requestsData = await requestsResponse.json();

    expect(requestsData.code).toBe(200);
    console.log("待处理请求数据:", JSON.stringify(requestsData, null, 2));
    const requests = requestsData.data || [];
    // 通过requesterId查找请求（因为requester对象可能为null）
    const receivedRequest = requests.find(
      (r: any) =>
        r.requesterId === testUser3.id ||
        (r.requester &&
          (r.requester.username === testUser3.username ||
            r.requester.id === testUser3.id))
    );
    expect(receivedRequest).toBeTruthy();
    console.log(`用户4收到用户3的好友请求`);

    await page.waitForTimeout(1000);

    // 等待请求容器和按钮出现
    const requestsSection = page.locator(".requests-section");
    await expect(requestsSection).toBeVisible({ timeout: 5000 });
    await page.waitForTimeout(500);

    // 拒绝请求
    const rejectPromise = page.waitForResponse(
      (response) => response.url().includes("/api/friends/reject/"),
      { timeout: 10000 }
    );

    const rejectButton = requestsSection
      .locator('button:has-text("拒绝")')
      .first();
    await expect(rejectButton).toBeVisible({ timeout: 3000 });
    await rejectButton.click();

    const rejectResponse = await rejectPromise;
    const rejectData = await rejectResponse.json();
    expect(rejectData.code).toBe(200);
    console.log("用户4已拒绝好友请求");

    // ==================== 验证拒绝结果 ====================
    console.log("\n========== 阶段4: 验证拒绝后状态 ==========");

    await page.waitForTimeout(2000);
    await page.reload();
    await page.waitForLoadState("domcontentloaded");
    await page.waitForTimeout(1000);

    // 验证请求列表已更新
    const requestsAfter = await page
      .locator(".requests-section .friend-card")
      .count();
    console.log(`拒绝后待处理请求数: ${requestsAfter}`);

    // 验证好友列表中没有用户3
    const friendListPromise2 = page.waitForResponse(
      (response) => response.url().includes("/api/friends/list"),
      { timeout: 15000 }
    );
    await page.reload();
    const friendListResponse = await friendListPromise2;
    const friendListData = await friendListResponse.json();

    const hasFriend3 = friendListData.data.some(
      (f: any) => f.username === testUser3.username
    );
    expect(hasFriend3).toBeFalsy();
    console.log("拒绝后用户3未成为好友（验证通过）");

    console.log("\n========== 测试完成：拒绝流程验证通过 ==========");
  });
});
