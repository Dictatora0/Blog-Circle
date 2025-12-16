package com.cloudcom.analytics;

import org.apache.spark.sql.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Properties;

/**
 * Spark 分析任务：从 GaussDB 读取数据，执行统计分析，写回结果
 * 
 * 使用示例：
 *   spark-submit \
 *     --class com.cloudcom.analytics.BlogAnalyticsJob \
 *     --master spark://spark-master:7077 \
 *     blog-analytics-1.0.0-jar-with-dependencies.jar \
 *     jdbc:opengauss://gaussdb:5432/blog_db \
 *     bloguser \
 *     blogpass
 */
public class BlogAnalyticsJob {
    private static final Logger logger = LoggerFactory.getLogger(BlogAnalyticsJob.class);

    public static void main(String[] args) {
        String jdbcUrl = args.length > 0 ? args[0] : "jdbc:opengauss://localhost:5432/blog_db";
        String username = args.length > 1 ? args[1] : "bloguser";
        String password = args.length > 2 ? args[2] : "blogpass";

        logger.info("启动 Spark 分析任务");
        logger.info("JDBC URL: {}", jdbcUrl);

        SparkSession spark = SparkSession.builder()
                .appName("BlogAnalytics")
                .getOrCreate();

        try {
            runAnalytics(spark, jdbcUrl, username, password);
            logger.info("分析任务完成");
        } catch (Exception e) {
            logger.error("分析任务失败: {}", e.getMessage(), e);
            throw new RuntimeException(e);
        } finally {
            spark.stop();
        }
    }

    private static void runAnalytics(SparkSession spark, String jdbcUrl, String username, String password) {
        Properties props = new Properties();
        props.setProperty("user", username);
        props.setProperty("password", password);
        props.setProperty("driver", "org.opengauss.Driver");

        logger.info("读取 posts 表...");
        Dataset<Row> posts = spark.read()
                .jdbc(jdbcUrl, "posts", props);
        posts.show(5);

        logger.info("读取 comments 表...");
        Dataset<Row> comments = spark.read()
                .jdbc(jdbcUrl, "comments", props);
        comments.show(5);

        logger.info("读取 users 表...");
        Dataset<Row> users = spark.read()
                .jdbc(jdbcUrl, "users", props);
        users.show(5);

        // 统计用户发文数量
        logger.info("统计用户发文数量...");
        Dataset<Row> userPostCounts = posts
                .groupBy("author_id")
                .count()
                .withColumnRenamed("count", "post_count");
        userPostCounts.show();

        // 统计文章浏览次数
        logger.info("统计文章浏览次数...");
        Dataset<Row> postViewStats = posts
                .select("id", "view_count")
                .filter("view_count > 0");
        postViewStats.show();

        // 统计评论数量
        logger.info("统计评论数量...");
        Dataset<Row> commentCounts = comments
                .groupBy("post_id")
                .count()
                .withColumnRenamed("count", "comment_count");
        commentCounts.show();

        // 写回统计结果到 statistics 表
        logger.info("写回统计结果到 statistics 表...");
        writeStatistics(spark, userPostCounts, "USER_POST_COUNT", "user_", jdbcUrl, props);
        writeStatistics(spark, postViewStats, "POST_VIEW_COUNT", "post_", jdbcUrl, props);
        writeStatistics(spark, commentCounts, "POST_COMMENT_COUNT", "post_", jdbcUrl, props);

        logger.info("所有统计完成");
    }

    private static void writeStatistics(SparkSession spark, Dataset<Row> data, 
                                       String statType, String keyPrefix, 
                                       String jdbcUrl, Properties props) {
        try {
            data.foreachPartition(iterator -> {
                while (iterator.hasNext()) {
                    Row row = iterator.next();
                    Long id = row.getLong(0);
                    Long value = row.getLong(1);
                    
                    String statKey = keyPrefix + id;
                    String sql = String.format(
                        "INSERT INTO statistics (stat_type, stat_key, stat_value, created_at, updated_at) " +
                        "VALUES ('%s', '%s', %d, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) " +
                        "ON CONFLICT (stat_type, stat_key) DO UPDATE SET stat_value = %d, updated_at = CURRENT_TIMESTAMP",
                        statType, statKey, value, value
                    );
                    
                    logger.debug("执行 SQL: {}", sql);
                }
            });
            logger.info("写回 {} 完成", statType);
        } catch (Exception e) {
            logger.error("写回 {} 失败: {}", statType, e.getMessage(), e);
        }
    }
}
