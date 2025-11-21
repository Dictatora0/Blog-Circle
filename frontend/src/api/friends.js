import request from '@/utils/request'

// 发送好友请求
export const sendFriendRequest = (receiverId) => {
  return request({
    url: `/friends/request/${receiverId}`,
    method: 'post'
  })
}

// 接受好友请求
export const acceptFriendRequest = (requestId) => {
  return request({
    url: `/friends/accept/${requestId}`,
    method: 'post'
  })
}

// 拒绝好友请求
export const rejectFriendRequest = (requestId) => {
  return request({
    url: `/friends/reject/${requestId}`,
    method: 'post'
  })
}

// 删除好友（通过用户ID）
export const deleteFriend = (friendUserId) => {
  return request({
    url: `/friends/user/${friendUserId}`,
    method: 'delete'
  })
}

// 获取好友列表
export const getFriendList = () => {
  return request({
    url: '/friends/list',
    method: 'get'
  })
}

// 获取待处理的好友请求
export const getPendingRequests = () => {
  return request({
    url: '/friends/requests',
    method: 'get'
  })
}

// 获取我发送的好友请求
export const getSentRequests = () => {
  return request({
    url: '/friends/sent-requests',
    method: 'get'
  })
}

// 搜索用户
export const searchUsers = (keyword) => {
  return request({
    url: '/friends/search',
    method: 'get',
    params: { keyword }
  })
}

// 检查好友关系状态
export const getFriendshipStatus = (userId) => {
  return request({
    url: `/friends/status/${userId}`,
    method: 'get'
  })
}

// 获取好友时间线
export const getFriendTimeline = () => {
  return request({
    url: '/posts/timeline',
    method: 'get'
  })
}

