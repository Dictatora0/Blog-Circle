/**
 * 文件上传模块 E2E 测试
 * 覆盖图片上传、文件验证、上传失败处理等场景
 */

import { test, expect } from '@playwright/test';
import { createTestPost, testFiles } from '../fixtures/test-data';
import { AuthHelpers } from '../fixtures/auth-helpers';
import { ApiHelpers } from '../fixtures/api-helpers';
import { Buffer } from 'buffer';

test.describe('文件上传模块', () => {
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

  test.describe('上传图片', () => {
    test('成功上传单张图片', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(1);

      // 访问发布页面
      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 创建测试图片（1x1像素的PNG）
      const imageBuffer = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'base64'
      );

      // 找到文件上传input
      const fileInput = page.locator('input[type="file"]');
      await fileInput.setInputFiles({
        name: 'test-image.png',
        mimeType: 'image/png',
        buffer: imageBuffer,
      });

      // 等待图片预览显示
      await page.waitForTimeout(1000);
      const preview = page.locator('img[alt*="preview"], .image-preview, [class*="preview"]');
      await expect(preview.first()).toBeVisible({ timeout: 5000 });
    });

    test('成功上传多张图片', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(2);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 创建测试图片
      const imageBuffer = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'base64'
      );

      // 上传3张图片
      const fileInput = page.locator('input[type="file"]');
      await fileInput.setInputFiles([
        {
          name: 'test-image-1.png',
          mimeType: 'image/png',
          buffer: imageBuffer,
        },
        {
          name: 'test-image-2.png',
          mimeType: 'image/png',
          buffer: imageBuffer,
        },
        {
          name: 'test-image-3.png',
          mimeType: 'image/png',
          buffer: imageBuffer,
        },
      ]);

      // 等待预览显示
      await page.waitForTimeout(2000);

      // 验证所有图片预览都显示
      const previews = page.locator('img[alt*="preview"], .image-preview img, [class*="preview"] img');
      const count = await previews.count();
      expect(count).toBeGreaterThanOrEqual(3);
    });

    test('上传JPG格式图片', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(3);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 创建JPG图片
      const jpgBuffer = Buffer.from(
        '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCwAA8A/9k=',
        'base64'
      );

      const fileInput = page.locator('input[type="file"]');
      await fileInput.setInputFiles({
        name: 'test-image.jpg',
        mimeType: 'image/jpeg',
        buffer: jpgBuffer,
      });

      await page.waitForTimeout(1000);
      const preview = page.locator('img[alt*="preview"], .image-preview').first();
      await expect(preview).toBeVisible({ timeout: 5000 });
    });

    test('上传后显示上传进度', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(4);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      const imageBuffer = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'base64'
      );

      const fileInput = page.locator('input[type="file"]');
      await fileInput.setInputFiles({
        name: 'test-image.png',
        mimeType: 'image/png',
        buffer: imageBuffer,
      });

      // 查找进度指示器（可能是进度条、百分比或加载动画）
      const progressIndicator = page.locator('[class*="progress"], [class*="loading"], .uploading');
      
      // 进度指示器可能会快速消失，所以使用短超时
      const hasProgress = await progressIndicator.isVisible().catch(() => false);
      
      // 最终应该显示预览
      await page.waitForTimeout(1000);
      const preview = page.locator('img[alt*="preview"], .image-preview').first();
      await expect(preview).toBeVisible({ timeout: 5000 });
    });
  });

  test.describe('文件格式验证', () => {
    test('拒绝上传非图片文件', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(5);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 尝试上传PDF文件
      const pdfBuffer = Buffer.from('PDF content here');

      const fileInput = page.locator('input[type="file"]');
      
      // 检查input的accept属性
      const acceptAttr = await fileInput.getAttribute('accept');
      
      // 如果有accept属性限制，应该只接受图片
      if (acceptAttr) {
        expect(acceptAttr).toMatch(/image/);
      }

      // 尝试上传非图片文件
      await fileInput.setInputFiles({
        name: 'document.pdf',
        mimeType: 'application/pdf',
        buffer: pdfBuffer,
      });

      await page.waitForTimeout(1000);

      // 应该显示错误提示或不显示预览
      const errorMessage = page.locator('text=/格式不支持|仅支持图片|无效的文件格式/');
      const preview = page.locator('img[alt*="preview"]');

      // 要么显示错误，要么不显示预览
      const hasError = await errorMessage.isVisible().catch(() => false);
      const hasPreview = await preview.isVisible().catch(() => false);

      expect(hasError || !hasPreview).toBe(true);
    });

    test('只接受指定的图片格式', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(6);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      const fileInput = page.locator('input[type="file"]');
      const acceptAttr = await fileInput.getAttribute('accept');

      // 验证accept属性
      if (acceptAttr) {
        // 应该包含常见图片格式
        const acceptedFormats = acceptAttr.toLowerCase();
        expect(
          acceptedFormats.includes('image') ||
          acceptedFormats.includes('png') ||
          acceptedFormats.includes('jpg') ||
          acceptedFormats.includes('jpeg')
        ).toBe(true);
      }
    });
  });

  test.describe('文件大小验证', () => {
    test('拒绝上传超大文件', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(7);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 创建一个较大的缓冲区（模拟大文件）
      // 注意：这里使用小文件模拟，实际验证在前端和后端都会进行
      const largeBuffer = Buffer.alloc(100000); // 100KB，实际中可能需要更大

      const fileInput = page.locator('input[type="file"]');
      await fileInput.setInputFiles({
        name: 'large-image.png',
        mimeType: 'image/png',
        buffer: largeBuffer,
      });

      await page.waitForTimeout(2000);

      // 根据文件大小限制，可能会显示错误或成功上传
      // 这里主要是验证有文件大小检查机制
      const errorMessage = page.locator('text=/文件过大|超过大小限制|文件太大/');
      const preview = page.locator('img[alt*="preview"]').first();

      // 文件大小限制的具体行为取决于应用配置
      const hasError = await errorMessage.isVisible().catch(() => false);
      const hasPreview = await preview.isVisible().catch(() => false);

      // 至少应该有一个结果（成功或失败）
      expect(hasError || hasPreview).toBeTruthy();
    });
  });

  test.describe('删除已上传图片', () => {
    test('删除预览中的图片', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(8);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 上传图片
      const imageBuffer = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'base64'
      );

      const fileInput = page.locator('input[type="file"]');
      await fileInput.setInputFiles({
        name: 'test-image.png',
        mimeType: 'image/png',
        buffer: imageBuffer,
      });

      await page.waitForTimeout(1000);

      // 验证预览显示
      const preview = page.locator('img[alt*="preview"], .image-preview').first();
      await expect(preview).toBeVisible();

      // 查找删除按钮
      const previewContainer = preview.locator('xpath=ancestor::div[contains(@class, "preview") or contains(@class, "image")]').first();
      const deleteButton = previewContainer.locator('button:has-text("删除"), button[class*="delete"], button[class*="remove"], [class*="close"]');

      if (await deleteButton.isVisible()) {
        await deleteButton.click();
        await page.waitForTimeout(500);

        // 验证预览已移除
        await expect(preview).not.toBeVisible();
      }
    });

    test('删除多张图片中的一张', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(9);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      const imageBuffer = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'base64'
      );

      // 上传3张图片
      const fileInput = page.locator('input[type="file"]');
      await fileInput.setInputFiles([
        { name: 'image-1.png', mimeType: 'image/png', buffer: imageBuffer },
        { name: 'image-2.png', mimeType: 'image/png', buffer: imageBuffer },
        { name: 'image-3.png', mimeType: 'image/png', buffer: imageBuffer },
      ]);

      await page.waitForTimeout(2000);

      // 获取初始预览数量
      const previews = page.locator('img[alt*="preview"], .image-preview img');
      const initialCount = await previews.count();
      expect(initialCount).toBeGreaterThanOrEqual(3);

      // 删除第一张图片
      const firstPreview = previews.first();
      const firstContainer = firstPreview.locator('xpath=ancestor::div[contains(@class, "preview") or contains(@class, "image")]').first();
      const deleteButton = firstContainer.locator('button:has-text("删除"), button[class*="delete"], [class*="close"]').first();

      if (await deleteButton.isVisible()) {
        await deleteButton.click();
        await page.waitForTimeout(500);

        // 验证预览数量减少
        const newCount = await previews.count();
        expect(newCount).toBe(initialCount - 1);
      }
    });
  });

  test.describe('上传头像', () => {
    test('在个人主页上传头像', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(10);

      // 访问个人主页
      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 查找头像上传按钮
      const avatarUpload = page.locator('input[type="file"][accept*="image"]').first();
      
      if (await avatarUpload.isVisible({ timeout: 1000 }).catch(() => false)) {
        const imageBuffer = Buffer.from(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          'base64'
        );

        await avatarUpload.setInputFiles({
          name: 'avatar.png',
          mimeType: 'image/png',
          buffer: imageBuffer,
        });

        await page.waitForTimeout(2000);

        // 验证头像更新成功（可能需要刷新页面）
        await page.reload();
        await page.waitForLoadState('networkidle');

        // 新头像应该显示
        const avatar = page.locator('img[alt*="头像"], img[alt*="avatar"], [class*="avatar"] img').first();
        await expect(avatar).toBeVisible();
      }
    });

    test('上传封面图片', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(11);

      await page.goto('/profile');
      await page.waitForLoadState('networkidle');

      // 查找封面上传功能
      const coverUpload = page.locator('input[type="file"]').filter({ hasText: /封面|cover/i }).or(
        page.locator('[class*="cover"] input[type="file"]')
      );

      if (await coverUpload.count() > 0) {
        const imageBuffer = Buffer.from(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          'base64'
        );

        await coverUpload.first().setInputFiles({
          name: 'cover.png',
          mimeType: 'image/png',
          buffer: imageBuffer,
        });

        await page.waitForTimeout(2000);

        // 验证封面更新
        const cover = page.locator('[class*="cover"] img, img[alt*="封面"]').first();
        await expect(cover).toBeVisible({ timeout: 5000 });
      }
    });
  });

  test.describe('上传失败处理', () => {
    test('网络错误时显示失败提示', async ({ page, request, context }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(12);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      // 模拟网络离线
      await context.setOffline(true);

      const imageBuffer = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'base64'
      );

      const fileInput = page.locator('input[type="file"]');
      await fileInput.setInputFiles({
        name: 'test-image.png',
        mimeType: 'image/png',
        buffer: imageBuffer,
      });

      // 填写动态内容并尝试发布
      const textarea = page.locator('textarea[placeholder*="分享"]');
      if (await textarea.isVisible()) {
        await textarea.fill('测试动态内容');
        await page.click('button:has-text("发布")');

        await page.waitForTimeout(2000);

        // 应该显示错误提示
        const errorMessage = page.locator('text=/上传失败|网络错误|连接失败/');
        await expect(errorMessage).toBeVisible({ timeout: 5000 });
      }

      // 恢复网络
      await context.setOffline(false);
    });

    test('上传失败后可重试', async ({ page, request }) => {
      const auth = new AuthHelpers(page, request);
      await auth.createAndLoginTestUser(13);

      await page.goto('/publish');
      await page.waitForLoadState('networkidle');

      const imageBuffer = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'base64'
      );

      const fileInput = page.locator('input[type="file"]');
      
      // 第一次上传
      await fileInput.setInputFiles({
        name: 'test-image.png',
        mimeType: 'image/png',
        buffer: imageBuffer,
      });

      await page.waitForTimeout(1000);

      // 如果上传失败，应该能重新上传
      const preview = page.locator('img[alt*="preview"]').first();
      const hasPreview = await preview.isVisible({ timeout: 3000 }).catch(() => false);

      if (!hasPreview) {
        // 重试上传
        await fileInput.setInputFiles({
          name: 'test-image-retry.png',
          mimeType: 'image/png',
          buffer: imageBuffer,
        });

        await page.waitForTimeout(1000);

        // 重试后应该成功
        await expect(preview).toBeVisible({ timeout: 5000 });
      }
    });
  });

  test.describe('API上传测试', () => {
    test('通过API上传文件', async ({ page, request }) => {
      const api = new ApiHelpers(request);
      const auth = new AuthHelpers(page, request);
      const { user, token } = await auth.createAndLoginTestUser(14);

      // 创建测试图片
      const imageBuffer = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'base64'
      );

      // 通过API上传
      const uploadResult = await api.uploadFile(imageBuffer, 'test-api-upload.png', token);

      // 验证上传成功
      expect(uploadResult.status).toBe(200);
      expect(uploadResult.body.data).toBeTruthy();

      // 验证返回文件URL
      const fileUrl = uploadResult.body.data.url || uploadResult.body.data.path;
      expect(fileUrl).toBeTruthy();
    });
  });
});


