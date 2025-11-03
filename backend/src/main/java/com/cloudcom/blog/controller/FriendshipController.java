package com.cloudcom.blog.controller;

import com.cloudcom.blog.common.Result;
import com.cloudcom.blog.entity.Friendship;
import com.cloudcom.blog.entity.User;
import com.cloudcom.blog.service.FriendshipService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 好友关系控制器
 */
@RestController
@RequestMapping("/api/friends")
@CrossOrigin
public class FriendshipController {

    @Autowired
    private FriendshipService friendshipService;

    /**
     * 发送好友请求
     */
    @PostMapping("/request/{receiverId}")
    public Result<?> sendFriendRequest(@PathVariable Long receiverId, HttpServletRequest request) {
        try {
            Long currentUserId = (Long) request.getAttribute("userId");
            Friendship friendship = friendshipService.sendFriendRequest(currentUserId, receiverId);
            return Result.success("好友请求已发送", friendship);
        } catch (IllegalArgumentException e) {
            return Result.error(e.getMessage());
        } catch (Exception e) {
            e.printStackTrace();
            return Result.error("发送好友请求失败");
        }
    }

    /**
     * 接受好友请求
     */
    @PostMapping("/accept/{requestId}")
    public Result<?> acceptFriendRequest(@PathVariable Long requestId, HttpServletRequest request) {
        try {
            Long currentUserId = (Long) request.getAttribute("userId");
            friendshipService.acceptFriendRequest(requestId, currentUserId);
            return Result.success("已接受好友请求", null);
        } catch (IllegalArgumentException e) {
            return Result.error(e.getMessage());
        } catch (Exception e) {
            e.printStackTrace();
            return Result.error("接受好友请求失败");
        }
    }

    /**
     * 拒绝好友请求
     */
    @PostMapping("/reject/{requestId}")
    public Result<?> rejectFriendRequest(@PathVariable Long requestId, HttpServletRequest request) {
        try {
            Long currentUserId = (Long) request.getAttribute("userId");
            friendshipService.rejectFriendRequest(requestId, currentUserId);
            return Result.success("已拒绝好友请求", null);
        } catch (IllegalArgumentException e) {
            return Result.error(e.getMessage());
        } catch (Exception e) {
            e.printStackTrace();
            return Result.error("拒绝好友请求失败");
        }
    }

    /**
     * 删除好友
     */
    @DeleteMapping("/{friendshipId}")
    public Result<?> deleteFriend(@PathVariable Long friendshipId, HttpServletRequest request) {
        try {
            Long currentUserId = (Long) request.getAttribute("userId");
            friendshipService.deleteFriend(friendshipId, currentUserId);
            return Result.success("已删除好友", null);
        } catch (IllegalArgumentException e) {
            return Result.error(e.getMessage());
        } catch (Exception e) {
            e.printStackTrace();
            return Result.error("删除好友失败");
        }
    }

    /**
     * 获取好友列表
     */
    @GetMapping("/list")
    public Result<?> getFriendList(HttpServletRequest request) {
        try {
            Long currentUserId = (Long) request.getAttribute("userId");
            List<User> friends = friendshipService.getFriendList(currentUserId);
            return Result.success(friends);
        } catch (Exception e) {
            e.printStackTrace();
            return Result.error("获取好友列表失败");
        }
    }

    /**
     * 获取待处理的好友请求
     */
    @GetMapping("/requests")
    public Result<?> getPendingRequests(HttpServletRequest request) {
        try {
            Long currentUserId = (Long) request.getAttribute("userId");
            List<Friendship> requests = friendshipService.getPendingRequests(currentUserId);
            return Result.success(requests);
        } catch (Exception e) {
            e.printStackTrace();
            return Result.error("获取好友请求失败");
        }
    }

    /**
     * 获取我发送的好友请求
     */
    @GetMapping("/sent-requests")
    public Result<?> getSentRequests(HttpServletRequest request) {
        try {
            Long currentUserId = (Long) request.getAttribute("userId");
            List<Friendship> requests = friendshipService.getSentRequests(currentUserId);
            return Result.success(requests);
        } catch (Exception e) {
            e.printStackTrace();
            return Result.error("获取发送的好友请求失败");
        }
    }

    /**
     * 搜索用户
     */
    @GetMapping("/search")
    public Result<?> searchUsers(@RequestParam String keyword, HttpServletRequest request) {
        try {
            Long currentUserId = (Long) request.getAttribute("userId");
            if (keyword == null || keyword.trim().isEmpty()) {
                return Result.error("搜索关键词不能为空");
            }
            List<User> users = friendshipService.searchUsers(keyword, currentUserId);
            return Result.success(users);
        } catch (Exception e) {
            e.printStackTrace();
            return Result.error("搜索用户失败");
        }
    }

    /**
     * 检查与某用户的好友关系状态
     */
    @GetMapping("/status/{userId}")
    public Result<?> getFriendshipStatus(@PathVariable Long userId, HttpServletRequest request) {
        try {
            Long currentUserId = (Long) request.getAttribute("userId");
            boolean isFriend = friendshipService.isFriend(currentUserId, userId);
            
            Map<String, Object> status = new HashMap<>();
            status.put("isFriend", isFriend);
            
            return Result.success(status);
        } catch (Exception e) {
            e.printStackTrace();
            return Result.error("获取好友关系失败");
        }
    }
}

