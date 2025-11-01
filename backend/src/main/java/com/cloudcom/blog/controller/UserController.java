package com.cloudcom.blog.controller;

import com.cloudcom.blog.common.Result;
import com.cloudcom.blog.entity.User;
import com.cloudcom.blog.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 用户控制器
 */
@RestController
@RequestMapping("/api/users")
public class UserController {

    @Autowired
    private UserService userService;

    /**
     * 获取当前用户信息
     */
    @GetMapping("/current")
    public Result<User> getCurrentUser(HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            User user = userService.getUserById(userId);
            if (user != null) {
                user.setPassword(null);
            }
            return Result.success(user);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 更新用户信息
     */
    @PutMapping("/{id}")
    public Result<Void> updateUser(@PathVariable Long id, 
                                    @RequestBody User user,
                                    HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            if (!userId.equals(id)) {
                return Result.error(403, "无权限修改其他用户信息");
            }
            user.setId(id);
            userService.updateUser(user);
            return Result.success("更新成功", null);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 获取所有用户
     */
    @GetMapping("/list")
    public Result<List<User>> getAllUsers() {
        try {
            List<User> users = userService.getAllUsers();
            users.forEach(user -> user.setPassword(null));
            return Result.success(users);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 删除用户
     */
    @DeleteMapping("/{id}")
    public Result<Void> deleteUser(@PathVariable Long id, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            if (!userId.equals(id)) {
                return Result.error(403, "无权限删除其他用户");
            }
            userService.deleteUser(id);
            return Result.success("删除成功", null);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }
}


