/**
 * 应用配置
 */

// 获取 API 基础 URL
export const getApiBaseUrl = () => {
  // 生产环境使用当前域名
  if (import.meta.env.PROD) {
    return window.location.origin
  }
  // 开发环境使用环境变量或默认值
  return import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'
}

// 获取完整的资源 URL
export const getResourceUrl = (path) => {
  if (!path) return ''
  // 如果已经是完整 URL，直接返回
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path
  }
  // 拼接基础 URL
  const baseUrl = getApiBaseUrl()
  return `${baseUrl}${path}`
}

export default {
  getApiBaseUrl,
  getResourceUrl
}

