import request from '@/utils/request'

// 触发Spark分析
export const runAnalytics = () => {
  return request({
    url: '/stats/analyze',
    method: 'post'
  })
}

// 获取所有统计数据
export const getAllStatistics = () => {
  return request({
    url: '/stats',
    method: 'get'
  })
}

// 根据类型获取统计数据
export const getStatisticsByType = (type) => {
  return request({
    url: `/stats/${type}`,
    method: 'get'
  })
}


