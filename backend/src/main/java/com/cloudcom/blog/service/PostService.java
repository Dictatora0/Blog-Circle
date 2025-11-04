package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.AccessLog;
import com.cloudcom.blog.entity.Post;
import com.cloudcom.blog.mapper.AccessLogMapper;
import com.cloudcom.blog.mapper.FriendshipMapper;
import com.cloudcom.blog.mapper.LikeMapper;
import com.cloudcom.blog.mapper.PostMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

/**
 * 文章服务类
 */
@Service
public class PostService {

    @Autowired
    private PostMapper postMapper;

    @Autowired
    private AccessLogMapper accessLogMapper;

    @Autowired
    private LikeMapper likeMapper;

    @Autowired
    private FriendshipMapper friendshipMapper;

    /**
     * 创建文章
     */
    public Post createPost(Post post) {
        postMapper.insert(post);
        
        // 记录访问日志
        AccessLog log = new AccessLog();
        log.setUserId(post.getAuthorId());
        log.setPostId(post.getId());
        log.setAction("CREATE_POST");
        accessLogMapper.insert(log);
        
        return post;
    }

    /**
     * 更新文章
     */
    public void updatePost(Post post) {
        postMapper.update(post);
    }

    /**
     * 删除文章
     */
    public void deletePost(Long id) {
        postMapper.deleteById(id);
    }

    /**
     * 根据ID获取文章
     */
    @Transactional
    public Post getPostById(Long id, Long userId) {
        Post post = postMapper.selectById(id);
        if (post != null) {
            // 设置点赞状态
            if (userId != null && userId > 0) {
                post.setLiked(likeMapper.selectByPostIdAndUserId(id, userId) != null);
            }
            
            // 处理浏览量和访问日志
            Long actualUserId = userId != null ? userId : 0L;
            boolean isAuthor = userId != null && userId.equals(post.getAuthorId());
            
            // 作者查看自己的文章不增加浏览量
            if (!isAuthor) {
                // 检查用户今天是否已经访问过这篇文章
                int todayViewCount = accessLogMapper.countTodayViewByUserAndPost(actualUserId, id);
                
                // 只有在今天首次访问时才增加浏览量
                if (todayViewCount == 0) {
                    // 增加浏览次数
                    postMapper.incrementViewCount(id);
                    // 更新返回对象中的浏览量
                    post.setViewCount(post.getViewCount() + 1);
                }
            }
            
            // 记录访问日志（无论是否增加浏览量都记录）
            AccessLog log = new AccessLog();
            log.setUserId(actualUserId);
            log.setPostId(id);
            log.setAction("VIEW_POST");
            accessLogMapper.insert(log);
        }
        return post;
    }

    /**
     * 获取所有文章（带点赞状态）
     */
    public List<Post> getAllPosts(Long userId) {
        List<Post> posts = postMapper.selectAllWithAuthor();
        // 设置点赞状态
        if (userId != null && userId > 0) {
            for (Post post : posts) {
                post.setLiked(likeMapper.selectByPostIdAndUserId(post.getId(), userId) != null);
            }
        }
        return posts;
    }

    /**
     * 根据作者ID获取文章
     */
    public List<Post> getPostsByAuthorId(Long authorId, Long currentUserId) {
        List<Post> posts = postMapper.selectByAuthorId(authorId);
        // 设置点赞状态
        if (currentUserId != null && currentUserId > 0) {
            for (Post post : posts) {
                post.setLiked(likeMapper.selectByPostIdAndUserId(post.getId(), currentUserId) != null);
            }
        }
        return posts;
    }

    /**
     * 获取好友时间线（自己+好友的动态）
     */
    public List<Post> getFriendTimeline(Long userId) {
        // 获取所有好友ID
        List<Long> friendIds = friendshipMapper.selectFriendIdsByUserId(userId);
        
        // 添加自己的ID
        List<Long> userIds = new ArrayList<>();
        userIds.add(userId);
        if (friendIds != null && !friendIds.isEmpty()) {
            userIds.addAll(friendIds);
        }
        
        // 查询这些用户的动态
        List<Post> posts = postMapper.selectFriendTimeline(userIds);
        
        // 设置点赞状态
        for (Post post : posts) {
            post.setLiked(likeMapper.selectByPostIdAndUserId(post.getId(), userId) != null);
        }
        
        return posts;
    }
}

