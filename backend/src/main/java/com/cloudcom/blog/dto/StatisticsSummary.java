package com.cloudcom.blog.dto;

import com.cloudcom.blog.entity.Statistic;

import java.util.List;
import java.util.Map;

/**
 * 封装聚合统计数据以及明细列表
 */
public class StatisticsSummary {
    private Map<String, Long> aggregated;
    private List<Statistic> details;

    public Map<String, Long> getAggregated() {
        return aggregated;
    }

    public void setAggregated(Map<String, Long> aggregated) {
        this.aggregated = aggregated;
    }

    public List<Statistic> getDetails() {
        return details;
    }

    public void setDetails(List<Statistic> details) {
        this.details = details;
    }
}
