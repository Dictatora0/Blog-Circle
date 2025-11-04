/**
 * 测试数据生成工具
 * 提供生成测试用户、动态、评论等数据的函数
 */

/**
 * 生成测试用户数据
 */
export function createTestUser(index: number = 1) {
  // 使用较短的时间戳（取后6位）确保用户名不超过20字符
  const timestamp = Date.now().toString().slice(-6);
  return {
    username: `test${index}_${timestamp}`,  // 格式: test1_123456，最多12字符
    password: 'Test123456!',
    email: `testuser${index}_${timestamp}@test.com`,
    nickname: `测试用户${index}`,
  };
}

/**
 * 生成测试动态数据
 */
export function createTestPost(index: number = 1) {
  const timestamp = Date.now();
  return {
    content: `这是第${index}条测试动态 - ${timestamp}`,
    images: [] as string[],
  };
}

/**
 * 生成长动态数据
 */
export function createLongPost(index: number = 1) {
  const timestamp = Date.now();
  const longContent = `这是第${index}条长动态测试 - ${timestamp}\n`.repeat(10);
  return {
    content: longContent,
    images: [] as string[],
  };
}

/**
 * 生成测试评论数据
 */
export function createTestComment(index: number = 1) {
  const timestamp = Date.now();
  return {
    content: `这是第${index}条测试评论 - ${timestamp}`,
  };
}

/**
 * 无效数据集合（用于测试验证）
 */
export const invalidData = {
  emptyUsername: '',
  emptyPassword: '',
  emptyEmail: '',
  invalidEmail: 'not-an-email',
  shortPassword: '123',
  longUsername: 'a'.repeat(101),
  xssContent: '<script>alert("XSS")</script>',
  sqlInjection: "'; DROP TABLE users; --",
};

/**
 * 测试文件数据
 */
import { Buffer } from 'buffer';

export const testFiles = {
  validImage: {
    name: 'test-image.png',
    mimeType: 'image/png',
    buffer: Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      'base64'
    ),
  },
  invalidFile: {
    name: 'test.txt',
    mimeType: 'text/plain',
    buffer: Buffer.from('This is not an image'),
  },
};
