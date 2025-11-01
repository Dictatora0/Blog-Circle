package com.cloudcom.blog.controller;

import com.cloudcom.blog.common.Result;
import com.cloudcom.blog.entity.Post;
import com.cloudcom.blog.service.PostService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 文章控制器
 */
@RestController
@RequestMapping("/api/posts")
public class PostController {

    @Autowired
    private PostService postService;

    /**
     * 创建文章
     */
    @PostMapping
    public Result<Post> createPost(@RequestBody Post post, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            post.setAuthorId(userId);
            Post newPost = postService.createPost(post);
            return Result.success("发布成功", newPost);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 更新文章
     */
    @PutMapping("/{id}")
    public Result<Void> updatePost(@PathVariable Long id, 
                                    @RequestBody Post post,
                                    HttpServletRequest request) {
        try {
            post.setId(id);
            postService.updatePost(post);
            return Result.success("更新成功", null);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 删除文章
     */
    @DeleteMapping("/{id}")
    public Result<Void> deletePost(@PathVariable Long id) {
        try {
            postService.deletePost(id);
            return Result.success("删除成功", null);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 获取文章详情
     */
    @GetMapping("/{id}/detail")
    public Result<Post> getPostDetail(@PathVariable Long id, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            if (userId == null) {
                userId = 0L; // 未登录用户
            }
            Post post = postService.getPostById(id, userId);
            return Result.success(post);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 获取所有文章
     */
    @GetMapping("/list")
    public Result<List<Post>> getAllPosts(HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            List<Post> posts = postService.getAllPosts(userId);
            return Result.success(posts);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 获取我的文章
     */
    @GetMapping("/my")
    public Result<List<Post>> getMyPosts(HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            List<Post> posts = postService.getPostsByAuthorId(userId, userId);
            return Result.success(posts);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }
}


