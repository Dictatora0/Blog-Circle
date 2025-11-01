import request from '@/utils/request'

// 获取文章列表
export const getPostList = () => {
  return request({
    url: '/posts/list',
    method: 'get'
  })
}

// 获取文章详情
export const getPostDetail = (id) => {
  return request({
    url: `/posts/${id}/detail`,
    method: 'get'
  })
}

// 创建文章
export const createPost = (data) => {
  return request({
    url: '/posts',
    method: 'post',
    data
  })
}

// 更新文章
export const updatePost = (id, data) => {
  return request({
    url: `/posts/${id}`,
    method: 'put',
    data
  })
}

// 删除文章
export const deletePost = (id) => {
  return request({
    url: `/posts/${id}`,
    method: 'delete'
  })
}

// 获取我的文章
export const getMyPosts = () => {
  return request({
    url: '/posts/my',
    method: 'get'
  })
}


