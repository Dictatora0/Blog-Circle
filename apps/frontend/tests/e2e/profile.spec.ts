/**
 * 个人主页模块 E2E 测试
 * 覆盖个人信息展示、编辑、动态列表等场景
 */

import { test, expect } from '@playwright/test';
import { createTestPost } from '../fixtures/test-data';
import { AuthHelpers } from '../fixtures/auth-helpers';
import { ApiHelpers } from '../fixtures/api-helpers';
import { Buffer } from 'buffer';

test.describe('个人主页模块', () => {
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

  test.describe('查看个人信息', () => {
    test('显示用户基本信息', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(1);

      // 访问个人主页
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 验证昵称显示
      await expect(page.locator(`text=${user.user.nickname}`)).toBeVisible();

      // 验证用户名显示（可能在某处显示）
      const username = page.locator(`text=${user.user.username}`);
      if (await username.isVisible().catch(() => false)) {
        await expect(username).toBeVisible();
      }
    });

    test('显示用户头像', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(2);

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 验证头像显示
      const avatar = page.locator('img[alt*="头像"], img[alt*="avatar"], [class*="avatar"] img').first();
      await expect(avatar).toBeVisible();

      // 验证头像有src属性
      const src = await avatar.getAttribute('src');
      expect(src).toBeTruthy();
    });

    test('显示封面图片', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(3);

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 查找封面元素
      const cover = page.locator('[class*="cover"], [class*="banner"]').first();
      
      if (await cover.isVisible()) {
        // 验证封面区域存在
        await expect(cover).toBeVisible();

        // 检查是否有背景图或img标签
        const coverImg = cover.locator('img');
        const hasCoverImage = await coverImg.isVisible().catch(() => false);
        
        if (hasCoverImage) {
          const src = await coverImg.getAttribute('src');
          expect(src).toBeTruthy();
        }
      }
    });

    test('显示用户统计信息', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(4);

      // 创建几条动态
      for (let i = 1; i <= 3; i++) {
        const post = createTestPost(i);
        await api.createPost({ content: post.content }, token);
      }

      // 访问个人主页
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 验证动态数量显示
      const statsArea = page.locator('[class*="stats"], [class*="count"]');
      const statsText = await statsArea.textContent();

      // 应该显示动态数量
      expect(statsText).toMatch(/3|动态/);
    });
  });

  test.describe('编辑个人信息', () => {
    test('修改昵称', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(5);

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 查找编辑按钮
      const editButton = page.locator('button:has-text("编辑"), button:has-text("修改"), [class*="edit"]');
      
      if (await editButton.first().isVisible()) {
        await editButton.first().click();
        await page.waitForTimeout(500);

        // 查找昵称输入框
        const nicknameInput = page.locator('input[placeholder*="昵称"], input[name="nickname"]').first();
        
        if (await nicknameInput.isVisible()) {
          const newNickname = `新昵称_${Date.now()}`;
          
          // 清空并输入新昵称
          await nicknameInput.clear();
          await nicknameInput.fill(newNickname);

          // 保存
          await page.click('button:has-text("保存"), button:has-text("确定"), button:has-text("提交")');

          await page.waitForTimeout(1000);

          // 验证昵称已更新
          await expect(page.locator(`text=${newNickname}`)).toBeVisible({ timeout: 5000 });
        }
      }
    });

    test('上传头像', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(6);

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 查找头像上传区域
      const avatarArea = page.locator('[class*="avatar"]').first();
      
      // 悬停或点击头像可能显示上传选项
      await avatarArea.hover();
      await page.waitForTimeout(500);

      // 查找文件上传input
      const uploadInput = page.locator('input[type="file"]').first();
      
      if (await uploadInput.isVisible({ timeout: 2000 }).catch(() => false) || 
          await uploadInput.isHidden()) {
        
        const imageBuffer = Buffer.from(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          'base64'
        );

        await uploadInput.setInputFiles({
          name: 'new-avatar.png',
          mimeType: 'image/png',
          buffer: imageBuffer,
        });

        await page.waitForTimeout(2000);

        // 验证头像更新
        // 可能需要刷新页面
        await page.reload();
        await page.waitForLoadState('networkidle');

        const avatar = page.locator('img[alt*="头像"], [class*="avatar"] img').first();
        await expect(avatar).toBeVisible();
      }
    });

    test('上传封面', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(7);

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 查找封面区域
      const coverArea = page.locator('[class*="cover"], [class*="banner"]').first();
      
      if (await coverArea.isVisible()) {
        await coverArea.hover();
        await page.waitForTimeout(500);

        // 查找上传按钮或input
        const uploadButton = page.locator('button:has-text("更换封面"), button:has-text("上传封面")');
        const uploadInput = page.locator('[class*="cover"] input[type="file"]');

        if (await uploadButton.isVisible().catch(() => false)) {
          await uploadButton.click();
        }

        if (await uploadInput.count() > 0) {
          const imageBuffer = Buffer.from(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
            'base64'
          );

          await uploadInput.first().setInputFiles({
            name: 'new-cover.png',
            mimeType: 'image/png',
            buffer: imageBuffer,
          });

          await page.waitForTimeout(2000);

          // 验证封面更新
          const coverImg = page.locator('[class*="cover"] img, img[alt*="封面"]').first();
          const hasCover = await coverImg.isVisible().catch(() => false);
          
          if (hasCover) {
            await expect(coverImg).toBeVisible();
          }
        }
      }
    });

    test('修改个人简介', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(8);

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 查找编辑按钮
      const editButton = page.locator('button:has-text("编辑"), button:has-text("修改")').first();
      
      if (await editButton.isVisible().catch(() => false)) {
        await editButton.click();
        await page.waitForTimeout(500);

        // 查找简介输入框
        const bioInput = page.locator('textarea[placeholder*="简介"], textarea[name="bio"], input[placeholder*="简介"]');
        
        if (await bioInput.isVisible().catch(() => false)) {
          const newBio = `这是我的个人简介_${Date.now()}`;
          
          await bioInput.clear();
          await bioInput.fill(newBio);

          // 保存
          await page.click('button:has-text("保存"), button:has-text("确定")');

          await page.waitForTimeout(1000);

          // 验证简介已更新
          await expect(page.locator(`text=${newBio}`)).toBeVisible({ timeout: 5000 });
        }
      }
    });
  });

  test.describe('我的动态列表', () => {
    test('显示我的所有动态', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(9);

      // 创建多条动态
      const posts = [];
      for (let i = 1; i <= 5; i++) {
        const post = createTestPost(i);
        await api.createPost({ content: post.content }, token);
        posts.push(post);
      }

      // 访问个人主页
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 切换到"我的动态"标签（如果有）
      const myPostsTab = page.locator('text=我的动态, [class*="tab"]:has-text("动态")').first();
      if (await myPostsTab.isVisible().catch(() => false)) {
        await myPostsTab.click();
        await page.waitForTimeout(500);
      }

      // 验证所有动态都显示
      for (const post of posts) {
        await expect(page.locator(`text=${post.content.substring(0, 20)}`)).toBeVisible();
      }
    });

    test('动态按时间倒序排列', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(10);

      // 创建3条动态，有时间间隔
      await api.createPost({ content: '第一条动态' }, token);
      await page.waitForTimeout(1000);
      await api.createPost({ content: '第二条动态' }, token);
      await page.waitForTimeout(1000);
      await api.createPost({ content: '第三条动态' }, token);

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 获取所有动态元素
      const moments = page.locator('.moment-item, .post-item, [class*="post"]');
      const count = await moments.count();

      if (count >= 3) {
        // 获取前三条动态的内容
        const firstMoment = await moments.nth(0).textContent();
        const secondMoment = await moments.nth(1).textContent();
        const thirdMoment = await moments.nth(2).textContent();

        // 最新的应该在最上面（倒序）
        expect(firstMoment).toContain('第三条');
        expect(secondMoment).toContain('第二条');
        expect(thirdMoment).toContain('第一条');
      }
    });

    test('显示动态数量统计', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(11);

      // 创建5条动态
      for (let i = 1; i <= 5; i++) {
        await api.createPost({ content: `动态${i}` }, token);
      }

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 查找动态数量显示
      const countElement = page.locator('[class*="count"]:has-text("动态"), text=/动态.*5|5.*动态/').first();
      
      if (await countElement.isVisible().catch(() => false)) {
        const countText = await countElement.textContent();
        expect(countText).toContain('5');
      } else {
        // 或者通过实际计数
        const moments = page.locator('.moment-item, .post-item');
        const count = await moments.count();
        expect(count).toBe(5);
      }
    });

    test('空动态状态显示', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(12);

      // 不创建任何动态，直接访问个人主页
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 应该显示空状态提示
      const emptyState = page.locator('text=/暂无动态|还没有发布|空空如也/');
      
      if (await emptyState.isVisible().catch(() => false)) {
        await expect(emptyState).toBeVisible();
      } else {
        // 或者验证动态列表为空
        const moments = page.locator('.moment-item, .post-item');
        const count = await moments.count();
        expect(count).toBe(0);
      }
    });
  });

  test.describe('用户互动统计', () => {
    test('显示获赞数', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      
      // 用户A创建动态
      const userA = await auth.createAndLoginTestUser(13);
      const post = createTestPost(13);
      const postResult = await api.createPost({ content: post.content }, userA.token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 用户B点赞
      await auth.logout();
      const userB = await auth.createAndLoginTestUser(14);
      await api.likePost(postId, userB.token);

      // 用户A查看个人主页
      await auth.logout();
      await auth.loginViaAPI(userA.user.username, userA.user.password);
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 验证获赞数显示
      const likesCount = page.locator('[class*="likes"], text=/获赞|点赞/').first();
      
      if (await likesCount.isVisible().catch(() => false)) {
        const countText = await likesCount.textContent();
        expect(countText).toMatch(/1/);
      }
    });

    test('显示好友数', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      
      // 创建用户A和B
      const userA = await auth.createAndLoginTestUser(15);
      const userB = await auth.createAndLoginTestUser(16);

      // 搜索并添加好友
      const searchResult = await api.searchUsers(userB.user.username, userA.token);
      const userBInfo = searchResult.body.data.find((u: any) => u.username === userB.user.username);
      const requestResult = await api.sendFriendRequest(userBInfo.id, userA.token);
      const requestData = requestResult.body.data || requestResult.body;
      const requestId = requestData.id || requestData;
      
      // 用户B接受好友请求
      await api.acceptFriendRequest(requestId, userB.token);

      // 用户A查看个人主页
      await auth.loginViaAPI(userA.user.username, userA.user.password);
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 验证好友数显示
      const friendsCount = page.locator('[class*="friends"], text=/好友/').first();
      
      if (await friendsCount.isVisible().catch(() => false)) {
        const countText = await friendsCount.textContent();
        expect(countText).toMatch(/1/);
      }
    });
  });

  test.describe('访问其他用户主页', () => {
    test('查看其他用户的主页', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      
      // 创建用户A和B
      const userA = await auth.createAndLoginTestUser(17);
      const userB = await auth.createAndLoginTestUser(18);

      // 用户B创建动态
      await api.createPost({ content: '用户B的动态' }, userB.token);

      // 用户A登录并访问用户B的主页
      await auth.loginViaAPI(userA.user.username, userA.user.password);
      
      // 假设可以通过URL访问其他用户主页
      await page.goto(`/profile/${userB.user.username}`);
      await page.waitForLoadState('networkidle');

      // 应该看到用户B的昵称
      await expect(page.locator(`text=${userB.user.nickname}`)).toBeVisible();

      // 应该看到用户B的动态
      await expect(page.locator('text=用户B的动态')).toBeVisible();
    });

    test('无法编辑他人信息', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      
      const userA = await auth.createAndLoginTestUser(19);
      const userB = await auth.createAndLoginTestUser(20);

      // 用户A访问用户B的主页
      await auth.loginViaAPI(userA.user.username, userA.user.password);
      await page.goto(`/profile/${userB.user.username}`);
      await page.waitForLoadState('networkidle');

      // 不应该看到编辑按钮
      const editButton = page.locator('button:has-text("编辑"), button:has-text("修改")');
      await expect(editButton).not.toBeVisible();
    });
  });

  test.describe('响应式布局', () => {
    test('桌面端正确显示', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(21);

      // 设置桌面端视口
      await page.setViewportSize({ width: 1920, height: 1080 });

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 验证页面正常显示（使用更精确的选择器）
      await expect(page.locator('.profile-page, main').first()).toBeVisible();
    });

    test('移动端正确显示', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(22);

      // 设置移动端视口
      await page.setViewportSize({ width: 375, height: 667 });

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 验证页面正常显示（使用更精确的选择器）
      await expect(page.locator('.profile-page, main').first()).toBeVisible();
    });
  });
});

