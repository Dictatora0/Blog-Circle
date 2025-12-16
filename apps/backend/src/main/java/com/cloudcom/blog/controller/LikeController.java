package com.cloudcom.blog.controller;

import com.cloudcom.blog.common.Result;
import com.cloudcom.blog.service.LikeService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * 点赞控制器
 */
@RestController
@RequestMapping("/api/likes")
public class LikeController {

    @Autowired
    private LikeService likeService;

    /**
     * 点赞
     */
    @PostMapping("/{postId}")
    public Result<Map<String, Object>> like(@PathVariable Long postId, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            
            // 检查是否已点赞
            if (likeService.isLiked(postId, userId)) {
                return Result.error("已经点赞过了");
            }
            
            likeService.like(postId, userId);
            int likeCount = likeService.getLikeCount(postId);
            
            Map<String, Object> result = new HashMap<>();
            result.put("liked", true);
            result.put("likeCount", likeCount);
            
            return Result.success("点赞成功", result);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }
    
    /**
     * 取消点赞
     */
    @DeleteMapping("/{postId}")
    public Result<Map<String, Object>> unlike(@PathVariable Long postId, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            
            // 检查是否已点赞
            if (!likeService.isLiked(postId, userId)) {
                return Result.error("还未点赞");
            }
            
            likeService.unlike(postId, userId);
            int likeCount = likeService.getLikeCount(postId);
            
            Map<String, Object> result = new HashMap<>();
            result.put("liked", false);
            result.put("likeCount", likeCount);
            
            return Result.success("取消点赞成功", result);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 检查是否已点赞
     */
    @GetMapping("/{postId}/check")
    public Result<Boolean> checkLike(@PathVariable Long postId, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            boolean liked = likeService.isLiked(postId, userId);
            return Result.success(liked);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 获取点赞数
     */
    @GetMapping("/{postId}/count")
    public Result<Integer> getLikeCount(@PathVariable Long postId) {
        try {
            int count = likeService.getLikeCount(postId);
            return Result.success(count);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }
}

