import request from '@/utils/request'

// 用户登录
export const login = (data) => {
  return request({
    url: '/auth/login',
    method: 'post',
    data
  })
}

// 用户注册
export const register = (data) => {
  return request({
    url: '/auth/register',
    method: 'post',
    data
  })
}

// 获取当前用户信息
export const getCurrentUser = () => {
  return request({
    url: '/users/current',
    method: 'get'
  })
}

// 更新用户信息
export const updateUser = (userId, data) => {
  return request({
    url: `/users/${userId}`,
    method: 'put',
    data
  })
}

// 更新用户封面
export const updateUserCover = (coverUrl) => {
  return request({
    url: '/users/cover',
    method: 'put',
    data: { coverUrl }
  })
}


