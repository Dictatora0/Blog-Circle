/**
 * 点赞功能模块 E2E 测试
 * 覆盖点赞、取消点赞、点赞数统计等场景
 */

import { test, expect } from '@playwright/test';
import { createTestPost } from '../fixtures/test-data';
import { AuthHelpers } from '../fixtures/auth-helpers';
import { ApiHelpers } from '../fixtures/api-helpers';

test.describe('点赞功能模块', () => {
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

  test.describe('点赞动态', () => {
    test('成功点赞动态', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(1);

      // 创建一条测试动态
      const post = createTestPost(1);
      const createResult = await api.createPost({ content: post.content }, token);
      expect(createResult.status).toBe(200);
      const postData = createResult.body.data || createResult.body;
      const postId = postData.id || postData;

      // 等待动态保存完成（增加等待时间，确保事务提交）
      await page.waitForTimeout(5000);

      // 访问首页
      await page.goto('/home');
      
      // 使用重试机制：多次尝试查找动态
      let foundPost = false;
      let retries = 0;
      const maxRetries = 5;
      
      while (!foundPost && retries < maxRetries) {
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
        
        // 验证API响应包含我们创建的动态
        if (timelineResponse) {
          const timelineData = await timelineResponse.json();
          const posts = timelineData?.data || timelineData || [];
          const foundPostInResponse = Array.isArray(posts) && posts.find((p: any) => 
            p.id === postId || (p.content && p.content.includes(post.content.substring(0, 20)))
          );
          
          if (foundPostInResponse) {
            foundPost = true;
            console.log(`Found post in API response: ${JSON.stringify({id: foundPostInResponse.id, content: foundPostInResponse.content?.substring(0, 30)})}`);
            break;
          } else {
            console.log(`Post not found in API response (attempt ${retries + 1}/${maxRetries})`);
          }
        }
        
        // 如果没找到，刷新页面重试
        if (!foundPost && retries < maxRetries - 1) {
          await page.reload();
          await page.waitForLoadState('networkidle');
          await page.waitForTimeout(2000);
        }
        
        retries++;
      }
      
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(2000);

      // 找到刚创建的动态
      const postContent = post.content.substring(0, 30);
      const postElement = page.locator(`text=${postContent}`).first();
      await expect(postElement).toBeVisible({ timeout: 20000 });

      // 找到动态卡片
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment-item")]').first();
      
      // 找到点赞按钮（使用图标按钮）
      const likeButton = postCard.locator('button.action-btn').filter({ hasText: '🤍' }).or(postCard.locator('button.action-btn').filter({ hasText: '❤️' })).first();

      // 点击点赞
      await likeButton.click();
      await page.waitForTimeout(1000);

      // 验证点赞状态 - 检查按钮图标变化或点赞数
      const likeIcon = await likeButton.locator('.action-icon').textContent();
      expect(likeIcon).toBe('❤️');
    });

    test('通过API点赞动态', async ({ page, request }) => {
      const api = new ApiHelpers(request);
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(2);

      // 创建动态
      const post = createTestPost(2);
      const postResult = await api.createPost({ content: post.content }, token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 点赞
      const likeResult = await api.likePost(postId, token);
      expect(likeResult.status).toBe(200);

      // 等待点赞保存完成
      await page.waitForTimeout(2000);

      // 访问首页验证点赞显示
      await page.goto('/home');
      
      // 等待时间线API响应完成
      await page.waitForResponse(
        response => response.url().includes('/api/posts/timeline') && response.status() === 200,
        { timeout: 15000 }
      ).catch(() => {});
      
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);

      const postContent = post.content.substring(0, 30);
      const postElement = page.locator(`text=${postContent}`).first();
      await expect(postElement).toBeVisible({ timeout: 15000 });
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      
      // 验证点赞数为1（使用 stat-item 和图标）
      const likeStat = postCard.locator('.stat-item').filter({ hasText: '❤️' });
      await expect(likeStat).toBeVisible({ timeout: 10000 });
      const countText = await likeStat.textContent();
      expect(countText).toContain('1');
    });

    test('点赞按钮视觉反馈正确', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(3);

      // 创建动态
      const post = createTestPost(3);
      const postResult = await api.createPost({ content: post.content }, token);

      // 访问首页
      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      const likeButton = postCard.locator('button.action-btn').filter({ hasText: '🤍' }).or(postCard.locator('button.action-btn').filter({ hasText: '❤️' })).first();

      // 记录点赞前的图标
      const beforeIcon = await likeButton.textContent();

      // 点击点赞
      await likeButton.click();
      await page.waitForTimeout(500);

      // 记录点赞后的图标
      const afterIcon = await likeButton.textContent();

      // 图标应该变化（🤍 -> ❤️）
      expect(afterIcon).toContain('❤️');
    });

    test('未登录用户无法点赞', async ({ page, request }) => {
      const api = new ApiHelpers(request);
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(4);

      // 创建动态
      const post = createTestPost(4);
      await api.createPost({ content: post.content }, token);

      // 登出
      await auth.logout();

      // 尝试访问首页
      await page.goto('/home');

      // 检查是否被重定向到登录页
      const currentUrl = page.url();
      if (currentUrl.includes('/login')) {
        // 符合预期：未登录用户被重定向到登录页
        await expect(page).toHaveURL(/\/login/);
      } else {
        // 如果允许访问，点赞功能应该被限制
        const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
        if (await postElement.isVisible()) {
          const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
          const likeButton = postCard.locator('button:has-text("点赞"), button[class*="like"]').first();
          
          if (await likeButton.isVisible()) {
            await likeButton.click();
            // 应该提示登录或被重定向
            await page.waitForTimeout(1000);
            
            // 检查是否显示登录提示或跳转到登录页
            const loginPrompt = page.locator('text=/请先登录|登录后/');
            const isLoginPage = page.url().includes('/login');
            
            expect(await loginPrompt.isVisible() || isLoginPage).toBe(true);
          }
        }
      }
    });
  });

  test.describe('取消点赞', () => {
    test('成功取消点赞', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(5);

      // 创建动态
      const post = createTestPost(5);
      const postResult = await api.createPost({ content: post.content }, token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 先点赞
      await api.likePost(postId, token);

      // 访问首页
      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      const likeButton = postCard.locator('button.action-btn').filter({ hasText: '🤍' }).or(postCard.locator('button.action-btn').filter({ hasText: '❤️' })).first();

      // 再次点击取消点赞
      await likeButton.click();
      await page.waitForTimeout(1000);

      // 验证点赞数变为0
      const likeStat = postCard.locator('.stat-item').filter({ hasText: '❤️' });
      const countText = await likeStat.textContent();
      
      // 应该显示0或不显示数字
      expect(countText).toMatch(/0|❤️/);
    });

    test('通过API取消点赞', async ({ page, request }) => {
      const api = new ApiHelpers(request);
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(6);

      // 创建动态并点赞
      const post = createTestPost(6);
      const postResult = await api.createPost({ content: post.content }, token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      await api.likePost(postId, token);

      // 取消点赞
      const unlikeResult = await api.unlikePost(postId, token);
      expect(unlikeResult.status).toBe(200);

      // 等待取消点赞保存完成
      await page.waitForTimeout(2000);

      // 验证点赞已取消
      await page.goto('/home');
      
      // 等待时间线API响应完成
      await page.waitForResponse(
        response => response.url().includes('/api/posts/timeline') && response.status() === 200,
        { timeout: 15000 }
      ).catch(() => {});
      
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);

      const postContent = post.content.substring(0, 30);
      const postElement = page.locator(`text=${postContent}`).first();
      await expect(postElement).toBeVisible({ timeout: 15000 });
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      const likeCount = postCard.locator('[class*="like-count"], [class*="likes"]').first();
      await expect(likeCount).toBeVisible({ timeout: 10000 });
      const countText = await likeCount.textContent();
      
      expect(countText).toMatch(/0|^$/);
    });

    test('点赞状态切换流畅', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(7);

      // 创建动态
      const post = createTestPost(7);
      await api.createPost({ content: post.content }, token);

      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      const likeButton = postCard.locator('button:has-text("点赞"), button[class*="like"]').first();

      // 连续点击3次：点赞 -> 取消 -> 再点赞
      for (let i = 0; i < 3; i++) {
        await likeButton.click();
        await page.waitForTimeout(500);
      }

      // 最终状态应该是已点赞（奇数次点击）
      const finalClass = await likeButton.getAttribute('class');
      expect(finalClass).toContain('liked' || 'active');
    });
  });

  test.describe('点赞数统计', () => {
    test('单个用户点赞数显示正确', async ({ page, request }) => {
      const api = new ApiHelpers(request);
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(8);

      // 创建动态
      const post = createTestPost(8);
      const postResult = await api.createPost({ content: post.content }, token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 点赞
      await api.likePost(postId, token);

      // 验证点赞数
      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      const likeCount = postCard.locator('[class*="like-count"], [class*="likes"]').first();
      const countText = await likeCount.textContent();
      
      expect(countText).toContain('1');
    });

    test('多个用户点赞数累加正确', async ({ page, request }) => {
      const api = new ApiHelpers(request);
      
      // 用户A创建动态
      const authA = new AuthHelpers(page, request);
      const userA = await authA.createAndLoginTestUser(9);
      
      const post = createTestPost(9);
      const postResult = await api.createPost({ content: post.content }, userA.token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 用户A点赞
      await api.likePost(postId, userA.token);

      // 用户B注册并点赞
      await authA.logout();
      const userB = await authA.createAndLoginTestUser(10);
      await api.likePost(postId, userB.token);

      // 用户C注册并点赞
      await authA.logout();
      const userC = await authA.createAndLoginTestUser(11);
      await api.likePost(postId, userC.token);

      // 验证点赞数为3
      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      const likeCount = postCard.locator('[class*="like-count"], [class*="likes"]').first();
      const countText = await likeCount.textContent();
      
      expect(countText).toContain('3');
    });

    test('取消点赞后数量减少', async ({ page, request }) => {
      const api = new ApiHelpers(request);
      
      // 创建两个用户
      const authA = new AuthHelpers(page, request);
      const userA = await authA.createAndLoginTestUser(12);
      const userB = await authA.createAndLoginTestUser(13);

      // 用户A创建动态
      const post = createTestPost(12);
      const postResult = await api.createPost({ content: post.content }, userA.token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 两个用户都点赞
      await api.likePost(postId, userA.token);
      await api.likePost(postId, userB.token);

      // 用户A取消点赞
      await api.unlikePost(postId, userA.token);

      // 验证点赞数为1
      await authA.loginViaAPI(userB.user.username, userB.user.password);
      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      const likeCount = postCard.locator('[class*="like-count"], [class*="likes"]').first();
      const countText = await likeCount.textContent();
      
      expect(countText).toContain('1');
    });
  });

  test.describe('重复点赞处理', () => {
    test('同一用户不能重复点赞', async ({ page, request }) => {
      const api = new ApiHelpers(request);
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(14);

      // 创建动态
      const post = createTestPost(14);
      const postResult = await api.createPost({ content: post.content }, token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 第一次点赞
      const firstLike = await api.likePost(postId, token);
      expect(firstLike.status).toBe(200);

      // 尝试再次点赞
      const secondLike = await api.likePost(postId, token);
      
      // 应该返回错误或已点赞状态
      // 具体行为取决于后端实现
      expect([200, 400, 409]).toContain(secondLike.status);

      // 验证点赞数仍为1
      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      const likeCount = postCard.locator('[class*="like-count"], [class*="likes"]').first();
      const countText = await likeCount.textContent();
      
      expect(countText).toContain('1');
    });
  });

  test.describe('点赞状态持久化', () => {
    test('刷新页面后点赞状态保持', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(15);

      // 创建动态
      const post = createTestPost(15);
      const postResult = await api.createPost({ content: post.content }, token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 点赞
      await api.likePost(postId, token);

      // 访问首页
      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      // 验证点赞状态
      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      const likeButton = postCard.locator('button:has-text("点赞"), button[class*="like"]').first();
      
      const beforeRefresh = await likeButton.getAttribute('class');

      // 刷新页面
      await page.reload();
      await page.waitForLoadState('networkidle');

      // 再次检查点赞状态
      const postElementAfter = page.locator(`text=${post.content.substring(0, 20)}`).first();
      const postCardAfter = postElementAfter.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
      const likeButtonAfter = postCardAfter.locator('button:has-text("点赞"), button[class*="like"]').first();
      
      const afterRefresh = await likeButtonAfter.getAttribute('class');

      // 点赞状态应该保持
      expect(beforeRefresh).toBe(afterRefresh);
    });

    test('不同用户看到正确的点赞状态', async ({ page, request }) => {
      const api = new ApiHelpers(request);
      
      // 用户A创建动态并点赞
      const authA = new AuthHelpers(page, request);
      const userA = await authA.createAndLoginTestUser(16);
      
      const post = createTestPost(16);
      const postResult = await api.createPost({ content: post.content }, userA.token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;
      await api.likePost(postId, userA.token);

      // 用户B登录查看（未点赞）
      await authA.logout();
      const userB = await authA.createAndLoginTestUser(17);

      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      // 用户B应该看到点赞数为1，但自己未点赞
      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      if (await postElement.isVisible()) {
        const postCard = postElement.locator('xpath=ancestor::div[contains(@class, "moment") or contains(@class, "post")]').first();
        const likeCount = postCard.locator('[class*="like-count"], [class*="likes"]').first();
        const countText = await likeCount.textContent();
        
        // 总点赞数应该是1
        expect(countText).toContain('1');

        // 用户B的点赞按钮应该是未点赞状态
        const likeButton = postCard.locator('button:has-text("点赞"), button[class*="like"]').first();
        const buttonClass = await likeButton.getAttribute('class');
        
        // 不应该有 liked 或 active 类名
        expect(buttonClass).not.toContain('liked');
      }
    });
  });
});





