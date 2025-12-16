package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.Like;
import com.cloudcom.blog.mapper.LikeMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 点赞服务类
 */
@Service
public class LikeService {

    @Autowired
    private LikeMapper likeMapper;

    /**
     * 点赞（幂等操作，如果已点赞则忽略）
     */
    @Transactional
    public void like(Long postId, Long userId) {
        // 先检查是否已点赞
        Like existingLike = likeMapper.selectByPostIdAndUserId(postId, userId);
        if (existingLike == null) {
            // 未点赞，则添加点赞
            Like like = new Like();
            like.setPostId(postId);
            like.setUserId(userId);
            likeMapper.insert(like);
        }
        // 如果已点赞，则直接返回（幂等）
    }
    
    /**
     * 取消点赞
     */
    @Transactional
    public void unlike(Long postId, Long userId) {
        likeMapper.delete(postId, userId);
    }
    
    /**
     * 点赞或取消点赞（兼容旧接口）
     */
    @Transactional
    public boolean toggleLike(Long postId, Long userId) {
        Like existingLike = likeMapper.selectByPostIdAndUserId(postId, userId);
        
        if (existingLike != null) {
            // 取消点赞
            likeMapper.delete(postId, userId);
            return false;
        } else {
            // 添加点赞
            Like like = new Like();
            like.setPostId(postId);
            like.setUserId(userId);
            likeMapper.insert(like);
            return true;
        }
    }

    /**
     * 检查是否已点赞
     */
    public boolean isLiked(Long postId, Long userId) {
        Like like = likeMapper.selectByPostIdAndUserId(postId, userId);
        return like != null;
    }

    /**
     * 获取点赞数
     */
    public int getLikeCount(Long postId) {
        return likeMapper.countByPostId(postId);
    }
}

