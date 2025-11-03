package com.cloudcom.blog.controller;

import com.cloudcom.blog.entity.User;
import com.cloudcom.blog.interceptor.JwtInterceptor;
import com.cloudcom.blog.service.UserService;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
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

import java.util.Arrays;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * 用户控制器测试类
 * 
 * Given-When-Then 风格测试：
 * 1. 获取当前用户信息成功
 * 2. 更新用户信息成功（包括头像和封面）
 * 3. 更新用户信息失败（无权限修改其他用户）
 * 4. 更新用户头像成功
 * 5. 更新用户封面成功
 * 6. 获取所有用户列表成功
 * 7. 删除用户成功
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("用户控制器测试")
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @MockBean
    private JwtInterceptor jwtInterceptor;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;

    @BeforeEach
    void setUp() throws Exception {
        // Given: 准备测试数据
        testUser = new User();
        testUser.setId(1L);
        testUser.setUsername("testuser");
        testUser.setEmail("test@example.com");
        testUser.setNickname("测试用户");
        testUser.setAvatar("http://localhost:8080/uploads/avatar1.jpg");
        testUser.setCoverImage("http://localhost:8080/uploads/cover1.jpg");

        // Mock拦截器行为：允许所有请求通过并设置userId
        when(jwtInterceptor.preHandle(any(HttpServletRequest.class), any(HttpServletResponse.class), any()))
                .thenAnswer(invocation -> {
                    HttpServletRequest request = invocation.getArgument(0);
                    request.setAttribute("userId", 1L);
                    return true;
                });
    }

    @Test
    @DisplayName("场景1: 获取当前用户信息成功")
    void testGetCurrentUser() throws Exception {
        // Given: 模拟用户服务返回用户信息
        when(userService.getUserById(1L)).thenReturn(testUser);

        // When: 发送获取当前用户信息请求
        // Then: 验证响应
        mockMvc.perform(get("/api/users/current"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.id").value(1))
                .andExpect(jsonPath("$.data.username").value("testuser"))
                .andExpect(jsonPath("$.data.nickname").value("测试用户"))
                .andExpect(jsonPath("$.data.password").doesNotExist()); // 密码不应返回

        verify(userService).getUserById(1L);
    }

    @Test
    @DisplayName("场景2: 更新用户信息成功")
    void testUpdateUserSuccess() throws Exception {
        // Given: 模拟用户服务更新成功
        when(userService.getUserById(1L)).thenReturn(testUser);
        doNothing().when(userService).updateUser(any(User.class));

        // When: 发送更新用户信息请求
        User updateData = new User();
        updateData.setNickname("更新后的昵称");
        updateData.setEmail("updated@example.com");

        // Then: 验证响应
        mockMvc.perform(put("/api/users/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updateData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("更新成功"));

        verify(userService).getUserById(1L);
        verify(userService).updateUser(any(User.class));
    }

    @Test
    @DisplayName("场景3: 更新用户信息失败 - 无权限修改其他用户")
    void testUpdateUserFailed_Unauthorized() throws Exception {
        // Given: 当前用户ID为1，尝试修改用户ID为2的信息
        when(jwtInterceptor.preHandle(any(HttpServletRequest.class), any(HttpServletResponse.class), any()))
                .thenAnswer(invocation -> {
                    HttpServletRequest request = invocation.getArgument(0);
                    request.setAttribute("userId", 1L); // 当前登录用户ID为1
                    return true;
                });

        // When: 发送更新其他用户信息的请求
        User updateData = new User();
        updateData.setNickname("更新后的昵称");

        // Then: 验证响应为403错误
        mockMvc.perform(put("/api/users/2") // 尝试修改用户ID为2的信息
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updateData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(403))
                .andExpect(jsonPath("$.message").value("无权限修改其他用户信息"));

        verify(userService, never()).updateUser(any(User.class));
    }

    @Test
    @DisplayName("场景4: 更新用户头像成功")
    void testUpdateUserAvatar() throws Exception {
        // Given: 模拟用户服务更新成功
        when(userService.getUserById(1L)).thenReturn(testUser);
        doNothing().when(userService).updateUser(any(User.class));

        // When: 发送更新头像请求
        User updateData = new User();
        updateData.setAvatar("http://localhost:8080/uploads/new-avatar.jpg");

        // Then: 验证响应
        mockMvc.perform(put("/api/users/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updateData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("更新成功"));

        // 验证传递给service的用户对象包含正确的头像URL
        verify(userService).getUserById(1L);
        verify(userService).updateUser(argThat(user -> 
            user.getId().equals(1L) && 
            "http://localhost:8080/uploads/new-avatar.jpg".equals(user.getAvatar())
        ));
    }

    @Test
    @DisplayName("场景5: 更新用户封面成功")
    void testUpdateUserCoverImage() throws Exception {
        // Given: 模拟用户服务更新成功
        when(userService.getUserById(1L)).thenReturn(testUser);
        doNothing().when(userService).updateUser(any(User.class));

        // When: 发送更新封面请求
        User updateData = new User();
        updateData.setCoverImage("http://localhost:8080/uploads/new-cover.jpg");

        // Then: 验证响应
        mockMvc.perform(put("/api/users/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updateData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("更新成功"));

        // 验证传递给service的用户对象包含正确的封面URL
        verify(userService).getUserById(1L);
        verify(userService).updateUser(argThat(user -> 
            user.getId().equals(1L) && 
            "http://localhost:8080/uploads/new-cover.jpg".equals(user.getCoverImage())
        ));
    }

    @Test
    @DisplayName("场景6: 同时更新头像和封面成功")
    void testUpdateUserAvatarAndCover() throws Exception {
        // Given: 模拟用户服务更新成功
        when(userService.getUserById(1L)).thenReturn(testUser);
        doNothing().when(userService).updateUser(any(User.class));

        // When: 发送同时更新头像和封面的请求
        User updateData = new User();
        updateData.setAvatar("http://localhost:8080/uploads/new-avatar.jpg");
        updateData.setCoverImage("http://localhost:8080/uploads/new-cover.jpg");

        // Then: 验证响应
        mockMvc.perform(put("/api/users/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updateData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("更新成功"));

        // 验证传递给service的用户对象包含正确的头像和封面URL
        verify(userService).getUserById(1L);
        verify(userService).updateUser(argThat(user -> 
            user.getId().equals(1L) && 
            "http://localhost:8080/uploads/new-avatar.jpg".equals(user.getAvatar()) &&
            "http://localhost:8080/uploads/new-cover.jpg".equals(user.getCoverImage())
        ));
    }

    @Test
    @DisplayName("场景7: 获取所有用户列表成功")
    void testGetAllUsers() throws Exception {
        // Given: 模拟用户服务返回用户列表
        User user1 = new User();
        user1.setId(1L);
        user1.setUsername("user1");
        user1.setNickname("用户1");

        User user2 = new User();
        user2.setId(2L);
        user2.setUsername("user2");
        user2.setNickname("用户2");

        List<User> users = Arrays.asList(user1, user2);
        when(userService.getAllUsers()).thenReturn(users);

        // When: 发送获取所有用户列表请求
        // Then: 验证响应
        mockMvc.perform(get("/api/users/list"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data").isArray())
                .andExpect(jsonPath("$.data.length()").value(2))
                .andExpect(jsonPath("$.data[0].password").doesNotExist()) // 密码不应返回
                .andExpect(jsonPath("$.data[1].password").doesNotExist());

        verify(userService).getAllUsers();
    }

    @Test
    @DisplayName("场景8: 删除用户成功")
    void testDeleteUserSuccess() throws Exception {
        // Given: 模拟用户服务删除成功
        doNothing().when(userService).deleteUser(1L);

        // When: 发送删除用户请求
        // Then: 验证响应
        mockMvc.perform(delete("/api/users/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("删除成功"));

        verify(userService).deleteUser(1L);
    }

    @Test
    @DisplayName("场景9: 删除用户失败 - 无权限删除其他用户")
    void testDeleteUserFailed_Unauthorized() throws Exception {
        // Given: 当前用户ID为1，尝试删除用户ID为2
        when(jwtInterceptor.preHandle(any(HttpServletRequest.class), any(HttpServletResponse.class), any()))
                .thenAnswer(invocation -> {
                    HttpServletRequest request = invocation.getArgument(0);
                    request.setAttribute("userId", 1L); // 当前登录用户ID为1
                    return true;
                });

        // When: 发送删除其他用户的请求
        // Then: 验证响应为403错误
        mockMvc.perform(delete("/api/users/2")) // 尝试删除用户ID为2
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(403))
                .andExpect(jsonPath("$.message").value("无权限删除其他用户"));

        verify(userService, never()).deleteUser(anyLong());
    }
}

