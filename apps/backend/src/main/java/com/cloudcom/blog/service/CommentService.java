package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.AccessLog;
import com.cloudcom.blog.entity.Comment;
import com.cloudcom.blog.mapper.AccessLogMapper;
import com.cloudcom.blog.mapper.CommentMapper;
import com.cloudcom.blog.util.InputSanitizer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 评论服务类
 */
@Service
public class CommentService {

    @Autowired
    private CommentMapper commentMapper;

    @Autowired
    private AccessLogMapper accessLogMapper;

    /**
     * 创建评论
     */
    @Transactional
    public Comment createComment(Comment comment) {
        // 验证评论内容不为空
        if (comment.getContent() == null || comment.getContent().trim().isEmpty()) {
            throw new RuntimeException("评论内容不能为空");
        }
        
        // 验证内容长度
        if (!InputSanitizer.isValidLength(comment.getContent(), 5000)) {
            throw new RuntimeException("评论内容过长（最多5000字符）");
        }
        
        // 清理 XSS 攻击
        String sanitizedContent = InputSanitizer.sanitizeXSS(comment.getContent());
        comment.setContent(sanitizedContent);
        
        commentMapper.insert(comment);
        
        // 记录访问日志
        AccessLog log = new AccessLog();
        log.setUserId(comment.getUserId());
        log.setPostId(comment.getPostId());
        log.setAction("ADD_COMMENT");
        accessLogMapper.insert(log);
        
        return comment;
    }

    /**
     * 更新评论
     */
    public void updateComment(Comment comment) {
        commentMapper.update(comment);
    }

    /**
     * 删除评论（带权限验证）
     */
    public void deleteComment(Long id, Long userId) {
        // 查询评论是否存在
        Comment comment = commentMapper.selectById(id);
        if (comment == null) {
            throw new RuntimeException("评论不存在");
        }
        
        // 验证是否是评论作者本人
        if (comment.getUserId() == null || !comment.getUserId().equals(userId)) {
            throw new RuntimeException("无权删除他人的评论");
        }
        
        commentMapper.deleteById(id);
    }

    /**
     * 根据ID获取评论
     */
    public Comment getCommentById(Long id) {
        return commentMapper.selectById(id);
    }

    /**
     * 根据文章ID获取评论列表
     */
    public List<Comment> getCommentsByPostId(Long postId) {
        return commentMapper.selectByPostIdWithUser(postId);
    }

    /**
     * 根据用户ID获取评论列表
     */
    public List<Comment> getCommentsByUserId(Long userId) {
        return commentMapper.selectByUserId(userId);
    }
}




