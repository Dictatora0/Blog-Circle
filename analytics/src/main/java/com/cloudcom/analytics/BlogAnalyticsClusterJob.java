package com.cloudcom.analytics;

import org.apache.spark.sql.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Spark 分析任务：访问 GaussDB 一主二备集群
 * 读操作使用备库，写操作使用主库
 */
public class BlogAnalyticsClusterJob {
    private static final Logger logger = LoggerFactory.getLogger(BlogAnalyticsClusterJob.class);

    public static void main(String[] args) {
        logger.info("启动 Spark 分析任务（GaussDB 集群模式）");

        SparkSession spark = SparkSession.builder()
                .appName("BlogAnalyticsCluster")
                .getOrCreate();

        try {
            // 测试集群连接
            GaussDBClusterConfig.testConnection(spark);
            
            // 执行分析任务
            runAnalytics(spark);
            
            logger.info("分析任务完成");
        } catch (Exception e) {
            logger.error("分析任务失败: {}", e.getMessage(), e);
            throw new RuntimeException(e);
        } finally {
            spark.stop();
        }
    }

    private static void runAnalytics(SparkSession spark) {
        logger.info("开始数据分析...");

        // 从备库读取数据（读操作）
        logger.info("从备库读取 posts 表...");
        Dataset<Row> posts = GaussDBClusterConfig.readFromReplica(spark, "posts");
        posts.show(5);

        logger.info("从备库读取 comments 表...");
        Dataset<Row> comments = GaussDBClusterConfig.readFromReplica(spark, "comments");
        comments.show(5);

        logger.info("从备库读取 users 表...");
        Dataset<Row> users = GaussDBClusterConfig.readFromReplica(spark, "users");
        users.show(5);

        // 统计用户发文数量
        logger.info("统计用户发文数量...");
        Dataset<Row> userPostCounts = posts
                .groupBy("author_id")
                .count()
                .withColumnRenamed("count", "post_count")
                .withColumnRenamed("author_id", "user_id");
        userPostCounts.show();

        // 统计文章浏览次数
        logger.info("统计文章浏览次数...");
        Dataset<Row> postViewStats = posts
                .select(
                    functions.col("id").alias("post_id"),
                    functions.col("view_count")
                )
                .filter("view_count > 0");
        postViewStats.show();

        // 统计评论数量
        logger.info("统计评论数量...");
        Dataset<Row> commentCounts = comments
                .groupBy("post_id")
                .count()
                .withColumnRenamed("count", "comment_count");
        commentCounts.show();

        // 写入主库（写操作）
        logger.info("写回统计结果到主库...");
        writeUserPostStats(spark, userPostCounts);
        writePostViewStats(spark, postViewStats);
        writeCommentStats(spark, commentCounts);

        logger.info("所有统计完成");
    }

    private static void writeUserPostStats(SparkSession spark, Dataset<Row> data) {
        logger.info("写入用户发文统计...");
        
        Dataset<Row> statsData = data.select(
            functions.lit("USER_POST_COUNT").alias("stat_type"),
            functions.concat(functions.lit("user_"), functions.col("user_id")).alias("stat_key"),
            functions.col("post_count").alias("stat_value"),
            functions.current_timestamp().alias("created_at"),
            functions.current_timestamp().alias("updated_at")
        );
        
        // 使用 append 模式写入主库
        GaussDBClusterConfig.writeToPrimary(statsData, "statistics", "append");
        logger.info("用户发文统计写入完成");
    }

    private static void writePostViewStats(SparkSession spark, Dataset<Row> data) {
        logger.info("写入文章浏览统计...");
        
        Dataset<Row> statsData = data.select(
            functions.lit("POST_VIEW_COUNT").alias("stat_type"),
            functions.concat(functions.lit("post_"), functions.col("post_id")).alias("stat_key"),
            functions.col("view_count").alias("stat_value"),
            functions.current_timestamp().alias("created_at"),
            functions.current_timestamp().alias("updated_at")
        );
        
        GaussDBClusterConfig.writeToPrimary(statsData, "statistics", "append");
        logger.info("文章浏览统计写入完成");
    }

    private static void writeCommentStats(SparkSession spark, Dataset<Row> data) {
        logger.info("写入评论统计...");
        
        Dataset<Row> statsData = data.select(
            functions.lit("POST_COMMENT_COUNT").alias("stat_type"),
            functions.concat(functions.lit("post_"), functions.col("post_id")).alias("stat_key"),
            functions.col("comment_count").alias("stat_value"),
            functions.current_timestamp().alias("created_at"),
            functions.current_timestamp().alias("updated_at")
        );
        
        GaussDBClusterConfig.writeToPrimary(statsData, "statistics", "append");
        logger.info("评论统计写入完成");
    }
}
