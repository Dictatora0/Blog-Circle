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
            if (userId == null) {
                return Result.error(401, "未登录或登录已过期");
            }
            User user = userService.getUserById(userId);
            if (user == null) {
                return Result.error(404, "用户不存在");
            }
            // 清除敏感信息
            user.setPassword(null);
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
            if (userId == null) {
                return Result.error(401, "未登录或登录已过期");
            }
            if (!userId.equals(id)) {
                return Result.error(403, "无权限修改其他用户信息");
            }
            
            // 验证用户是否存在
            User existingUser = userService.getUserById(id);
            if (existingUser == null) {
                return Result.error(404, "用户不存在");
            }
            
            // 创建安全的更新对象，只允许更新特定字段
            User updateData = new User();
            updateData.setId(id);
            
            // 只允许更新这些字段，防止更新敏感字段（username, password）
            if (user.getEmail() != null) {
                // 简单的邮箱格式验证
                if (!user.getEmail().matches("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")) {
                    return Result.error("邮箱格式不正确");
                }
                updateData.setEmail(user.getEmail());
            }
            
            if (user.getNickname() != null) {
                // 验证昵称长度（1-50字符）
                String nickname = user.getNickname().trim();
                if (nickname.isEmpty() || nickname.length() > 50) {
                    return Result.error("昵称长度必须在1-50个字符之间");
                }
                updateData.setNickname(nickname);
            }
            
            if (user.getAvatar() != null) {
                // 验证URL格式（允许相对路径和绝对URL）
                String avatar = user.getAvatar().trim();
                if (!avatar.isEmpty()) {
                    // 允许：http://..., https://..., /uploads/...
                    if (!avatar.matches("^(https?://.+|/.+)$")) {
                        return Result.error("头像URL格式不正确，必须是http://、https://开头的完整URL或以/开头的相对路径");
                    }
                    // 限制URL长度（防止过长的恶意URL）
                    if (avatar.length() > 500) {
                        return Result.error("头像URL长度不能超过500个字符");
                    }
                }
                updateData.setAvatar(avatar.isEmpty() ? null : avatar);
            }
            
            if (user.getCoverImage() != null) {
                // 验证URL格式（允许相对路径和绝对URL）
                String coverImage = user.getCoverImage().trim();
                if (!coverImage.isEmpty()) {
                    // 允许：http://..., https://..., /uploads/...
                    if (!coverImage.matches("^(https?://.+|/.+)$")) {
                        return Result.error("封面URL格式不正确，必须是http://、https://开头的完整URL或以/开头的相对路径");
                    }
                    // 限制URL长度（防止过长的恶意URL）
                    if (coverImage.length() > 500) {
                        return Result.error("封面URL长度不能超过500个字符");
                    }
                }
                updateData.setCoverImage(coverImage.isEmpty() ? null : coverImage);
            }
            
            // 执行更新
            userService.updateUser(updateData);
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


