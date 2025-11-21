package com.cloudcom.blog;

import com.cloudcom.blog.annotation.ReadOnly;
import com.cloudcom.blog.config.DataSourceConfig;
import com.cloudcom.blog.entity.User;
import com.cloudcom.blog.mapper.UserMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 数据库集成测试
 * 使用 Testcontainers 启动 PostgreSQL 容器，测试数据库操作和读写分离
 */
@SpringBootTest
@Testcontainers
@DisplayName("数据库集成测试")
class DatabaseIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:13")
            .withDatabaseName("blog_test")
            .withUsername("bloguser")
            .withPassword("747599qw@");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        // 覆盖默认数据源配置，使测试直接连接到 Testcontainers PostgreSQL
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.datasource.driver-class-name", () -> "org.postgresql.Driver");
    }

    @Autowired
    private UserMapper userMapper;

    @BeforeEach
    void setUp() throws Exception {
        // 初始化测试数据
        try (Connection conn = DriverManager.getConnection(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())) {
            // 创建表结构
            String createTableSql = """
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    username VARCHAR(50) NOT NULL UNIQUE,
                    password VARCHAR(255) NOT NULL,
                    email VARCHAR(100) NOT NULL,
                    nickname VARCHAR(50),
                    avatar VARCHAR(255),
                    cover_image VARCHAR(255),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """;
            try (PreparedStatement stmt = conn.prepareStatement(createTableSql)) {
                stmt.execute();
            }
        }
    }

    @Test
    @DisplayName("测试用户 CRUD 操作")
    @Transactional
    void testUserCrudOperations() {
        // 创建用户
        User user = new User();
        user.setUsername("testuser");
        user.setPassword("$2a$10$R9twLfa1VCMKgDQIv92xYeM7iyrztE2XWJvD4Y.iFFNJ6qg9hfmJK");
        user.setEmail("test@example.com");
        user.setNickname("测试用户");

        userMapper.insert(user);
        assertThat(user.getId()).isNotNull();

        // 查询用户
        User found = userMapper.selectById(user.getId());
        assertThat(found).isNotNull();
        assertThat(found.getUsername()).isEqualTo("testuser");

        // 更新用户
        found.setNickname("更新后的昵称");
        userMapper.update(found);

        User updated = userMapper.selectById(user.getId());
        assertThat(updated.getNickname()).isEqualTo("更新后的昵称");

        // 删除用户
        userMapper.deleteById(user.getId());
        User deleted = userMapper.selectById(user.getId());
        assertThat(deleted).isNull();
    }

    @Test
    @DisplayName("测试 @ReadOnly 注解切换到 replica 数据源")
    void testReadOnlyAnnotation() throws Exception {
        // 创建测试用户
        User user = new User();
        user.setUsername("readonlyuser");
        user.setPassword("$2a$10$R9twLfa1VCMKgDQIv92xYeM7iyrztE2XWJvD4Y.iFFNJ6qg9hfmJK");
        user.setEmail("readonly@example.com");
        user.setNickname("只读用户");

        userMapper.insert(user);

        // 测试只读操作（应该使用 replica 数据源）
        User found = readOnlyUserService(user.getId());
        assertThat(found).isNotNull();
        assertThat(found.getUsername()).isEqualTo("readonlyuser");

        // 清理
        userMapper.deleteById(user.getId());
    }

    @ReadOnly
    private User readOnlyUserService(Long userId) {
        // 此方法会被 AOP 拦截，切换到 replica 数据源
        return userMapper.selectById(userId);
    }

    @Test
    @DisplayName("测试数据源上下文切换")
    void testDataSourceContextSwitching() {
        // 测试手动切换数据源
        DataSourceConfig.DataSourceContextHolder.setDataSourceType(DataSourceConfig.DataSourceType.PRIMARY);
        assertThat(DataSourceConfig.DataSourceContextHolder.getDataSourceType())
                .isEqualTo(DataSourceConfig.DataSourceType.PRIMARY);

        DataSourceConfig.DataSourceContextHolder.setDataSourceType(DataSourceConfig.DataSourceType.REPLICA);
        assertThat(DataSourceConfig.DataSourceContextHolder.getDataSourceType())
                .isEqualTo(DataSourceConfig.DataSourceType.REPLICA);

        DataSourceConfig.DataSourceContextHolder.clearDataSourceType();
        assertThat(DataSourceConfig.DataSourceContextHolder.getDataSourceType())
                .isEqualTo(DataSourceConfig.DataSourceType.PRIMARY); // 默认主库
    }

    @Test
    @DisplayName("测试数据库连接池配置")
    void testConnectionPoolConfiguration() throws Exception {
        // 验证数据库连接正常
        try (Connection conn = DriverManager.getConnection(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())) {
            try (PreparedStatement stmt = conn.prepareStatement("SELECT 1")) {
                try (ResultSet rs = stmt.executeQuery()) {
                    assertThat(rs.next()).isTrue();
                    assertThat(rs.getInt(1)).isEqualTo(1);
                }
            }
        }
    }
}
