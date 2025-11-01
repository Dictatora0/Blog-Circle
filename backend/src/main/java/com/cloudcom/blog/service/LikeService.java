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
     * 点赞或取消点赞
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

