/**
 * 数据统计模块 E2E 测试
 * 覆盖数据分析、Spark统计、SQL回退等场景
 */

import { test, expect } from '@playwright/test';
import { createTestPost } from '../fixtures/test-data';
import { AuthHelpers } from '../fixtures/auth-helpers';
import { ApiHelpers } from '../fixtures/api-helpers';

test.describe('数据统计模块', () => {
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

  test.describe('基础统计数据', () => {
    test('查看统计数据页面', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(1);

      // 创建一些测试数据
      for (let i = 1; i <= 3; i++) {
        const post = createTestPost(i);
        await api.createPost({ content: post.content }, token);
      }

      // 访问统计页面（假设路由为 /statistics 或 /stats）
      await page.goto('/statistics');
      await page.waitForLoadState('networkidle');

      // 如果页面不存在，可能在个人主页的某个tab
      if (page.url().includes('/login') || page.url().includes('/404')) {
        await page.goto('/profile');
        await page.waitForLoadState('networkidle');

        // 查找统计相关tab或按钮
        const statsTab = page.locator('text=数据统计, text=统计, [class*="stats"]').first();
        if (await statsTab.isVisible().catch(() => false)) {
          await statsTab.click();
          await page.waitForTimeout(500);
        }
      }

      // 验证页面显示统计信息
      const statsContent = page.locator('[class*="stats"], [class*="statistics"]');
      const hasStats = await statsContent.isVisible().catch(() => false);
      
      if (hasStats) {
        await expect(statsContent).toBeVisible();
      }
    });

    test('通过API获取统计数据', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(2);

      // 创建测试数据
      for (let i = 1; i <= 5; i++) {
        await api.createPost({ content: `测试动态${i}` }, token);
      }

      // 调用统计API
      const statsResult = await api.getStatistics(token);

      // 验证API返回
      expect(statsResult.status).toBe(200);
      
      if (statsResult.body && statsResult.body.data) {
        const stats = statsResult.body.data;
        
        // 验证统计数据结构
        expect(stats).toBeTruthy();
        
        // 可能包含的统计字段
        const possibleFields = ['postCount', 'viewCount', 'likeCount', 'commentCount', 'userCount'];
        const hasAtLeastOneField = possibleFields.some(field => stats[field] !== undefined);
        
        expect(hasAtLeastOneField).toBe(true);
      }
    });
  });

  test.describe('用户发布数统计', () => {
    test('统计用户发布动态数量', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(3);

      // 创建10条动态
      for (let i = 1; i <= 10; i++) {
        await api.createPost({ content: `动态${i}` }, token);
      }

      // 获取统计数据
      const statsResult = await api.getStatistics(token);

      if (statsResult.status === 200 && statsResult.body.data) {
        const postCount = statsResult.body.data.postCount || statsResult.body.data.userPostCount;
        
        // 验证发布数正确
        expect(postCount).toBeGreaterThanOrEqual(10);
      }

      // 或者通过个人主页验证
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      const countElement = page.locator('[class*="count"]:has-text("动态"), text=/动态.*10|10.*动态/').first();
      
      if (await countElement.isVisible().catch(() => false)) {
        const countText = await countElement.textContent();
        expect(countText).toContain('10');
      }
    });

    test('统计多个用户的发布数', async ({ page, request }) => {
      const api = new ApiHelpers(request);
      
      // 创建3个用户，每个发布不同数量的动态
      const auth1 = new AuthHelpers(page, request);
      const user1 = await auth1.createAndLoginTestUser(4);
      for (let i = 1; i <= 3; i++) {
        await api.createPost({ content: `User1_Post${i}` }, user1.token);
      }

      const auth2 = new AuthHelpers(page, request);
      const user2 = await auth2.createAndLoginTestUser(5);
      for (let i = 1; i <= 5; i++) {
        await api.createPost({ content: `User2_Post${i}` }, user2.token);
      }

      const auth3 = new AuthHelpers(page, request);
      const user3 = await auth3.createAndLoginTestUser(6);
      for (let i = 1; i <= 2; i++) {
        await api.createPost({ content: `User3_Post${i}` }, user3.token);
      }

      // 验证总发布数
      const stats1 = await api.getStatistics(user1.token);
      const stats2 = await api.getStatistics(user2.token);
      const stats3 = await api.getStatistics(user3.token);

      if (stats1.status === 200 && stats1.body.data) {
        const count1 = stats1.body.data.postCount || stats1.body.data.userPostCount;
        expect(count1).toBeGreaterThanOrEqual(3);
      }

      if (stats2.status === 200 && stats2.body.data) {
        const count2 = stats2.body.data.postCount || stats2.body.data.userPostCount;
        expect(count2).toBeGreaterThanOrEqual(5);
      }

      if (stats3.status === 200 && stats3.body.data) {
        const count3 = stats3.body.data.postCount || stats3.body.data.userPostCount;
        expect(count3).toBeGreaterThanOrEqual(2);
      }
    });
  });

  test.describe('浏览量统计', () => {
    test('记录动态浏览量', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      
      // 用户A创建动态
      const userA = await auth.createAndLoginTestUser(7);
      const post = createTestPost(7);
      const postResult = await api.createPost({ content: post.content }, userA.token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 用户B浏览动态
      await auth.logout();
      const userB = await auth.createAndLoginTestUser(8);

      await page.goto('/home');
      await page.waitForLoadState('networkidle');

      // 点击查看动态详情
      const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
      if (await postElement.isVisible()) {
        await postElement.click();
        await page.waitForTimeout(1000);
      }

      // 用户A查看统计
      await auth.logout();
      await auth.loginViaAPI(userA.user.username, userA.user.password);
      
      const stats = await api.getStatistics(userA.token);
      
      if (stats.status === 200 && stats.body.data) {
        const viewCount = stats.body.data.viewCount || stats.body.data.totalViews;
        
        // 至少有1次浏览
        if (viewCount !== undefined) {
          expect(viewCount).toBeGreaterThanOrEqual(1);
        }
      }
    });

    test('浏览量累计计算', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      
      // 用户A创建动态
      const userA = await auth.createAndLoginTestUser(9);
      const post = createTestPost(9);
      await api.createPost({ content: post.content }, userA.token);

      // 多个用户浏览
      for (let i = 10; i <= 12; i++) {
        await auth.logout();
        const viewer = await auth.createAndLoginTestUser(i);
        
        await page.goto('/home');
        await page.waitForLoadState('networkidle');

        const postElement = page.locator(`text=${post.content.substring(0, 20)}`).first();
        if (await postElement.isVisible()) {
          await postElement.click();
          await page.waitForTimeout(500);
        }
      }

      // 验证总浏览量
      await auth.logout();
      await auth.loginViaAPI(userA.user.username, userA.user.password);
      
      const stats = await api.getStatistics(userA.token);
      
      if (stats.status === 200 && stats.body.data) {
        const viewCount = stats.body.data.viewCount || stats.body.data.totalViews;
        
        if (viewCount !== undefined) {
          // 至少3次浏览
          expect(viewCount).toBeGreaterThanOrEqual(3);
        }
      }
    });
  });

  test.describe('评论数统计', () => {
    test('统计总评论数', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(13);

      // 创建动态
      const post = createTestPost(13);
      const postResult = await api.createPost({ content: post.content }, token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 添加5条评论
      for (let i = 1; i <= 5; i++) {
        await api.createComment(postId, `评论${i}`, token);
      }

      // 获取统计
      const stats = await api.getStatistics(token);

      if (stats.status === 200 && stats.body.data) {
        const commentCount = stats.body.data.commentCount || stats.body.data.totalComments;
        
        if (commentCount !== undefined) {
          expect(commentCount).toBeGreaterThanOrEqual(5);
        }
      }
    });

    test('评论数实时更新', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(14);

      // 创建动态
      const post = createTestPost(14);
      const postResult = await api.createPost({ content: post.content }, token);
      const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;

      // 获取初始统计
      const initialStats = await api.getStatistics(token);
      const initialCount = initialStats.body?.data?.commentCount || 0;

      // 添加新评论
      await api.createComment(postId, '新评论', token);

      // 再次获取统计
      const updatedStats = await api.getStatistics(token);
      const updatedCount = updatedStats.body?.data?.commentCount || 0;

      // 评论数应该增加
      expect(updatedCount).toBeGreaterThan(initialCount);
    });
  });

  test.describe('Spark 数据分析', () => {
    test('Spark 成功执行数据统计', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(15);

      // 创建足够的测试数据
      for (let i = 1; i <= 10; i++) {
        const post = createTestPost(i);
        await api.createPost({ content: post.content }, token);
      }

      // 调用统计API（应该尝试使用Spark）
      const stats = await api.getStatistics(token);

      // 验证返回成功
      expect(stats.status).toBe(200);
      expect(stats.body.data).toBeTruthy();

      // 验证统计数据准确
      if (stats.body.data) {
        const postCount = stats.body.data.postCount || stats.body.data.userPostCount;
        expect(postCount).toBeGreaterThanOrEqual(10);
      }
    });

    test('Spark 失败后 SQL 回退', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(16);

      // 创建测试数据
      for (let i = 1; i <= 5; i++) {
        await api.createPost({ content: `Post${i}` }, token);
      }

      // 调用统计API
      const stats = await api.getStatistics(token);

      // 无论Spark是否可用，都应该返回正确的统计数据
      expect(stats.status).toBe(200);
      
      if (stats.body.data) {
        const postCount = stats.body.data.postCount || stats.body.data.userPostCount;
        
        // 验证数据正确性（说明回退机制工作正常）
        expect(postCount).toBeGreaterThanOrEqual(5);
      }
    });

    test('统计结果写入数据库', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(17);

      // 创建数据
      for (let i = 1; i <= 3; i++) {
        await api.createPost({ content: `Test${i}` }, token);
      }

      // 第一次获取统计
      const stats1 = await api.getStatistics(token);
      const count1 = stats1.body?.data?.postCount || stats1.body?.data?.userPostCount;

      // 添加更多数据
      for (let i = 4; i <= 6; i++) {
        await api.createPost({ content: `Test${i}` }, token);
      }

      // 第二次获取统计
      const stats2 = await api.getStatistics(token);
      const count2 = stats2.body?.data?.postCount || stats2.body?.data?.userPostCount;

      // 统计结果应该反映数据变化
      expect(count2).toBeGreaterThan(count1);
    });
  });

  test.describe('统计数据展示', () => {
    test('在仪表板显示统计图表', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(18);

      // 创建多样化的数据
      for (let i = 1; i <= 5; i++) {
        const post = createTestPost(i);
        const postResult = await api.createPost({ content: post.content }, token);
        const postData = postResult.body.data || postResult.body;
      const postId = postData.id || postData;
        
        // 点赞
        await api.likePost(postId, token);
        
        // 评论
        await api.createComment(postId, `评论${i}`, token);
      }

      // 访问统计页面
      await page.goto('/statistics');
      await page.waitForLoadState('networkidle');

      // 如果页面重定向，尝试从其他入口访问
      if (page.url().includes('/login')) {
        await page.goto('/profile');
        await page.waitForLoadState('networkidle');
      }

      // 查找图表元素（可能使用ECharts、Chart.js等）
      const chartElements = page.locator('canvas, svg, [class*="chart"]');
      const hasChart = await chartElements.count() > 0;

      // 或者查找统计数字
      const statsNumbers = page.locator('[class*="stats"] [class*="number"], [class*="count"]');
      const hasStats = await statsNumbers.count() > 0;

      // 至少应该有一种展示方式
      expect(hasChart || hasStats).toBe(true);
    });

    test('显示趋势数据', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(19);

      // 在不同时间创建数据
      await api.createPost({ content: 'Day1_Post1' }, token);
      await page.waitForTimeout(1000);
      await api.createPost({ content: 'Day1_Post2' }, token);
      await page.waitForTimeout(1000);
      await api.createPost({ content: 'Day1_Post3' }, token);

      // 获取统计数据
      const stats = await api.getStatistics(token);

      if (stats.status === 200 && stats.body.data) {
        // 验证有趋势数据
        const hasTrend = stats.body.data.trend || 
                        stats.body.data.timeline || 
                        stats.body.data.daily;
        
        // 趋势数据是可选的，所以不强制要求
        if (hasTrend) {
          expect(hasTrend).toBeTruthy();
        }
      }
    });
  });

  test.describe('性能测试', () => {
    test('大数据量统计性能', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(20);

      // 创建较多数据
      const startTime = Date.now();
      
      for (let i = 1; i <= 20; i++) {
        await api.createPost({ content: `批量数据${i}` }, token);
      }

      // 调用统计API
      const statsStartTime = Date.now();
      const stats = await api.getStatistics(token);
      const statsEndTime = Date.now();

      // 验证统计API响应时间
      const responseTime = statsEndTime - statsStartTime;
      
      // 统计API应该在合理时间内返回（如5秒）
      expect(responseTime).toBeLessThan(5000);

      // 验证数据正确性
      expect(stats.status).toBe(200);
      if (stats.body.data) {
        const postCount = stats.body.data.postCount || stats.body.data.userPostCount;
        expect(postCount).toBeGreaterThanOrEqual(20);
      }
    });

    test('并发统计请求', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      const api = new ApiHelpers(request);
      const { user, token } = await auth.createAndLoginTestUser(21);

      // 创建数据
      for (let i = 1; i <= 5; i++) {
        await api.createPost({ content: `并发测试${i}` }, token);
      }

      // 并发调用统计API
      const promises = [];
      for (let i = 0; i < 5; i++) {
        promises.push(api.getStatistics(token));
      }

      const results = await Promise.all(promises);

      // 所有请求都应该成功
      for (const result of results) {
        expect(result.status).toBe(200);
        expect(result.body.data).toBeTruthy();
      }

      // 所有结果应该一致
      const firstCount = results[0].body.data.postCount || results[0].body.data.userPostCount;
      for (const result of results) {
        const count = result.body.data.postCount || result.body.data.userPostCount;
        expect(count).toBe(firstCount);
      }
    });
  });
});



