package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.AccessLog;
import com.cloudcom.blog.entity.Comment;
import com.cloudcom.blog.mapper.AccessLogMapper;
import com.cloudcom.blog.mapper.CommentMapper;
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
     * 删除评论
     */
    public void deleteComment(Long id) {
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




