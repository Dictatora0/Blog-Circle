/**
 * API 辅助函数
 * 封装常用的 API 调用，简化测试代码
 */

import { APIRequestContext } from '@playwright/test';

const TEST_ENV = process.env.TEST_ENV || 'local';
const API_BASE_URL = TEST_ENV === 'docker' 
  ? 'http://10.211.55.11:8080/api'
  : 'http://localhost:8080/api';

export class ApiHelpers {
  constructor(private request: APIRequestContext) {}

  /**
   * 获取请求头（带认证 token）
   */
  private getHeaders(token?: string) {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    
    return headers;
  }

  /**
   * 登录
   */
  async login(credentials: { username: string; password: string }) {
    const response = await this.request.post(`${API_BASE_URL}/auth/login`, {
      data: credentials,
      headers: this.getHeaders(),
    });

    const body = await response.json();
    const token = body?.data?.token || null;

    return {
      status: response.status(),
      body,
      token,
    };
  }

  /**
   * 注册
   */
  async register(userData: {
    username: string;
    password: string;
    email: string;
    nickname: string;
  }) {
    const response = await this.request.post(`${API_BASE_URL}/auth/register`, {
      data: userData,
      headers: this.getHeaders(),
    });

    const body = await response.json();

    return {
      status: response.status(),
      body,
    };
  }

  /**
   * 创建动态
   */
  async createPost(postData: { content: string; images?: string[] }, token: string) {
    const response = await this.request.post(`${API_BASE_URL}/posts`, {
      data: postData,
      headers: this.getHeaders(token),
    });

    const body = await response.json();

    return {
      status: response.status(),
      body,
    };
  }

  /**
   * 删除动态
   */
  async deletePost(postId: number, token: string) {
    const response = await this.request.delete(`${API_BASE_URL}/posts/${postId}`, {
      headers: this.getHeaders(token),
    });

    const body = await response.json();

    return {
      status: response.status(),
      body,
    };
  }

  /**
   * 创建评论
   */
  async createComment(postId: number, content: string, token: string) {
    const response = await this.request.post(`${API_BASE_URL}/comments`, {
      data: {
        postId,
        content,
      },
      headers: this.getHeaders(token),
    });

    const body = await response.json();

    return {
      status: response.status(),
      body,
    };
  }

  /**
   * 获取评论列表
   */
  async getComments(postId: number, token?: string) {
    const response = await this.request.get(`${API_BASE_URL}/comments/${postId}`, {
      headers: this.getHeaders(token),
    });

    const body = await response.json();

    return {
      status: response.status(),
      body,
    };
  }

  /**
   * 点赞动态
   */
  async likePost(postId: number, token: string) {
    const response = await this.request.post(`${API_BASE_URL}/likes/${postId}`, {
      headers: this.getHeaders(token),
    });

    const body = await response.json();

    return {
      status: response.status(),
      body,
    };
  }

  /**
   * 取消点赞
   */
  async unlikePost(postId: number, token: string) {
    const response = await this.request.delete(`${API_BASE_URL}/likes/${postId}`, {
      headers: this.getHeaders(token),
    });

    const body = await response.json();

    return {
      status: response.status(),
      body,
    };
  }

  /**
   * 上传文件
   */
  async uploadFile(fileBuffer: Buffer, filename: string, token: string) {
    const response = await this.request.post(`${API_BASE_URL}/upload/image`, {
      multipart: {
        file: {
          name: filename,
          mimeType: 'image/png',
          buffer: fileBuffer,
        },
      },
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });

    const body = await response.json();

    return {
      status: response.status(),
      body,
    };
  }

  /**
   * 获取统计数据
   */
  async getStats(type?: string, token?: string) {
    const url = type 
      ? `${API_BASE_URL}/stats/${type}`
      : `${API_BASE_URL}/stats`;
    
    const response = await this.request.get(url, {
      headers: this.getHeaders(token),
    });

    const body = await response.json();

    return {
      status: response.status(),
      body,
    };
  }

  /**
   * 获取统计数据（别名，兼容测试）
   */
  async getStatistics(token?: string) {
    return this.getStats(undefined, token);
  }

  /**
   * 运行数据分析
   */
  async analyzeStats(token: string) {
    const response = await this.request.post(`${API_BASE_URL}/stats/analyze`, {
      headers: this.getHeaders(token),
    });

    const body = await response.json();

    return {
      status: response.status(),
      body,
    };
  }
}

export default ApiHelpers;

