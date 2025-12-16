package com.cloudcom.blog.controller;

import com.cloudcom.blog.entity.User;
import com.cloudcom.blog.interceptor.JwtInterceptor;
import com.cloudcom.blog.service.UserService;
import com.cloudcom.blog.util.JwtUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.HashMap;
import java.util.Map;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * 认证控制器测试类
 * 
 * 测试场景：
 * 1. 用户注册成功
 * 2. 用户注册失败（用户名已存在）
 * 3. 用户登录成功
 * 4. 用户登录失败（用户名或密码错误）
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("认证控制器测试")
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @MockBean
    private JwtUtil jwtUtil;

    @MockBean
    private JwtInterceptor jwtInterceptor;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;

    @BeforeEach
    void setUp() {
        // Given: 准备测试数据
        testUser = new User();
        testUser.setId(1L);
        testUser.setUsername("testuser");
        testUser.setPassword("$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH");
        testUser.setEmail("test@example.com");
        testUser.setNickname("测试用户");
    }

    @Test
    @DisplayName("场景1: 用户注册成功")
    void testRegisterSuccess() throws Exception {
        // Given: 模拟用户服务返回新创建的用户
        User newUser = new User();
        newUser.setId(1L);
        newUser.setUsername("newuser");
        newUser.setEmail("newuser@example.com");
        newUser.setNickname("新用户");

        when(userService.register(any(User.class))).thenReturn(newUser);

        // When: 发送注册请求
        User registerData = new User();
        registerData.setUsername("newuser");
        registerData.setPassword("password123");
        registerData.setEmail("newuser@example.com");
        registerData.setNickname("新用户");

        // Then: 验证响应
        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(registerData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("注册成功"))
                .andExpect(jsonPath("$.data.username").value("newuser"))
                .andExpect(jsonPath("$.data.password").doesNotExist());
    }

    @Test
    @DisplayName("场景2: 用户注册失败 - 用户名已存在")
    void testRegisterFailed_UsernameExists() throws Exception {
        // Given: 模拟用户服务抛出异常
        when(userService.register(any(User.class)))
                .thenThrow(new RuntimeException("用户名已存在"));

        // When: 发送注册请求
        User registerData = new User();
        registerData.setUsername("testuser");
        registerData.setPassword("password123");
        registerData.setEmail("test@example.com");

        // Then: 验证响应为错误
        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(registerData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(500))
                .andExpect(jsonPath("$.message").value("用户名已存在"));
    }

    @Test
    @DisplayName("场景3: 用户登录成功")
    void testLoginSuccess() throws Exception {
        // Given: 模拟用户服务和JWT工具
        when(userService.login("testuser", "password123")).thenReturn(testUser);
        when(jwtUtil.generateToken(1L, "testuser")).thenReturn("mock-jwt-token");

        // When: 发送登录请求
        Map<String, String> loginData = new HashMap<>();
        loginData.put("username", "testuser");
        loginData.put("password", "password123");

        // Then: 验证响应
        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("登录成功"))
                .andExpect(jsonPath("$.data.token").value("mock-jwt-token"))
                .andExpect(jsonPath("$.data.user.username").value("testuser"))
                .andExpect(jsonPath("$.data.user.password").doesNotExist());
    }

    @Test
    @DisplayName("场景4: 用户登录失败 - 用户名或密码错误")
    void testLoginFailed_InvalidCredentials() throws Exception {
        // Given: 模拟用户服务抛出异常
        when(userService.login("testuser", "wrongpassword"))
                .thenThrow(new RuntimeException("用户名或密码错误"));

        // When: 发送登录请求
        Map<String, String> loginData = new HashMap<>();
        loginData.put("username", "testuser");
        loginData.put("password", "wrongpassword");

        // Then: 验证响应为错误
        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(500))
                .andExpect(jsonPath("$.message").value("用户名或密码错误"));
    }
}
