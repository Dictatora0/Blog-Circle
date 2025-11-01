import request from '@/utils/request'

// 上传图片
export const uploadImage = (file) => {
  const formData = new FormData()
  formData.append('file', file)
  
  return request({
    url: '/upload/image',
    method: 'post',
    data: formData,
    headers: {
      'Content-Type': 'multipart/form-data'
    }
  })
}

// 点赞/取消点赞
export const toggleLike = (postId) => {
  return request({
    url: `/likes/${postId}`,
    method: 'post'
  })
}

// 检查是否已点赞
export const checkLike = (postId) => {
  return request({
    url: `/likes/${postId}/check`,
    method: 'get'
  })
}

// 获取点赞数
export const getLikeCount = (postId) => {
  return request({
    url: `/likes/${postId}/count`,
    method: 'get'
  })
}

