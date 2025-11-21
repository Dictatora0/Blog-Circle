package com.cloudcom.blog.service;

import com.cloudcom.blog.dto.StatisticsSummary;
import com.cloudcom.blog.entity.Statistic;
import com.cloudcom.blog.mapper.StatisticMapper;
import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.SparkSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Spark数据分析服务
 */
@Service
public class SparkAnalyticsService {

    private static final Logger logger = LoggerFactory.getLogger(SparkAnalyticsService.class);

    @Autowired
    private StatisticMapper statisticMapper;

    @Value("${spring.datasource.primary.jdbc-url:jdbc:opengauss://127.0.0.1:5432/blog_db}")
    private String dbUrl;

    @Value("${spring.datasource.primary.username:bloguser}")
    private String dbUsername;

    @Value("${spring.datasource.primary.password:Bloguser1234}")
    private String dbPassword;

    // 默认启用Spark，失败时回退到SQL分析
    @Value("${spark.enabled:true}")
    private boolean sparkEnabled = true;  // 默认值true，优先使用Spark

    /**
     * 执行数据分析
     * 默认优先使用Spark，失败时回退到SQL分析
     */
    public void runAnalytics() {
        // 默认优先使用Spark（更强大），失败时回退到SQL分析
        logger.info("开始执行数据分析，sparkEnabled配置: {}", sparkEnabled);
        
        if (sparkEnabled) {
            // 尝试使用Spark，失败则回退到SQL
            boolean sparkSuccess = false;
            try {
                logger.info("尝试使用Spark分析...");
                runSparkAnalytics();
                sparkSuccess = true;
                logger.info("Spark分析成功完成");
            } catch (Exception e) {
                logger.warn("Spark分析失败，回退到SQL查询: {}", e.getMessage());
                sparkSuccess = false;
            }
            
            // 如果Spark失败，使用SQL直接查询
            if (!sparkSuccess) {
                try {
                    runSqlAnalytics();
                    logger.info("SQL分析成功完成（Spark失败后的备用方案）");
                } catch (Exception e) {
                    logger.error("SQL分析也失败: {}", e.getMessage(), e);
                    throw new RuntimeException("数据分析失败: " + e.getMessage(), e);
                }
            }
        } else {
            // Spark被禁用，直接使用SQL分析
            logger.info("Spark功能已禁用，直接使用SQL分析");
            try {
                runSqlAnalytics();
                logger.info("SQL分析成功完成");
            } catch (Exception e) {
                logger.error("SQL分析失败: {}", e.getMessage(), e);
                throw new RuntimeException("数据分析失败: " + e.getMessage(), e);
            }
        }
    }

    /**
     * 使用Spark进行数据分析
     */
    private void runSparkAnalytics() {
        SparkSession spark = null;
        try {
            // 创建SparkSession
            // 添加配置以解决Java 17+安全管理器问题
            logger.info("开始创建SparkSession，配置安全管理器设置...");
            
            spark = SparkSession.builder()
                    .appName("BlogAnalytics")
                    .master("local[*]")
                    .config("spark.driver.host", "127.0.0.1")
                    .config("spark.driver.allowMultipleContexts", "false")
                    .config("spark.ui.enabled", "false")
                    .config("spark.sql.adaptive.enabled", "false")
                    .config("spark.sql.warehouse.dir", "file:${java.io.tmpdir}/spark-warehouse")
                    .config("spark.driver.memory", "1g")
                    .config("spark.executor.memory", "1g")
                    .config("spark.sql.shuffle.partitions", "1")
                    // 关键配置：禁用安全管理器以避免 getSubject 错误
                    .config("spark.security.manager.enabled", "false")
                    .config("spark.sql.crossJoin.enabled", "true")
                    // Java 17+ 兼容性配置
                    .config("spark.driver.extraJavaOptions", 
                            "-Djava.security.manager=allow " +
                            "-Djava.security.policy= " +
                            "-Dnet.bytebuddy.experimental=true")
                    .config("spark.executor.extraJavaOptions",
                            "-Djava.security.manager=allow " +
                            "-Djava.security.policy= " +
                            "-Dnet.bytebuddy.experimental=true")
                    .getOrCreate();
            
            logger.info("SparkSession创建成功，开始数据分析...");

            // 读取访问日志表
            logger.info("从数据库读取访问日志表");
            Properties connectionProperties = new Properties();
            connectionProperties.put("user", dbUsername);
            connectionProperties.put("password", dbPassword);
            connectionProperties.put("driver", "org.postgresql.Driver");
            
            Dataset<Row> accessLogs = spark.read()
                    .jdbc(dbUrl, "access_logs", connectionProperties);
            
            logger.info("成功读取访问日志表，记录数: {}", accessLogs.count());

            // 统计每个用户的发文数量
            Dataset<Row> postCountByUser = accessLogs
                    .filter("action = 'CREATE_POST'")
                    .groupBy("user_id")
                    .count()
                    .withColumnRenamed("count", "post_count");

            // 将结果写入统计表
            List<Row> postCounts = postCountByUser.collectAsList();
            for (Row row : postCounts) {
                Long userId = row.getLong(0);
                Long count = row.getLong(1);
                
                Statistic stat = new Statistic();
                stat.setStatType("USER_POST_COUNT");
                stat.setStatKey("user_" + userId);
                stat.setStatValue(count);
                insertOrUpdateStatistic(stat);
            }

            // 统计文章浏览次数
            Dataset<Row> viewCountByPost = accessLogs
                    .filter("action = 'VIEW_POST'")
                    .groupBy("post_id")
                    .count()
                    .withColumnRenamed("count", "view_count");

            List<Row> viewCounts = viewCountByPost.collectAsList();
            for (Row row : viewCounts) {
                Long postId = row.getLong(0);
                Long count = row.getLong(1);
                
                Statistic stat = new Statistic();
                stat.setStatType("POST_VIEW_COUNT");
                stat.setStatKey("post_" + postId);
                stat.setStatValue(count);
                insertOrUpdateStatistic(stat);
            }

            // 统计评论数量
            Dataset<Row> commentCountByPost = accessLogs
                    .filter("action = 'ADD_COMMENT'")
                    .groupBy("post_id")
                    .count()
                    .withColumnRenamed("count", "comment_count");

            List<Row> commentCounts = commentCountByPost.collectAsList();
            for (Row row : commentCounts) {
                Long postId = row.getLong(0);
                Long count = row.getLong(1);
                
                Statistic stat = new Statistic();
                stat.setStatType("POST_COMMENT_COUNT");
                stat.setStatKey("post_" + postId);
                stat.setStatValue(count);
                insertOrUpdateStatistic(stat);
            }

            logger.info("Spark分析完成，统计结果已写入数据库");

        } catch (Exception e) {
            logger.error("Spark分析过程中发生错误: {}", e.getMessage(), e);
            // 抛出异常以便上层捕获并回退到SQL
            throw new RuntimeException("Spark分析失败: " + e.getMessage(), e);
        } finally {
            // 确保Spark资源被释放
            if (spark != null) {
                try {
                    logger.info("正在关闭SparkSession...");
                    spark.stop();
                    logger.info("SparkSession已成功关闭");
                } catch (Exception ex) {
                    logger.warn("停止Spark会话失败: {}", ex.getMessage());
                }
            }
        }
    }

