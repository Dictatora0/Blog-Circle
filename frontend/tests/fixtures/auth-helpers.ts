/**
 * 认证辅助函数
 * 处理登录、注册等认证相关操作
 */

import { Page, APIRequestContext } from '@playwright/test';
import { createTestUser } from './test-data';
import { ApiHelpers } from './api-helpers';

export class AuthHelpers {
  constructor(
    private page: Page,
    private request: APIRequestContext
  ) {}

  /**
   * UI 登录
   * 通过前端页面进行登录操作
   */
  async loginViaUI(username: string, password: string) {
    await this.page.goto('/login');
    await this.page.waitForLoadState('networkidle');
    
    // 等待登录页面加载（Element Plus 组件）
    await this.page.waitForSelector('.login-page', { state: 'visible', timeout: 15000 });
    
    // Element Plus 的 input 实际在 .el-input__inner 内
    await this.page.waitForSelector('.el-input__inner[placeholder="用户名"]', { state: 'visible', timeout: 10000 });
    
    // 填写登录表单
    await this.page.locator('.el-input__inner[placeholder="用户名"]').fill(username);
    await this.page.locator('.el-input__inner[placeholder="密码"]').fill(password);
    
    // 点击登录按钮
    await this.page.locator('button.el-button--primary:has-text("登录")').click();
    
    // 等待导航到首页
    await this.page.waitForURL('/home', { timeout: 10000 });
    
    // 等待页面加载完成
    await this.page.waitForLoadState('networkidle');
  }

  /**
   * API 登录
   * 通过 API 直接登录，速度更快
   */
  async loginViaAPI(username: string, password: string) {
    const apiHelpers = new ApiHelpers(this.request);
    const result = await apiHelpers.login({ username, password });
    
    if (result.status === 200 && result.token) {
      // 将 token 存入 localStorage
      await this.page.addInitScript((token) => {
        localStorage.setItem('token', token);
      }, result.token);
      
      // 将用户信息存入 localStorage
      if (result.body?.data?.user) {
        await this.page.addInitScript((userInfo) => {
          localStorage.setItem('userInfo', JSON.stringify(userInfo));
        }, result.body.data.user);
      }
      
      return result.token;
    }
    
    throw new Error(`Login failed: ${result.body?.message || 'Unknown error'}`);
  }

  /**
   * UI 注册
   * 通过前端页面进行注册操作
   */
  async registerViaUI(userData: {
    username: string;
    password: string;
    email: string;
    nickname: string;
  }) {
    await this.page.goto('/register');
    await this.page.waitForLoadState('networkidle');
    
    // 等待注册页面加载（Element Plus 组件）
    await this.page.waitForSelector('.register-page', { state: 'visible', timeout: 15000 });
    
    // Element Plus 的 input 实际在 .el-input__inner 内
    await this.page.waitForSelector('.el-input__inner[placeholder="用户名"]', { state: 'visible', timeout: 10000 });
    
    // 填写注册表单
    await this.page.locator('.el-input__inner[placeholder="用户名"]').fill(userData.username);
    await this.page.locator('.el-input__inner[placeholder="密码"]').first().fill(userData.password);
    await this.page.locator('.el-input__inner[placeholder="确认密码"]').fill(userData.password);
    await this.page.locator('.el-input__inner[placeholder="邮箱"]').fill(userData.email);
    await this.page.locator('.el-input__inner[placeholder="昵称"]').fill(userData.nickname);
    
    // 点击注册按钮
    await this.page.locator('button.el-button--primary:has-text("注册")').click();
    
    // 等待跳转到登录页
    await this.page.waitForURL('/login', { timeout: 10000 });
  }

  /**
   * API 注册
   * 通过 API 直接注册
   */
  async registerViaAPI(userData: {
    username: string;
    password: string;
    email: string;
    nickname: string;
  }) {
    const apiHelpers = new ApiHelpers(this.request);
    const result = await apiHelpers.register(userData);
    
    if (result.status === 200) {
      return result.body;
    }
    
    throw new Error(`Registration failed: ${result.body?.message || 'Unknown error'}`);
  }

  /**
   * 创建并登录测试用户
   * 一站式创建用户并登录
   */
  async createAndLoginTestUser(index: number = 1) {
    const user = createTestUser(index);
    
    // 注册用户
    await this.registerViaAPI(user);
    
    // 登录
    const token = await this.loginViaAPI(user.username, user.password);
    
    return {
      user,
      token,
    };
  }

  /**
   * 登出
   */
  async logout() {
    // 先导航到登录页（确保在有效的上下文中）
    await this.page.goto('/login');
    await this.page.waitForLoadState('networkidle');
    
    // 清除 localStorage（现在在有效的页面上下文中）
    await this.page.evaluate(() => {
      try {
        localStorage.clear();
        sessionStorage.clear();
      } catch (e) {
        // 忽略错误，可能已经清除
      }
    });
  }

  /**
   * 检查是否已登录
   */
  async isLoggedIn(): Promise<boolean> {
    const token = await this.page.evaluate(() => {
      return localStorage.getItem('token');
    });
    return !!token;
  }

  /**
   * 获取当前用户的 token
   */
  async getToken(): Promise<string | null> {
    return await this.page.evaluate(() => {
      return localStorage.getItem('token');
    });
  }

  /**
   * 获取当前用户信息
   */
  async getCurrentUser() {
    return await this.page.evaluate(() => {
      const userInfoStr = localStorage.getItem('userInfo');
      return userInfoStr ? JSON.parse(userInfoStr) : null;
    });
  }

  /**
   * 等待登录成功
   */
  async waitForLogin(timeout: number = 10000) {
    await this.page.waitForFunction(
      () => {
        return localStorage.getItem('token') !== null;
      },
      { timeout }
    );
  }

  /**
   * 设置过期的 token（用于测试 token 过期场景）
   */
  async setExpiredToken() {
    await this.page.evaluate(() => {
      localStorage.setItem('token', 'expired_token_for_testing');
    });
  }
}

export default AuthHelpers;


