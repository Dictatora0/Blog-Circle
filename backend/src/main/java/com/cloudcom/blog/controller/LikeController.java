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
     * 点赞或取消点赞
     */
    @PostMapping("/{postId}")
    public Result<Map<String, Object>> toggleLike(@PathVariable Long postId, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            boolean liked = likeService.toggleLike(postId, userId);
            int likeCount = likeService.getLikeCount(postId);
            
            Map<String, Object> result = new HashMap<>();
            result.put("liked", liked);
            result.put("likeCount", likeCount);
            
            return Result.success(liked ? "点赞成功" : "取消点赞成功", result);
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

