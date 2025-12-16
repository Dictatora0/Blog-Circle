package com.cloudcom.blog.util;

import io.jsonwebtoken.Claims;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * JWT工具类测试
 * 
 * Given-When-Then 风格测试：
 * 1. 生成Token成功
 * 2. 解析Token成功
 * 3. 验证Token有效性
 * 4. 验证Token过期
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
@ActiveProfiles("test")
@DisplayName("JWT工具类测试")
class JwtUtilTest {

    @Autowired
    private JwtUtil jwtUtil;

    private Long testUserId;
    private String testUsername;

    @BeforeEach
    void setUp() {
        // Given: 准备测试数据
        testUserId = 1L;
        testUsername = "testuser";
    }

    @Test
    @DisplayName("场景1: 生成Token成功")
    void testGenerateToken() {
        // When: 生成Token
        String token = jwtUtil.generateToken(testUserId, testUsername);

        // Then: 验证Token不为空且格式正确
        assertThat(token).isNotNull();
        assertThat(token.split("\\.")).hasSize(3); // JWT由三部分组成
        
        // 验证Token可解析
        Claims claims = jwtUtil.getClaimsFromToken(token);
        assertThat(claims).isNotNull();
        assertThat(claims.getSubject()).isEqualTo(testUsername);
        assertThat(claims.get("userId", Long.class)).isEqualTo(testUserId);
    }

    @Test
    @DisplayName("场景2: 从Token中获取用户ID")
    void testGetUserIdFromToken() {
        // Given: 生成Token
        String token = jwtUtil.generateToken(testUserId, testUsername);

        // When: 从Token中获取用户ID
        Long userId = jwtUtil.getUserIdFromToken(token);

        // Then: 验证用户ID正确
        assertThat(userId).isEqualTo(testUserId);
    }

    @Test
    @DisplayName("场景3: 从Token中获取用户名")
    void testGetUsernameFromToken() {
        // Given: 生成Token
        String token = jwtUtil.generateToken(testUserId, testUsername);

        // When: 从Token中获取用户名
        String username = jwtUtil.getUsernameFromToken(token);

        // Then: 验证用户名正确
        assertThat(username).isEqualTo(testUsername);
    }

    @Test
    @DisplayName("场景4: 验证Token有效性")
    void testValidateToken() {
        // Given: 生成有效的Token
        String token = jwtUtil.generateToken(testUserId, testUsername);

        // When: 验证Token
        boolean isValid = jwtUtil.validateToken(token);

        // Then: 验证Token有效
        assertThat(isValid).isTrue();
    }

    @Test
    @DisplayName("场景5: 验证Token未过期")
    void testTokenNotExpired() {
        // Given: 生成Token
        String token = jwtUtil.generateToken(testUserId, testUsername);

        // When: 检查Token是否过期
        boolean isExpired = jwtUtil.isTokenExpired(token);

        // Then: 验证Token未过期
        assertThat(isExpired).isFalse();
    }

    @Test
    @DisplayName("场景6: 解析Token获取Claims")
    void testGetClaimsFromToken() {
        // Given: 生成Token
        String token = jwtUtil.generateToken(testUserId, testUsername);

        // When: 解析Token
        Claims claims = jwtUtil.getClaimsFromToken(token);

        // Then: 验证Claims内容
        assertThat(claims).isNotNull();
        assertThat(claims.getSubject()).isEqualTo(testUsername);
        assertThat(claims.get("userId", Long.class)).isEqualTo(testUserId);
        assertThat(claims.getIssuedAt()).isNotNull();
        assertThat(claims.getExpiration()).isNotNull();
    }
}

