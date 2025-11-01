package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.User;
import com.cloudcom.blog.mapper.UserMapper;
import com.cloudcom.blog.util.PasswordUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * 用户服务测试类
 * 
 * Given-When-Then 风格测试：
 * 1. 用户注册成功
 * 2. 用户注册失败（用户名已存在）
 * 3. 用户登录成功
 * 4. 用户登录失败（用户名不存在）
 * 5. 用户登录失败（密码错误）
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("用户服务测试")
class UserServiceTest {

    @Mock
    private UserMapper userMapper;

    @InjectMocks
    private UserService userService;

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
    void testRegisterSuccess() {
        // Given: 用户名不存在
        when(userMapper.selectByUsername("newuser")).thenReturn(null);
        when(userMapper.insert(any(User.class))).thenAnswer(invocation -> {
            User user = invocation.getArgument(0);
            user.setId(1L);
            return null;
        });

        // When: 执行注册
        User newUser = new User();
        newUser.setUsername("newuser");
        newUser.setPassword("password123");
        newUser.setEmail("newuser@example.com");
        newUser.setNickname("新用户");

        User result = userService.register(newUser);

        // Then: 验证结果
        assertThat(result).isNotNull();
        assertThat(result.getId()).isNotNull();
        assertThat(result.getPassword()).isNotEqualTo("password123"); // 密码已加密
        assertThat(result.getPassword()).startsWith("$2a$"); // BCrypt格式
        
        verify(userMapper).selectByUsername("newuser");
        verify(userMapper).insert(any(User.class));
    }

    @Test
    @DisplayName("场景2: 用户注册失败 - 用户名已存在")
    void testRegisterFailed_UsernameExists() {
        // Given: 用户名已存在
        when(userMapper.selectByUsername("testuser")).thenReturn(testUser);

        // When & Then: 执行注册应该抛出异常
        User newUser = new User();
        newUser.setUsername("testuser");
        newUser.setPassword("password123");

        assertThatThrownBy(() -> userService.register(newUser))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("用户名已存在");

        verify(userMapper).selectByUsername("testuser");
        verify(userMapper, never()).insert(any(User.class));
    }

    @Test
    @DisplayName("场景3: 用户登录成功")
    void testLoginSuccess() {
        // Given: 用户名和密码正确
        // 使用正确的BCrypt哈希（password123对应的哈希）
        User userWithCorrectPassword = new User();
        userWithCorrectPassword.setId(1L);
        userWithCorrectPassword.setUsername("testuser");
        // 使用 PasswordUtil 生成正确的哈希
        String correctPassword = "password123";
        userWithCorrectPassword.setPassword(PasswordUtil.encode(correctPassword));
        userWithCorrectPassword.setEmail("test@example.com");
        userWithCorrectPassword.setNickname("测试用户");
        
        when(userMapper.selectByUsername("testuser")).thenReturn(userWithCorrectPassword);

        // When: 执行登录
        User result = userService.login("testuser", correctPassword);

        // Then: 验证结果
        assertThat(result).isNotNull();
        assertThat(result.getUsername()).isEqualTo("testuser");
        
        verify(userMapper).selectByUsername("testuser");
    }

    @Test
    @DisplayName("场景4: 用户登录失败 - 用户名不存在")
    void testLoginFailed_UsernameNotFound() {
        // Given: 用户名不存在
        when(userMapper.selectByUsername("nonexistent")).thenReturn(null);

        // When & Then: 执行登录应该抛出异常
        assertThatThrownBy(() -> userService.login("nonexistent", "password123"))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("用户名或密码错误");

        verify(userMapper).selectByUsername("nonexistent");
    }

    @Test
    @DisplayName("场景5: 用户登录失败 - 密码错误")
    void testLoginFailed_WrongPassword() {
        // Given: 用户名存在但密码错误
        when(userMapper.selectByUsername("testuser")).thenReturn(testUser);

        // When & Then: 执行登录应该抛出异常
        assertThatThrownBy(() -> userService.login("testuser", "wrongpassword"))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("用户名或密码错误");

        verify(userMapper).selectByUsername("testuser");
    }

    @Test
    @DisplayName("场景6: 根据ID获取用户")
    void testGetUserById() {
        // Given: 用户ID存在
        when(userMapper.selectById(1L)).thenReturn(testUser);

        // When: 执行查询
        User result = userService.getUserById(1L);

        // Then: 验证结果
        assertThat(result).isNotNull();
        assertThat(result.getId()).isEqualTo(1L);
        assertThat(result.getUsername()).isEqualTo("testuser");
        
        verify(userMapper).selectById(1L);
    }

    @Test
    @DisplayName("场景7: 更新用户信息")
    void testUpdateUser() {
        // Given: 准备更新的用户数据
        User updatedUser = new User();
        updatedUser.setId(1L);
        updatedUser.setNickname("更新后的昵称");
        
        // update 方法返回 int，不是 void
        when(userMapper.update(any(User.class))).thenReturn(1);

        // When: 执行更新
        userService.updateUser(updatedUser);

        // Then: 验证mapper被调用
        verify(userMapper).update(updatedUser);
    }
}

