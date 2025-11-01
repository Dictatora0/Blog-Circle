package com.cloudcom.blog.mapper;

import com.cloudcom.blog.entity.Like;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 点赞Mapper接口
 */
@Mapper
public interface LikeMapper {
    
    /**
     * 插入点赞
     */
    int insert(Like like);
    
    /**
     * 删除点赞
     */
    int delete(@Param("postId") Long postId, @Param("userId") Long userId);
    
    /**
     * 检查是否已点赞
     */
    Like selectByPostIdAndUserId(@Param("postId") Long postId, @Param("userId") Long userId);
    
    /**
     * 统计文章点赞数
     */
    int countByPostId(Long postId);
    
    /**
     * 根据文章ID查询所有点赞用户
     */
    List<Like> selectByPostId(Long postId);
}

