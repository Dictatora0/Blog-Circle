package com.cloudcom.blog.mapper;

import com.cloudcom.blog.entity.Comment;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 评论Mapper接口
 */
@Mapper
public interface CommentMapper {
    
    /**
     * 插入评论
     */
    int insert(Comment comment);
    
    /**
     * 根据ID删除评论
     */
    int deleteById(Long id);
    
    /**
     * 更新评论
     */
    int update(Comment comment);
    
    /**
     * 根据ID查询评论
     */
    Comment selectById(Long id);
    
    /**
     * 根据文章ID查询评论（带用户信息）
     */
    List<Comment> selectByPostIdWithUser(Long postId);
    
    /**
     * 根据用户ID查询评论
     */
    List<Comment> selectByUserId(Long userId);
    
    /**
     * 统计文章评论数量
     */
    int countByPostId(Long postId);
}


