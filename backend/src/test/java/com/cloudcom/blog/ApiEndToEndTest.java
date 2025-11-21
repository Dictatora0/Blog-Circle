package com.cloudcom.blog;

import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.*;

/**
 * API 端到端测试
 * 启动完整应用，测试 API 接口
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@DisplayName("API 端到端测试")
class ApiEndToEndTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:13")
            .withDatabaseName("blog_test")
            .withUsername("bloguser")
            .withPassword("747599qw@");

    @LocalServerPort
    private int port;

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        // 覆盖默认数据源配置
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.datasource.driver-class-name", () -> "org.postgresql.Driver");
    }

    @BeforeAll
    static void initDatabase() throws Exception {
        // 初始化数据库表结构
        try (Connection conn = DriverManager.getConnection(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
             Statement stmt = conn.createStatement()) {
            // 创建 users 表
            stmt.execute("""
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
                """);
            
            // 创建 posts 表
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS posts (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(200) NOT NULL,
                    content TEXT NOT NULL,
                    author_id BIGINT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """);
            
            // 创建 comments 表
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS comments (
                    id SERIAL PRIMARY KEY,
                    post_id BIGINT NOT NULL,
                    user_id BIGINT NOT NULL,
                    content TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """);
            
            // 创建 likes 表
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS likes (
                    id SERIAL PRIMARY KEY,
                    post_id BIGINT NOT NULL,
                    user_id BIGINT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(post_id, user_id)
                );
                """);
            
            // 创建 access_logs 表
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS access_logs (
                    id SERIAL PRIMARY KEY,
                    user_id BIGINT,
                    post_id BIGINT,
                    action VARCHAR(50),
                    ip_address VARCHAR(50),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """);
            
            // 创建 statistics 表
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS statistics (
                    id SERIAL PRIMARY KEY,
                    stat_type VARCHAR(50) NOT NULL,
                    stat_key VARCHAR(100) NOT NULL,
                    stat_value BIGINT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """);
            
            // 插入 admin 测试用户（密码：admin123，使用 BCrypt 加密）
            stmt.execute("""
                INSERT INTO users (username, password, email, nickname) 
                VALUES ('admin', '$2a$10$R9twLfa1VCMKgDQIv92xYeM7iyrztE2XWJvD4Y.iFFNJ6qg9hfmJK', 'admin@test.com', '管理员')
                ON CONFLICT (username) DO NOTHING;
                """);
        }
    }

    @BeforeEach
    void setUp() {
        RestAssured.baseURI = "http://localhost";
        RestAssured.port = port;
        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();
    }

    @Test
    @DisplayName("测试用户注册和登录流程")
    void testUserRegistrationAndLogin() {
        // 注册新用户
        Map<String, String> registerRequest = new HashMap<>();
        registerRequest.put("username", "e2euser");
        registerRequest.put("password", "password123");
        registerRequest.put("email", "e2e@example.com");
        registerRequest.put("nickname", "E2E用户");

        // 注册返回的是 User 对象，不包含 token
        given()
                .contentType(ContentType.JSON)
                .body(registerRequest)
                .when()
                .post("/api/auth/register")
                .then()
                .statusCode(200)
                .body("code", equalTo(200))
                .body("message", equalTo("注册成功"))
                .body("data.username", equalTo("e2euser"));


        // 使用注册的账号登录
        Map<String, String> loginRequest = new HashMap<>();
        loginRequest.put("username", "e2euser");
        loginRequest.put("password", "password123");

        String loginToken = given()
                .contentType(ContentType.JSON)
                .body(loginRequest)
                .when()
                .post("/api/auth/login")
                .then()
                .statusCode(200)
                .body("code", equalTo(200))
                .body("message", equalTo("登录成功"))
                .body("data.token", notNullValue())
                .body("data.user.username", equalTo("e2euser"))
                .extract()
                .path("data.token");

        assertThat(loginToken).isNotNull();
    }

    @Test
    @DisplayName("测试文章 CRUD 操作")
    void testPostCrudOperations() {
        // 先注册用户
        Map<String, String> registerRequest = new HashMap<>();
        registerRequest.put("username", "postuser");
        registerRequest.put("password", "password123");
        registerRequest.put("email", "post@example.com");
        registerRequest.put("nickname", "文章用户");

        // 注册后再登录获取 token
        given()
                .contentType(ContentType.JSON)
                .body(registerRequest)
                .when()
                .post("/api/auth/register")
                .then()
                .statusCode(200);

        Map<String, String> loginRequest = new HashMap<>();
        loginRequest.put("username", "postuser");
        loginRequest.put("password", "password123");

        String token = given()
                .contentType(ContentType.JSON)
                .body(loginRequest)
                .when()
                .post("/api/auth/login")
                .then()
                .statusCode(200)
                .extract()
                .path("data.token");

        assertThat(token).isNotNull();

        // 获取文章列表（验证接口可访问）
        given()
                .when()
                .get("/api/posts/list")
                .then()
                .statusCode(200)
                .body("code", equalTo(200));
    }

    @Test
    @DisplayName("测试健康检查")
    void testHealthCheck() {
        given()
                .when()
                .get("/actuator/health")
                .then()
                .statusCode(200)
                .body("status", equalTo("UP"));
    }

    @Test
    @DisplayName("测试未授权访问保护")
    void testUnauthorizedAccess() {
        // 尝试创建文章但没有 token
        Map<String, Object> postRequest = new HashMap<>();
        postRequest.put("title", "未授权测试");
        postRequest.put("content", "应该失败");

        given()
                .contentType(ContentType.JSON)
                .body(postRequest)
                .when()
                .post("/api/posts")
                .then()
                .statusCode(401);
    }
}
