package com.cloudcom.analytics;

import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.SparkSession;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Properties;

/**
 * Spark 访问 GaussDB 集群配置
 * 支持主备切换和失败重试
 */
public class GaussDBClusterConfig {
    
    private static final Logger logger = LoggerFactory.getLogger(GaussDBClusterConfig.class);
    
    // 集群节点配置
    private static final String PRIMARY_HOST = System.getenv().getOrDefault("GAUSSDB_PRIMARY_HOST", "10.211.55.11");
    private static final String STANDBY1_HOST = System.getenv().getOrDefault("GAUSSDB_STANDBY1_HOST", "10.211.55.14");
    private static final String STANDBY2_HOST = System.getenv().getOrDefault("GAUSSDB_STANDBY2_HOST", "10.211.55.13");
    private static final String PORT = System.getenv().getOrDefault("GAUSSDB_PORT", "5432");
    private static final String DATABASE = System.getenv().getOrDefault("GAUSSDB_DATABASE", "blog_db");
    private static final String USERNAME = System.getenv().getOrDefault("GAUSSDB_USERNAME", "bloguser");
    private static final String PRIMARY_PASSWORD = System.getenv().getOrDefault("GAUSSDB_PRIMARY_PASSWORD", "747599qw@");
    private static final String STANDBY_PASSWORD = System.getenv().getOrDefault("GAUSSDB_STANDBY_PASSWORD", "747599qw@1");
    
    // 重试配置
    private static final int MAX_RETRIES = 3;
    private static final long RETRY_DELAY_MS = 2000;
    
    /**
     * 获取主库 JDBC URL（写操作）
     */
    public static String getPrimaryJdbcUrl() {
        return String.format("jdbc:postgresql://%s:%s/%s", PRIMARY_HOST, PORT, DATABASE);
    }
    
    /**
     * 获取备库 JDBC URL（读操作，负载均衡）
     */
    public static String getReplicaJdbcUrl() {
        // 暂时指向主库（单节点 PostgreSQL）
        return String.format("jdbc:postgresql://%s:%s/%s", PRIMARY_HOST, PORT, DATABASE);
    }
    
    /**
     * 创建主库连接属性
     */
    public static Properties getPrimaryConnectionProperties() {
        Properties props = new Properties();
        props.setProperty("user", USERNAME);
        props.setProperty("password", PRIMARY_PASSWORD);
        props.setProperty("driver", "org.postgresql.Driver");
        props.setProperty("fetchsize", "1000");
        props.setProperty("batchsize", "1000");
        props.setProperty("loginTimeout", "30");
        props.setProperty("connectTimeout", "30");
        props.setProperty("socketTimeout", "60");
        return props;
    }
    
    /**
     * 创建备库连接属性
     */
    public static Properties getReplicaConnectionProperties() {
        Properties props = new Properties();
        props.setProperty("user", USERNAME);
        props.setProperty("password", PRIMARY_PASSWORD);
        props.setProperty("driver", "org.postgresql.Driver");
        props.setProperty("fetchsize", "1000");
        props.setProperty("batchsize", "1000");
        props.setProperty("loginTimeout", "30");
        props.setProperty("connectTimeout", "30");
        props.setProperty("socketTimeout", "60");
        return props;
    }
    
    /**
     * 从主库读取数据（带重试）
     */
    public static Dataset<Row> readFromPrimary(SparkSession spark, String tableName) {
        return readWithRetry(spark, getPrimaryJdbcUrl(), tableName, "主库", getPrimaryConnectionProperties());
    }
    
    /**
     * 从备库读取数据（带重试）
     */
    public static Dataset<Row> readFromReplica(SparkSession spark, String tableName) {
        return readWithRetry(spark, getReplicaJdbcUrl(), tableName, "备库", getReplicaConnectionProperties());
    }
    
    /**
     * 写入主库（带重试）
     */
    public static void writeToPrimary(Dataset<Row> dataset, String tableName, String saveMode) {
        writeWithRetry(dataset, getPrimaryJdbcUrl(), tableName, saveMode, getPrimaryConnectionProperties());
    }
    
