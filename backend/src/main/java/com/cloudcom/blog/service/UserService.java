package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.User;
import com.cloudcom.blog.mapper.UserMapper;
import com.cloudcom.blog.util.InputSanitizer;
import com.cloudcom.blog.util.PasswordUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * 用户服务类
 */
@Service
public class UserService {

    @Autowired
    private UserMapper userMapper;

    /**
     * 用户注册
     */
    public User register(User user) {
        // 验证用户名
        if (InputSanitizer.isBlankOrEmpty(user.getUsername())) {
            throw new RuntimeException("用户名不能为空");
        }
        if (!InputSanitizer.isValidUsername(user.getUsername())) {
            throw new RuntimeException("用户名格式不正确（3-20个字符，只能包含字母、数字和下划线）");
        }
        
        // 验证密码
        if (InputSanitizer.isBlankOrEmpty(user.getPassword())) {
            throw new RuntimeException("密码不能为空");
        }
        
        // 检查用户名是否已存在（优先检查，避免不必要的验证）
        User existUser = userMapper.selectByUsername(user.getUsername());
        if (existUser != null) {
            throw new RuntimeException("用户名已存在");
        }
        
        // 验证邮箱
        if (InputSanitizer.isBlankOrEmpty(user.getEmail())) {
            throw new RuntimeException("邮箱不能为空");
        }
        if (!InputSanitizer.isValidEmail(user.getEmail())) {
            throw new RuntimeException("邮箱格式不正确");
        }
        
        // 清理昵称中的 XSS
        if (!InputSanitizer.isBlankOrEmpty(user.getNickname())) {
            user.setNickname(InputSanitizer.sanitizeXSS(user.getNickname()));
        }
        
        // 加密密码
        user.setPassword(PasswordUtil.encode(user.getPassword()));
        
        userMapper.insert(user);
        return user;
    }

    /**
     * 用户登录
     */
    public User login(String username, String password) {
        User user = userMapper.selectByUsername(username);
        if (user == null) {
            throw new RuntimeException("用户名或密码错误");
        }
        
        if (!PasswordUtil.matches(password, user.getPassword())) {
            throw new RuntimeException("用户名或密码错误");
        }
        
        return user;
    }

    /**
     * 根据ID获取用户
     */
    public User getUserById(Long id) {
        return userMapper.selectById(id);
    }

    /**
     * 更新用户信息
     */
    public void updateUser(User user) {
        // 验证用户是否存在
        if (user.getId() == null) {
            throw new RuntimeException("用户ID不能为空");
        }
        User existingUser = userMapper.selectById(user.getId());
        if (existingUser == null) {
            throw new RuntimeException("用户不存在");
        }
        
        // 执行更新
        userMapper.update(user);
    }

    /**
     * 删除用户
     */
    public void deleteUser(Long id) {
        userMapper.deleteById(id);
    }

    /**
     * 获取所有用户
     */
    public List<User> getAllUsers() {
        return userMapper.selectAll();
    }
}

