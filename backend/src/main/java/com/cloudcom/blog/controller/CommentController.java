package com.cloudcom.blog.controller;

import com.cloudcom.blog.common.Result;
import com.cloudcom.blog.entity.Comment;
import com.cloudcom.blog.service.CommentService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 评论控制器
 */
@RestController
@RequestMapping("/api/comments")
public class CommentController {

    @Autowired
    private CommentService commentService;

    /**
     * 创建评论
     */
    @PostMapping
    public Result<Comment> createComment(@RequestBody Comment comment, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            comment.setUserId(userId);
            Comment newComment = commentService.createComment(comment);
            return Result.success("评论成功", newComment);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 更新评论
     */
    @PutMapping("/{id}")
    public Result<Void> updateComment(@PathVariable Long id, 
                                       @RequestBody Comment comment,
                                       HttpServletRequest request) {
        try {
            comment.setId(id);
            commentService.updateComment(comment);
            return Result.success("更新成功", null);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 删除评论
     */
    @DeleteMapping("/{id}")
    public Result<Void> deleteComment(@PathVariable Long id) {
        try {
            commentService.deleteComment(id);
            return Result.success("删除成功", null);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 根据文章ID获取评论列表
     */
    @GetMapping("/post/{postId}")
    public Result<List<Comment>> getCommentsByPostId(@PathVariable Long postId) {
        try {
            List<Comment> comments = commentService.getCommentsByPostId(postId);
            return Result.success(comments);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 获取我的评论
     */
    @GetMapping("/my")
    public Result<List<Comment>> getMyComments(HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            List<Comment> comments = commentService.getCommentsByUserId(userId);
            return Result.success(comments);
        } catch (Exception e) {
            return Result.error(e.getMessage());
        }
    }
}


