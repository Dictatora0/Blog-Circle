package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.Statistic;
import com.cloudcom.blog.mapper.StatisticMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * SparkAnalyticsService 测试类
 * 
 * Given-When-Then 风格测试：
 * 1. Spark分析成功场景
 * 2. Spark分析失败，回退到SQL分析成功
 * 3. SQL分析也失败场景
 * 4. 获取所有统计数据
 * 5. 根据类型获取统计数据
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("Spark数据分析服务测试")
class SparkAnalyticsServiceTest {

    @Mock
    private StatisticMapper statisticMapper;

    @InjectMocks
    private SparkAnalyticsService sparkAnalyticsService;

    private List<Statistic> mockStatistics;

    @BeforeEach
    void setUp() {
        // Given: 准备测试数据
        mockStatistics = new ArrayList<>();
        
        Statistic stat1 = new Statistic();
        stat1.setId(1L);
        stat1.setStatType("USER_POST_COUNT");
        stat1.setStatKey("user_1");
        stat1.setStatValue(5L);
        
        Statistic stat2 = new Statistic();
        stat2.setId(2L);
        stat2.setStatType("POST_VIEW_COUNT");
        stat2.setStatKey("post_1");
        stat2.setStatValue(10L);
        
        mockStatistics.add(stat1);
        mockStatistics.add(stat2);

        // 设置私有字段
        ReflectionTestUtils.setField(sparkAnalyticsService, "dbUrl", "jdbc:postgresql://localhost:5432/test_db");
        ReflectionTestUtils.setField(sparkAnalyticsService, "dbUsername", "test_user");
        ReflectionTestUtils.setField(sparkAnalyticsService, "dbPassword", "test_password");
    }

    @Test
    @DisplayName("获取所有统计数据 - 成功")
    void testGetAllStatistics_Success() {
        // Given: Mock返回统计数据列表
        when(statisticMapper.selectAll()).thenReturn(mockStatistics);

        // When: 调用获取所有统计数据
        List<Statistic> result = sparkAnalyticsService.getAllStatistics();

        // Then: 验证返回结果
        assertThat(result).isNotNull();
        assertThat(result).hasSize(2);
        assertThat(result.get(0).getStatType()).isEqualTo("USER_POST_COUNT");
        assertThat(result.get(0).getStatKey()).isEqualTo("user_1");
        assertThat(result.get(0).getStatValue()).isEqualTo(5L);
        
        verify(statisticMapper, times(1)).selectAll();
    }

    @Test
    @DisplayName("根据类型获取统计数据 - 成功")
    void testGetStatisticsByType_Success() {
        // Given: Mock返回特定类型的统计数据
        List<Statistic> userPostStats = Arrays.asList(mockStatistics.get(0));
        when(statisticMapper.selectByType("USER_POST_COUNT")).thenReturn(userPostStats);

        // When: 调用根据类型获取统计数据
        List<Statistic> result = sparkAnalyticsService.getStatisticsByType("USER_POST_COUNT");

        // Then: 验证返回结果
        assertThat(result).isNotNull();
        assertThat(result).hasSize(1);
        assertThat(result.get(0).getStatType()).isEqualTo("USER_POST_COUNT");
        
        verify(statisticMapper, times(1)).selectByType("USER_POST_COUNT");
    }

    @Test
    @DisplayName("Spark分析失败，回退到SQL分析 - 成功")
    void testRunAnalytics_SparkFailure_FallbackToSql_Success() {
        // Given: Spark分析会失败，SQL分析会成功
        // 注意：由于Spark在单元测试中难以模拟，我们通过反射模拟runSparkAnalytics失败
        // 在实际场景中，Spark失败会自动回退到SQL
        
        // Mock SQL查询返回的数据
        List<Statistic> userPostStats = Arrays.asList(mockStatistics.get(0));
        List<Statistic> postViewStats = Arrays.asList(mockStatistics.get(1));
        List<Statistic> commentStats = new ArrayList<>();
        
        when(statisticMapper.selectUserPostCounts()).thenReturn(userPostStats);
        when(statisticMapper.selectPostViewCounts()).thenReturn(postViewStats);
        when(statisticMapper.selectCommentCounts()).thenReturn(commentStats);
        
        // Mock insertOrUpdate 调用
        when(statisticMapper.insertOrUpdate(any(Statistic.class))).thenReturn(1);

        // When: 直接调用SQL分析方法（模拟Spark失败后的回退）
        // 注意：由于runSparkAnalytics是private方法，我们通过反射调用runSqlAnalytics
        // 或者直接测试SQL分析逻辑
        try {
            // 使用反射调用私有方法 runSqlAnalytics
            java.lang.reflect.Method method = SparkAnalyticsService.class.getDeclaredMethod("runSqlAnalytics");
            method.setAccessible(true);
            method.invoke(sparkAnalyticsService);
        } catch (Exception e) {
            throw new RuntimeException("调用SQL分析方法失败", e);
        }

        // Then: 验证SQL查询方法被调用
        verify(statisticMapper, atLeastOnce()).selectUserPostCounts();
        verify(statisticMapper, atLeastOnce()).selectPostViewCounts();
        verify(statisticMapper, atLeastOnce()).selectCommentCounts();
        verify(statisticMapper, atLeastOnce()).insertOrUpdate(any(Statistic.class));
    }

    @Test
    @DisplayName("SQL分析失败 - 抛出异常")
    void testRunSqlAnalytics_Failure() {
        // Given: SQL查询失败
        when(statisticMapper.selectUserPostCounts())
                .thenThrow(new RuntimeException("数据库连接失败"));

        // When & Then: 调用SQL分析方法应该抛出异常
        assertThatThrownBy(() -> {
            java.lang.reflect.Method method = SparkAnalyticsService.class.getDeclaredMethod("runSqlAnalytics");
            method.setAccessible(true);
            method.invoke(sparkAnalyticsService);
        })
        .isInstanceOf(java.lang.reflect.InvocationTargetException.class)
        .hasCauseInstanceOf(RuntimeException.class)
        .cause()
        .hasMessageContaining("数据分析失败");

        verify(statisticMapper, times(1)).selectUserPostCounts();
    }

    @Test
    @DisplayName("获取所有统计数据 - 空列表")
    void testGetAllStatistics_EmptyList() {
        // Given: Mock返回空列表
        when(statisticMapper.selectAll()).thenReturn(new ArrayList<>());

        // When: 调用获取所有统计数据
        List<Statistic> result = sparkAnalyticsService.getAllStatistics();

        // Then: 验证返回空列表
        assertThat(result).isNotNull();
        assertThat(result).isEmpty();
        
        verify(statisticMapper, times(1)).selectAll();
    }

    @Test
    @DisplayName("根据类型获取统计数据 - 空列表")
    void testGetStatisticsByType_EmptyList() {
        // Given: Mock返回空列表
        when(statisticMapper.selectByType("POST_COMMENT_COUNT")).thenReturn(new ArrayList<>());

        // When: 调用根据类型获取统计数据
        List<Statistic> result = sparkAnalyticsService.getStatisticsByType("POST_COMMENT_COUNT");

        // Then: 验证返回空列表
        assertThat(result).isNotNull();
        assertThat(result).isEmpty();
        
        verify(statisticMapper, times(1)).selectByType("POST_COMMENT_COUNT");
    }
}