    /**
     * 使用SQL直接查询进行数据分析（Spark失败时的备用方案）
     */
    private void runSqlAnalytics() {
        try {
            // 统计每个用户的发文数量（从posts表）
            List<Statistic> userPostStats = statisticMapper.selectUserPostCounts();
            for (Statistic stat : userPostStats) {
                insertOrUpdateStatistic(stat);
            }

            // 统计文章浏览次数（从posts表的view_count字段）
            List<Statistic> postViewStats = statisticMapper.selectPostViewCounts();
            for (Statistic stat : postViewStats) {
                insertOrUpdateStatistic(stat);
            }

            // 统计评论数量（从comments表）
            List<Statistic> commentStats = statisticMapper.selectCommentCounts();
            for (Statistic stat : commentStats) {
                insertOrUpdateStatistic(stat);
            }

            logger.info("SQL分析完成");
        } catch (Exception e) {
            logger.error("SQL分析失败: {}", e.getMessage(), e);
            throw new RuntimeException("数据分析失败: " + e.getMessage(), e);
        }
    }

    /**
     * 获取所有统计结果
     */
    public List<Statistic> getAllStatistics() {
        return statisticMapper.selectAll();
    }

    /**
     * 获取统计汇总（聚合 + 明细）
     */
    public StatisticsSummary getStatisticsSummary() {
        StatisticsSummary summary = new StatisticsSummary();
        summary.setAggregated(getAggregatedStatistics());
        summary.setDetails(getAllStatistics());
        return summary;
    }

    /**
     * 根据类型获取统计结果
     */
    public List<Statistic> getStatisticsByType(String statType) {
        return statisticMapper.selectByType(statType);
    }

    /**
     * 获取聚合统计数据
     * 返回包含 postCount, viewCount, likeCount, commentCount, userCount 的聚合对象
     */
    public Map<String, Long> getAggregatedStatistics() {
        Map<String, Long> aggregated = new LinkedHashMap<>();

        // 从数据库直接查询统计数据（避免依赖statistics表）
        long postCount = statisticMapper.countTotalPosts();
        long viewCount = statisticMapper.countTotalViews();
        long likeCount = statisticMapper.countTotalLikes();
        long commentCount = statisticMapper.countTotalComments();
        long userCount = statisticMapper.countTotalUsers();

        aggregated.put("postCount", postCount);
        aggregated.put("viewCount", viewCount);
        aggregated.put("likeCount", likeCount);
        aggregated.put("commentCount", commentCount);
        aggregated.put("userCount", userCount);

        return aggregated;
    }

    /**
     * 插入或更新统计数据的辅助方法
     * 使用 UPSERT 操作（存在则更新，不存在则插入）
     */
    private void insertOrUpdateStatistic(Statistic stat) {
        statisticMapper.insertOrUpdate(stat);
    }
}
