import axios from 'axios'
import { useUserStore } from '@/stores/user'

const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
  timeout: 10000
})

// 请求拦截器
request.interceptors.request.use(
  config => {
    const userStore = useUserStore()
    if (userStore.token) {
      config.headers.Authorization = `Bearer ${userStore.token}`
    }
    return config
  },
  error => {
    return Promise.reject(error)
  }
)

// 响应拦截器
request.interceptors.response.use(
  response => {
    // 统一处理响应格式
    // 如果业务code不是200，视为错误
    if (response.data && typeof response.data === 'object') {
      const code = response.data.code
      // 业务code不是200时，抛出错误以便catch块处理
      if (code && code !== 200) {
        return Promise.reject({
          response: {
            data: response.data
          },
          message: response.data.message || '请求失败'
        })
      }
      return response
    }
    return response
  },
  error => {
    if (error.response?.status === 401) {
      const userStore = useUserStore()
      userStore.logout()
      window.location.href = '/login'
    }
    // 统一处理错误响应格式
    if (error.response?.data) {
      return Promise.reject(error)
    }
    return Promise.reject(error)
  }
)

export default request
