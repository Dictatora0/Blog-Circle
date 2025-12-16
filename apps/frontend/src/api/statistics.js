import request from "@/utils/request";

// 触发 Spark 分析
export const runAnalytics = () => {
  return request({
    url: "/stats/analyze",
    method: "post",
  });
};

// 获取统计汇总（聚合 + 明细）
export const getStatisticsSummary = () => {
  return request({
    url: "/stats",
    method: "get",
  });
};

// 仅获取聚合统计数据
export const getAggregatedStatistics = () => {
  return request({
    url: "/stats/aggregated",
    method: "get",
  });
};

// 获取全部统计明细列表
export const getAllStatistics = () => {
  return request({
    url: "/stats/list",
    method: "get",
  });
};

// 根据类型获取统计数据
export const getStatisticsByType = (type) => {
  return request({
    url: `/stats/${type}`,
    method: "get",
  });
};
