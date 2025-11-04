package com.cloudcom.blog.controller;

import com.cloudcom.blog.common.Result;
import com.cloudcom.blog.entity.Statistic;
import com.cloudcom.blog.service.SparkAnalyticsService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 统计分析控制器
 */
@RestController
@RequestMapping("/api/stats")
public class StatisticsController {

    @Autowired
    private SparkAnalyticsService sparkAnalyticsService;

    /**
     * 触发Spark分析
     */
    @PostMapping("/analyze")
    public Result<Void> runAnalytics() {
        try {
            sparkAnalyticsService.runAnalytics();
            return Result.success("分析完成", null);
        } catch (Exception e) {
            // 返回错误响应，状态码500
            return Result.error("分析失败: " + e.getMessage());
        }
    }

    /**
     * 获取所有统计结果
     * 返回聚合统计数据（包含 postCount, viewCount, likeCount, commentCount, userCount）
     */
    @GetMapping
    public Result<Map<String, Object>> getAllStatistics() {
        try {
            Map<String, Object> aggregated = sparkAnalyticsService.getAggregatedStatistics();
            return Result.success(aggregated);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 根据类型获取统计结果
     */
    @GetMapping("/{type}")
    public Result<List<Statistic>> getStatisticsByType(@PathVariable String type) {
        try {
            List<Statistic> statistics = sparkAnalyticsService.getStatisticsByType(type);
            return Result.success(statistics);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }
}




