package com.cloudcom.blog.controller;

import com.cloudcom.blog.common.Result;
import com.cloudcom.blog.entity.User;
import com.cloudcom.blog.service.UserService;
import com.cloudcom.blog.util.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * 认证控制器
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @Autowired
    private UserService userService;

    @Autowired
    private JwtUtil jwtUtil;

    /**
     * 用户注册
     */
    @PostMapping("/register")
    public Result<User> register(@RequestBody User user) {
        try {
            User newUser = userService.register(user);
            // 清除密码信息
            newUser.setPassword(null);
            return Result.success("注册成功", newUser);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 用户登录
     */
    @PostMapping("/login")
    public Result<Map<String, Object>> login(@RequestBody Map<String, String> loginData) {
        try {
            String username = loginData.get("username");
            String password = loginData.get("password");
            
            User user = userService.login(username, password);
            
            // 生成Token
            String token = jwtUtil.generateToken(user.getId(), user.getUsername());
            
            // 清除密码信息
            user.setPassword(null);
            
            Map<String, Object> result = new HashMap<>();
            result.put("token", token);
            result.put("user", user);
            
            return Result.success("登录成功", result);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }
}


