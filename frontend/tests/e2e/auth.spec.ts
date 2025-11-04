/**
 * 用户认证模块 E2E 测试
 * 覆盖注册、登录、登出、权限校验等场景
 */

import { test, expect } from '@playwright/test';
import { createTestUser, invalidData } from '../fixtures/test-data';
import { AuthHelpers } from '../fixtures/auth-helpers';

test.describe('用户认证模块', () => {
  test.beforeEach(async ({ page }) => {
    // 先导航到首页，确保在有效的上下文中
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // 清除所有 cookies 和 localStorage
    await page.context().clearCookies();
    await page.evaluate(() => {
      try {
        localStorage.clear();
        sessionStorage.clear();
      } catch (e) {
        // 忽略错误
      }
    });
  });

  test.describe('用户注册', () => {
    test('成功注册新用户', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const user = createTestUser(1);

      // 访问注册页
      await page.goto('/register');
      await expect(page).toHaveURL('/register');
      
      // 等待 Vue 应用加载完成
      await page.waitForLoadState('networkidle');
      await page.waitForSelector('.register-page', { state: 'visible', timeout: 15000 });
      
      // 等待页面关键元素加载
      await expect(page.getByText('Blog Circle')).toBeVisible({ timeout: 10000 });

      // Element Plus 的 input 实际在 .el-input__inner 内
      // 等待表单输入框可用
      await page.waitForSelector('.el-input__inner[placeholder="用户名"]', { state: 'visible', timeout: 10000 });
      
      // 填写注册表单
      await page.locator('.el-input__inner[placeholder="用户名"]').fill(user.username);
      await page.locator('.el-input__inner[placeholder="密码"]').first().fill(user.password);
      await page.locator('.el-input__inner[placeholder="确认密码"]').fill(user.password);
      await page.locator('.el-input__inner[placeholder="邮箱"]').fill(user.email);
      await page.locator('.el-input__inner[placeholder="昵称"]').fill(user.nickname);

      // 提交注册（等待注册 API 响应）
      const [response] = await Promise.all([
        page.waitForResponse(resp => resp.url().includes('/api/auth/register') && resp.status() === 200, { timeout: 15000 }),
        page.locator('button.el-button--primary:has-text("注册")').click()
      ]);

      // 等待页面跳转到登录页
      await page.waitForURL('/login', { timeout: 10000 });
      
      // 验证跳转成功
      await expect(page).toHaveURL('/login');
      await expect(page.getByText('欢迎回来')).toBeVisible({ timeout: 5000 });
    });

    test('用户名重复时注册失败', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const user = createTestUser(2);

      // 先注册一次
      await auth.registerViaAPI(user);

      // 再次尝试注册相同用户名
      await page.goto('/register');
      await page.waitForLoadState('networkidle');
      await page.waitForSelector('.register-form', { state: 'visible', timeout: 10000 });
      
      await page.getByPlaceholder('用户名').fill(user.username);
      await page.getByPlaceholder('密码').first().fill(user.password);
      await page.getByPlaceholder('确认密码').fill(user.password);
      await page.getByPlaceholder('邮箱').fill('another' + user.email);
      await page.getByPlaceholder('昵称').fill(user.nickname);

      await page.getByRole('button', { name: '注册' }).click();

      // 应该显示错误消息（用户名已存在）
      await expect(page.locator('text=/用户名已存在|注册失败/')).toBeVisible({ timeout: 5000 });
    });

    test('邮箱格式无效时注册失败', async ({ page }) => {
      const user = createTestUser(3);

      await page.goto('/register');
      await page.waitForLoadState('networkidle');
      await page.waitForSelector('.register-form', { state: 'visible', timeout: 10000 });
      
      await page.getByPlaceholder('用户名').fill(user.username);
      await page.getByPlaceholder('密码').first().fill(user.password);
      await page.getByPlaceholder('确认密码').fill(user.password);
      await page.getByPlaceholder('邮箱').fill(invalidData.invalidEmail);  // 使用无效邮箱
      await page.getByPlaceholder('昵称').fill(user.nickname);

      // 注册按钮应该禁用或显示验证错误
      const registerButton = page.getByRole('button', { name: '注册' });
      
      // 尝试点击注册
      await registerButton.click();
      
      // 应该留在注册页面
      await expect(page).toHaveURL('/register');
    });

    test('密码不一致时注册失败', async ({ page }) => {
      const user = createTestUser(10);

      await page.goto('/register');
      await page.waitForLoadState('networkidle');
      await page.waitForSelector('.register-form', { state: 'visible', timeout: 10000 });
      
      await page.getByPlaceholder('用户名').fill(user.username);
      await page.getByPlaceholder('密码').first().fill(user.password);
      await page.getByPlaceholder('确认密码').fill('DifferentPassword123!');
      await page.getByPlaceholder('邮箱').fill(user.email);
      await page.getByPlaceholder('昵称').fill(user.nickname);

      await page.getByRole('button', { name: '注册' }).click();

      // 应该显示密码不一致的错误
      await expect(page).toHaveURL('/register');
    });
  });

  test.describe('用户登录', () => {
    test('使用正确凭据登录成功', async ({ page, request }) => {
      // 监听console消息
      page.on('console', msg => console.log(`浏览器console [${msg.type()}]:`, msg.text()));
      
      const auth = new AuthHelpers(page, request);
      const user = createTestUser(4);

      // 先注册用户
      await auth.registerViaAPI(user);

      // 访问登录页
      await page.goto('/login');
      await expect(page).toHaveURL('/login');
      await page.waitForLoadState('networkidle');
      await page.waitForSelector('.login-form', { state: 'visible', timeout: 10000 });

      // 填写登录表单
      await page.getByPlaceholder('用户名').fill(user.username);
      await page.getByPlaceholder('密码').fill(user.password);

      // 等待一下确保输入完成
      await page.waitForTimeout(500);

      // 等待登录API响应
      const loginPromise = page.waitForResponse(
        response => response.url().includes('/api/auth/login') && response.request().method() === 'POST',
        { timeout: 15000 }
      );

      // 确保登录按钮可见且可点击
      const loginButton = page.getByRole('button', { name: '登录' });
      await loginButton.waitFor({ state: 'visible' });
      await expect(loginButton).toBeEnabled();
      
      console.log('即将点击登录按钮');
      await loginButton.click();
      console.log('已点击登录按钮');

      // 等待并检查登录API响应
      const loginResponse = await loginPromise;
      const loginData = await loginResponse.json();
      console.log('登录API响应:', loginData);
      expect(loginData.code).toBe(200);

      // 等待跳转到主页
      await page.waitForURL('/home', { timeout: 15000 });
      
      // 验证登录成功
      await expect(page).toHaveURL('/home');
      // 验证登录状态：检查"发表动态"按钮是否可见（而不是昵称，因为昵称在移动端会被隐藏）
      await expect(page.getByRole('button', { name: /发表动态/ })).toBeVisible({ timeout: 5000 });

      // 验证 token 已保存
      const token = await page.evaluate(() => localStorage.getItem('token'));
      expect(token).toBeTruthy();
    });

    test('使用错误密码登录失败', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const user = createTestUser(5);

      // 先注册用户
      await auth.registerViaAPI(user);

      // 访问登录页
      await page.goto('/login');
      await page.waitForLoadState('networkidle');
      await page.waitForSelector('.login-form', { state: 'visible', timeout: 10000 });

      // 使用错误密码登录
      await page.getByPlaceholder('用户名').fill(user.username);
      await page.getByPlaceholder('密码').fill('WrongPassword123!');

      await page.getByRole('button', { name: '登录' }).click();

      // 应该显示错误消息
      await expect(page.getByText(/用户名或密码错误|登录失败/)).toBeVisible({ timeout: 5000 });
      
      // 应该留在登录页
      await expect(page).toHaveURL('/login');
    });

    test('使用不存在的用户登录失败', async ({ page }) => {
      await page.goto('/login');
      await page.waitForLoadState('networkidle');
      await page.waitForSelector('.login-form', { state: 'visible', timeout: 10000 });

      await page.getByPlaceholder('用户名').fill('nonexistentuser');
      await page.getByPlaceholder('密码').fill('SomePassword123!');

      await page.getByRole('button', { name: '登录' }).click();

      // 应该显示错误消息
      await expect(page.getByText(/用户名或密码错误|登录失败/)).toBeVisible({ timeout: 5000 });
    });
  });

  test.describe('用户登出', () => {
    test('成功登出', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(6);

      // 导航到主页
      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      // 点击用户头像/菜单（使用头像元素而不是昵称文字）
      await page.locator('.user-avatar-wrapper').click();
      
      // 等待下拉菜单显示
      await page.waitForSelector('text=退出登录', { state: 'visible', timeout: 5000 });

      // 点击退出登录
      await page.click('text=退出登录');

      // 应该跳转到登录页
      await page.waitForURL('/login', { timeout: 10000 });
      await expect(page).toHaveURL('/login');

      // 验证 token 已清除
      const tokenAfterLogout = await page.evaluate(() => localStorage.getItem('token'));
      expect(tokenAfterLogout).toBeNull();
    });
  });

  test.describe('权限校验', () => {
    test('未登录用户访问受保护页面时重定向到登录页', async ({ page }) => {
      // 直接访问需要登录的页面
      await page.goto('/profile');

      // 应该被重定向到登录页
      await page.waitForURL('/login', { timeout: 10000 });
      await expect(page).toHaveURL('/login');
    });

    test('Token 过期后访问受限资源失败', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      
      // 设置过期的 token
      await auth.setExpiredToken();

      // 尝试访问受保护页面
      await page.goto('/profile');

      // 应该被重定向到登录页
      await page.waitForURL('/login', { timeout: 10000 });
      await expect(page).toHaveURL('/login');
    });

    test('登录用户可以访问个人主页', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(7);

      // 访问个人主页
      await page.goto('/profile');
      
      // 等待个人主页API响应
      await page.waitForResponse(
        response => response.url().includes('/api/users/profile') || response.url().includes('/api/posts/my'),
        { timeout: 10000 }
      ).catch(() => {});
      
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);

      // 验证页面加载成功（使用更可靠的元素）
      await expect(page.locator('text=我的动态')).toBeVisible({ timeout: 10000 });
      // 或者检查编辑资料按钮
      await expect(page.locator('text=/编辑资料|编辑/')).toBeVisible({ timeout: 10000 });
    });
  });

  test.describe('用户状态持久化', () => {
    test('刷新页面后登录状态保持', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(8);

      // 导航到主页
      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      // 验证已登录（检查发表动态按钮）
      await expect(page.getByRole('button', { name: /发表动态/ })).toBeVisible({ timeout: 5000 });

      // 刷新页面
      await page.reload();
      await page.waitForLoadState('networkidle');

      // 验证仍然处于登录状态
      await expect(page.getByRole('button', { name: /发表动态/ })).toBeVisible({ timeout: 5000 });
      
      // Token 仍然存在
      const tokenAfterReload = await page.evaluate(() => localStorage.getItem('token'));
      expect(tokenAfterReload).toBe(token);
    });

    test('关闭标签页重新打开后登录状态保持', async ({ page, request, context }) => {
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(9);

      // 导航到主页
      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      // 验证已登录（检查发表动态按钮）
      await expect(page.getByRole('button', { name: /发表动态/ })).toBeVisible({ timeout: 5000 });

      // 关闭页面
      await page.close();

      // 打开新页面
      const newPage = await context.newPage();
      await newPage.goto('/home');
      await newPage.waitForLoadState('networkidle');

      // 验证仍然处于登录状态（localStorage 持久化）
      const tokenInNewPage = await newPage.evaluate(() => localStorage.getItem('token'));
      expect(tokenInNewPage).toBe(token);

      await newPage.close();
    });
  });
});



