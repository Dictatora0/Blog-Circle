package com.cloudcom.blog.config;

import com.zaxxer.hikari.HikariDataSource;
import org.apache.ibatis.session.SqlSessionFactory;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.annotation.MapperScan;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.lookup.AbstractRoutingDataSource;
import org.springframework.transaction.PlatformTransactionManager;

import javax.sql.DataSource;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;

/**
 * openGauss 集群数据源配置
 * 实现读写分离：主库写，备库读（负载均衡）
 */
@Configuration
@ConditionalOnProperty(name = "spring.profiles.active", havingValue = "opengauss-cluster")
@MapperScan(basePackages = "com.cloudcom.blog.mapper", sqlSessionFactoryRef = "sqlSessionFactory")
public class OpenGaussDataSourceConfig {

    /**
     * 主库数据源（写操作）
     */
    @Bean(name = "primaryDataSource")
    @ConfigurationProperties(prefix = "spring.datasource.primary")
    public DataSource primaryDataSource() {
        return DataSourceBuilder.create().type(HikariDataSource.class).build();
    }

    /**
     * 备库1数据源（读操作）
     */
    @Bean(name = "replica1DataSource")
    @ConfigurationProperties(prefix = "spring.datasource.replica1")
    public DataSource replica1DataSource() {
        HikariDataSource dataSource = DataSourceBuilder.create().type(HikariDataSource.class).build();
        dataSource.setReadOnly(true);
        return dataSource;
    }

    /**
     * 备库2数据源（读操作）
     */
    @Bean(name = "replica2DataSource")
    @ConfigurationProperties(prefix = "spring.datasource.replica2")
    public DataSource replica2DataSource() {
        HikariDataSource dataSource = DataSourceBuilder.create().type(HikariDataSource.class).build();
        dataSource.setReadOnly(true);
        return dataSource;
    }

    /**
     * 动态路由数据源
     */
    @Bean(name = "routingDataSource")
    @Primary
    public DataSource routingDataSource(
            @Qualifier("primaryDataSource") DataSource primaryDataSource,
            @Qualifier("replica1DataSource") DataSource replica1DataSource,
            @Qualifier("replica2DataSource") DataSource replica2DataSource) {
        
        DynamicRoutingDataSource routingDataSource = new DynamicRoutingDataSource();
        
        Map<Object, Object> targetDataSources = new HashMap<>();
        targetDataSources.put(DataSourceType.PRIMARY, primaryDataSource);
        targetDataSources.put(DataSourceType.REPLICA1, replica1DataSource);
        targetDataSources.put(DataSourceType.REPLICA2, replica2DataSource);
        
        routingDataSource.setTargetDataSources(targetDataSources);
        routingDataSource.setDefaultTargetDataSource(primaryDataSource);
        
        return routingDataSource;
    }

    /**
     * SqlSessionFactory
     */
    @Bean(name = "sqlSessionFactory")
    public SqlSessionFactory sqlSessionFactory(@Qualifier("routingDataSource") DataSource dataSource) throws Exception {
        SqlSessionFactoryBean sessionFactory = new SqlSessionFactoryBean();
        sessionFactory.setDataSource(dataSource);
        sessionFactory.setTypeAliasesPackage("com.cloudcom.blog.entity");
        sessionFactory.setMapperLocations(
            new PathMatchingResourcePatternResolver().getResources("classpath:mapper/*.xml")
        );
        return sessionFactory.getObject();
    }

    /**
     * 事务管理器
     */
    @Bean(name = "transactionManager")
    public PlatformTransactionManager transactionManager(@Qualifier("routingDataSource") DataSource dataSource) {
        return new DataSourceTransactionManager(dataSource);
    }

    /**
     * 动态路由数据源实现（支持读负载均衡）
     */
    static class DynamicRoutingDataSource extends AbstractRoutingDataSource {
        @Override
        protected Object determineCurrentLookupKey() {
            DataSourceType type = DataSourceContextHolder.getDataSourceType();
            // 如果是读操作，随机选择一个备库
            if (type == DataSourceType.REPLICA1 || type == DataSourceType.REPLICA2) {
                return ThreadLocalRandom.current().nextBoolean() ? DataSourceType.REPLICA1 : DataSourceType.REPLICA2;
            }
            return type;
        }
    }

    /**
     * 数据源类型枚举
     */
    public enum DataSourceType {
        PRIMARY,   // 主库
        REPLICA1,  // 备库1
        REPLICA2   // 备库2
    }

    /**
     * 数据源上下文持有者（线程安全）
     */
    public static class DataSourceContextHolder {
        private static final ThreadLocal<DataSourceType> contextHolder = new ThreadLocal<>();

        public static void setDataSourceType(DataSourceType dataSourceType) {
            contextHolder.set(dataSourceType);
        }

        public static DataSourceType getDataSourceType() {
            return contextHolder.get() == null ? DataSourceType.PRIMARY : contextHolder.get();
        }

        public static void clearDataSourceType() {
            contextHolder.remove();
        }
    }
}