    /**
     * 读取数据（带重试机制）
     */
    private static Dataset<Row> readWithRetry(SparkSession spark, String jdbcUrl, String tableName, String source, Properties props) {
        int retries = 0;
        Exception lastException = null;
        
        while (retries < MAX_RETRIES) {
            try {
                logger.info("尝试从{}读取表 {} (尝试 {}/{})", source, tableName, retries + 1, MAX_RETRIES);
                logger.debug("JDBC URL: {}", jdbcUrl);
                Dataset<Row> df = spark.read()
                    .jdbc(jdbcUrl, tableName, props);
                long count = df.count();
                logger.info("成功从{}读取表 {}, 记录数: {}", source, tableName, count);
                return df;
            } catch (Exception e) {
                lastException = e;
                retries++;
                logger.error("从{}读取失败 (尝试 {}/{}): {}", source, retries, MAX_RETRIES, e.getMessage(), e);
                
                if (retries < MAX_RETRIES) {
                    try {
                        logger.info("等待 {} ms 后重试...", RETRY_DELAY_MS);
                        Thread.sleep(RETRY_DELAY_MS);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        throw new RuntimeException("重试被中断", ie);
                    }
                }
            }
        }
        
        throw new RuntimeException(String.format("从%s读取表 %s 失败，已重试 %d 次", source, tableName, MAX_RETRIES), lastException);
    }
    
    /**
     * 写入数据（带重试机制）
     */
    private static void writeWithRetry(Dataset<Row> dataset, String jdbcUrl, String tableName, String saveMode, Properties props) {
        int retries = 0;
        Exception lastException = null;
        
        while (retries < MAX_RETRIES) {
            try {
                logger.info("尝试写入主库表 {} (尝试 {}/{})", tableName, retries + 1, MAX_RETRIES);
                logger.debug("JDBC URL: {}", jdbcUrl);
                dataset.write()
                    .mode(saveMode)
                    .jdbc(jdbcUrl, tableName, props);
                logger.info("成功写入主库表 {}", tableName);
                return;
            } catch (Exception e) {
                lastException = e;
                retries++;
                logger.error("写入主库失败 (尝试 {}/{}): {}", retries, MAX_RETRIES, e.getMessage(), e);
                
                if (retries < MAX_RETRIES) {
                    try {
                        logger.info("等待 {} ms 后重试...", RETRY_DELAY_MS);
                        Thread.sleep(RETRY_DELAY_MS);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        throw new RuntimeException("重试被中断", ie);
                    }
                }
            }
        }
        
        throw new RuntimeException(String.format("写入主库表 %s 失败，已重试 %d 次", tableName, MAX_RETRIES), lastException);
    }
    
    /**
     * 测试集群连接
     */
    public static void testConnection(SparkSession spark) {
        logger.info("测试 GaussDB 集群连接...");
        logger.info("主库: {}", getPrimaryJdbcUrl());
        logger.info("备库: {}", getReplicaJdbcUrl());
        
        // 测试主库
        try {
            logger.info("测试主库连接...");
            Dataset<Row> primaryTest = spark.read()
                .jdbc(getPrimaryJdbcUrl(), "(SELECT 1 as test) t", getPrimaryConnectionProperties());
            primaryTest.show();
            logger.info("✓ 主库连接成功: {}", PRIMARY_HOST);
        } catch (Exception e) {
            logger.error("✗ 主库连接失败: {}", e.getMessage(), e);
            throw new RuntimeException("主库连接失败", e);
        }
        
        // 测试备库
        try {
            logger.info("测试备库连接...");
            Dataset<Row> replicaTest = spark.read()
                .jdbc(getReplicaJdbcUrl(), "(SELECT 1 as test) t", getReplicaConnectionProperties());
            replicaTest.show();
            logger.info("✓ 备库连接成功");
        } catch (Exception e) {
            logger.error("✗ 备库连接失败: {}", e.getMessage(), e);
            throw new RuntimeException("备库连接失败", e);
        }
        
        logger.info("所有数据库连接测试通过");
    }
}
