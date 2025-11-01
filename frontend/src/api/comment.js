import request from '@/utils/request'

// 获取文章评论列表
export const getCommentsByPostId = (postId) => {
  return request({
    url: `/comments/post/${postId}`,
    method: 'get'
  })
}

// 创建评论
export const createComment = (data) => {
  return request({
    url: '/comments',
    method: 'post',
    data
  })
}

// 更新评论
export const updateComment = (id, data) => {
  return request({
    url: `/comments/${id}`,
    method: 'put',
    data
  })
}

// 删除评论
export const deleteComment = (id) => {
  return request({
    url: `/comments/${id}`,
    method: 'delete'
  })
}

// 获取我的评论
export const getMyComments = () => {
  return request({
    url: '/comments/my',
    method: 'get'
  })
}


