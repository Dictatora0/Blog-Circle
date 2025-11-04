// 配置文件

// API基础URL
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080/api'

// 资源基础URL（用于图片等静态资源）
export const RESOURCE_BASE_URL = import.meta.env.VITE_RESOURCE_BASE_URL || 'http://localhost:8080'

/**
 * 获取完整的资源URL
 * @param {string} path - 资源路径（可能是相对路径或完整URL）
 * @returns {string} - 完整的资源URL
 */
export function getResourceUrl(path) {
  if (!path) return ''
  
  // 如果已经是完整URL，直接返回
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path
  }
  
  // 如果是相对路径，添加基础URL
  const cleanPath = path.startsWith('/') ? path : `/${path}`
  return `${RESOURCE_BASE_URL}${cleanPath}`
}

/**
 * 获取默认头像URL（使用SVG）
 * @returns {string} - 默认头像的Data URL
 */
export function getDefaultAvatar() {
  return "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'%3E%3Ccircle cx='20' cy='20' r='20' fill='%23E0E7FF'/%3E%3Ctext x='50%25' y='50%25' dominant-baseline='middle' text-anchor='middle' font-size='16' fill='%23667eea' font-family='Arial, sans-serif'%3E👤%3C/text%3E%3C/svg%3E"
}

/**
 * 获取默认封面URL（使用渐变背景）
 * @returns {string} - 默认封面的Data URL
 */
export function getDefaultCover() {
  return "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='800' height='200' viewBox='0 0 800 200'%3E%3Cdefs%3E%3ClinearGradient id='grad' x1='0%25' y1='0%25' x2='100%25' y2='100%25'%3E%3Cstop offset='0%25' style='stop-color:%23667eea;stop-opacity:1' /%3E%3Cstop offset='100%25' style='stop-color:%23764ba2;stop-opacity:1' /%3E%3C/linearGradient%3E%3C/defs%3E%3Crect width='800' height='200' fill='url(%23grad)' /%3E%3C/svg%3E"
}
