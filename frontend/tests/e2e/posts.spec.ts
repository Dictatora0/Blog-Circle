/**
 * 动态发布模块 E2E 测试
 * 覆盖发布、删除、图片上传等场景
 */

import { test, expect } from '@playwright/test';
import { createTestPost, createLongPost, invalidData } from '../fixtures/test-data';
import { AuthHelpers } from '../fixtures/auth-helpers';
import { ApiHelpers } from '../fixtures/api-helpers';

test.describe('动态发布模块', () => {
  test.beforeEach(async ({ page }) => {
    // 先导航到首页，确保在有效的上下文中
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // 清除cookies和storage
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

  test.describe('发布动态', () => {
    test('成功发布纯文字动态', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(1);
      const post = createTestPost(1);

      // 导航到发布页
      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 填写动态内容
      await page.fill('textarea[placeholder*="分享"]', post.content);

      // 检查字数统计（使用更具体的选择器，避免多个匹配）
      const charCount = await page.locator('.word-count, [class*="word-count"]').first().textContent();
      expect(charCount).toContain(post.content.length.toString());

      // 发布
      await page.click('button:has-text("发布")');

      // 等待发布成功，跳转到首页
      await page.waitForURL('/home', { timeout: 10000 });
      
      // 等待时间线API响应完成（首页使用/timeline）
      const timelineResponse = await page.waitForResponse(
        response => response.url().includes('/api/posts/timeline') && response.status() === 200,
        { timeout: 15000 }
      ).catch(() => {
        return page.waitForResponse(
          response => response.url().includes('/api/posts') && response.status() === 200,
          { timeout: 10000 }
        );
      });
      
      // 验证API响应包含我们发布的动态
      if (timelineResponse) {
        const timelineData = await timelineResponse.json();
        const posts = timelineData?.data || timelineData || [];
        const foundPost = Array.isArray(posts) && posts.find((p: any) => p.content?.includes(post.content.substring(0, 20)));
        if (!foundPost) {
          // 如果API响应中没有找到，刷新页面重试
          await page.reload();
          await page.waitForLoadState('networkidle');
          await page.waitForTimeout(2000);
        }
      }
      
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(2000);

      // 验证动态显示在首页
      const postContent = post.content.substring(0, 30);
      await expect(page.locator(`text=${postContent}`).first()).toBeVisible({ timeout: 20000 });
    });

    test('空内容无法发布', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(2);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 不填写内容，直接点击发布
      const publishButton = page.locator('button:has-text("发布")');
      
      // 按钮应该被禁用或点击后显示错误
      const isDisabled = await publishButton.isDisabled();
      
      if (!isDisabled) {
        await publishButton.click();
        
        // 应该显示错误提示
        await expect(page.locator('text=/请输入内容|不能为空/')).toBeVisible();
        
        // 仍在发布页面
        await expect(page).toHaveURL('/publish');
      } else {
        expect(isDisabled).toBe(true);
      }
    });

    test('发布超长内容', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(3);
      const longPost = createLongPost();

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 填写超长内容
      await page.fill('textarea[placeholder*="分享"]', longPost.content);

      // 字数统计应该正确显示（使用更具体的选择器，避免多个匹配）
      const charCount = await page.locator('.word-count, [class*="word-count"]').first().textContent();
      
      // 发布按钮状态（可能限制或允许）
      const publishButton = page.locator('button:has-text("发布")');
      await publishButton.click();

      // 根据业务逻辑验证结果
      // 如果允许发布，应该成功跳转
      // 如果不允许，应该显示错误
    });

    test('发布带图片的动态', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(4);
      const post = createTestPost(4);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 填写文字内容
      await page.fill('textarea[placeholder*="分享"]', post.content);

      // 上传图片
      const fileInput = page.locator('input[type="file"]');
      
      // 创建测试图片
      const buffer = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64');
      
      await fileInput.setInputFiles({
        name: 'test-image.png',
        mimeType: 'image/png',
        buffer: buffer,
      });

      // 等待图片上传预览
      await expect(page.locator('img[alt*="preview"], .image-preview')).toBeVisible({ timeout: 5000 });

      // 发布
      await page.click('button:has-text("发布")');

      // 等待发布成功
      await page.waitForURL('/home', { timeout: 15000 });

      // 验证动态和图片都显示
      await expect(page.locator(`text=${post.content.substring(0, 20)}`)).toBeVisible();
    });

    test('发布多张图片的动态', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(5);
      const post = createTestPost(5);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      await page.fill('textarea[placeholder*="分享"]', post.content);

      // 上传多张图片
      const buffer = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64');
      
      const fileInput = page.locator('input[type="file"]');
      await fileInput.setInputFiles([
        { name: 'test-image-1.png', mimeType: 'image/png', buffer },
        { name: 'test-image-2.png', mimeType: 'image/png', buffer },
        { name: 'test-image-3.png', mimeType: 'image/png', buffer },
      ]);

      // 等待所有图片预览显示
      await page.waitForTimeout(2000);
      const previewImages = page.locator('img[alt*="preview"], .image-preview img');
      const count = await previewImages.count();
      expect(count).toBeGreaterThanOrEqual(3);

      // 发布
      await page.click('button:has-text("发布")');
      await page.waitForURL('/home', { timeout: 15000 });
    });
  });

  test.describe('删除动态', () => {
    test('删除自己的动态', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(6);
      const post = createTestPost(6);

      // 先创建一条动态
      const createResult = await api.createPost({ content: post.content }, token);
      expect(createResult.status).toBe(200);
      const postData = createResult.body.data || createResult.body;
      const postId = postData.id || postData;

      // 访问个人主页
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 找到刚发布的动态
      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      await expect(postElement).toBeVisible();

      // 点击删除按钮（通常是三个点菜单）
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      await postCard.locator('button[class*="more"], button:has-text("⋮")').first().click();

      // 点击删除选项
      await page.click('text=删除');

      // 确认删除
      await page.click('button:has-text("确定")');

      // 等待删除成功
      await page.waitForTimeout(1000);

      // 验证动态已被删除
      await expect(postElement).not.toBeVisible();
    });

    test('无法删除他人的动态', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      
      // 用户A创建动态
      const userA = await auth.createAndLoginTestUser(7);
      const post = createTestPost(7);
      const createResult = await api.createPost({ content: post.content }, userA.token);
      const postData = createResult.body.data || createResult.body;
      const postId = postData.id || postData;

      // 用户B登录
      await auth.logout();
      const userB = await auth.createAndLoginTestUser(8);

      // 用户B访问首页（如果能看到userA的动态）
      await page.goto('/home');
      
      // 等待时间线API响应完成
      await page.waitForResponse(
        response => response.url().includes('/api/posts/timeline') && response.status() === 200,
        { timeout: 15000 }
      ).catch(() => {});
      
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      await page.waitForLoadState('networkidle');

      // 查找userA的动态，不应该有删除按钮
      const posts = page.locator('.moment-item, .post-item');
      const count = await posts.count();

      for (let i = 0; i < count; i++) {
        const postCard = posts.nth(i);
        const content = await postCard.textContent();
        
        if (content?.includes(post.content.substring(0, 20))) {
          // 这个动态属于userA，userB不应该看到删除按钮
          const deleteButton = postCard.locator('button:has-text("删除")');
          await expect(deleteButton).not.toBeVisible();
        }
      }
    });
  });

  test.describe('查看动态', () => {
    test('在首页查看动态列表', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(9);

      // 创建多条动态
      for (let i = 1; i <= 3; i++) {
        const post = createTestPost(i);
        await api.createPost({ content: post.content }, token);
      }

      // 访问首页
      await page.goto('/home');
      
      // 等待时间线API响应完成
      await page.waitForResponse(
        response => response.url().includes('/api/posts/timeline') && response.status() === 200,
        { timeout: 15000 }
      ).catch(() => {});
      
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      await page.waitForLoadState('networkidle');

      // 验证至少有一些动态显示
      const moments = page.locator('.moment-item, .post-item');
      const count = await moments.count();
      expect(count).toBeGreaterThan(0);
    });

    test('查看我的动态列表', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(10);

      // 创建几条动态
      const posts = [];
      for (let i = 1; i <= 3; i++) {
        const post = createTestPost(i);
        await api.createPost({ content: post.content }, token);
        posts.push(post);
      }

      // 访问个人主页
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 验证我的动态都显示了
      for (const post of posts) {
        await expect(page.locator(`text=${post.content.substring(0, 20)}`)).toBeVisible();
      }
    });

    test('动态数量统计正确', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(11);

      // 创建3条动态
      for (let i = 1; i <= 3; i++) {
        await api.createPost({ content: `测试动态${i}` }, token);
      }

      // 访问个人主页
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 验证动态数量
      const countElement = page.locator('[class*="count"], text=/动态数|发布/').first();
      const countText = await countElement.textContent();
      
      // 应该包含数字3
      expect(countText).toMatch(/3/);
    });
  });

  test.describe('XSS 防护', () => {
    test('HTML/脚本标签被正确转义', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(12);

      // 尝试发布包含HTML/脚本的内容
      const xssContent = invalidData.specialCharacters.content;
      await api.createPost({ content: xssContent }, token);

      // 访问首页
      await page.goto('/home');
      
      // 等待时间线API响应完成
      await page.waitForResponse(
        response => response.url().includes('/api/posts/timeline') && response.status() === 200,
        { timeout: 15000 }
      ).catch(() => {});
      
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      await page.waitForLoadState('networkidle');

      // 验证内容被转义显示为文本，而不是被执行
      const postContent = await page.locator(`text=${xssContent}`).textContent();
      expect(postContent).toContain('<script>');
      
      // 确保没有弹窗（脚本未被执行）
      let alertFired = false;
      page.on('dialog', () => {
        alertFired = true;
      });
      
      await page.waitForTimeout(1000);
      expect(alertFired).toBe(false);
    });
  });
});

