package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.AccessLog;
import com.cloudcom.blog.entity.Post;
import com.cloudcom.blog.mapper.AccessLogMapper;
import com.cloudcom.blog.mapper.FriendshipMapper;
import com.cloudcom.blog.mapper.LikeMapper;
import com.cloudcom.blog.mapper.PostMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
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
    @Transactional
    public Post createPost(Post post) {
        // 验证内容不为空
        if (post.getContent() == null || post.getContent().trim().isEmpty()) {
            throw new RuntimeException("动态内容不能为空");
        }
        
        // 调试日志：记录创建前的信息
        System.out.println("PostService.createPost: BEFORE insert - authorId=" + post.getAuthorId() + ", content=" + (post.getContent() != null ? post.getContent().substring(0, Math.min(30, post.getContent().length())) : "null"));
        
        // 插入动态
        System.out.println("PostService.createPost: Calling postMapper.insert - post.getId() before insert=" + post.getId());
        try {
            int result = postMapper.insert(post);
            System.out.println("PostService.createPost: After postMapper.insert - result=" + result + ", post.getId()=" + post.getId());
        } catch (Exception e) {
            System.out.println("PostService.createPost: Exception during insert - " + e.getClass().getName() + ": " + e.getMessage());
            e.printStackTrace();
            throw e;
        }
        
        // 确保ID已设置（MyBatis useGeneratedKeys会自动设置）
        if (post.getId() == null) {
            System.out.println("PostService.createPost: ERROR - post.getId() is null after insert!");
            throw new RuntimeException("创建动态失败：未获取到动态ID");
        }
        
        // 调试日志：记录插入后的信息
        System.out.println("PostService.createPost: AFTER insert - authorId=" + post.getAuthorId() + ", postId=" + post.getId());
        
        // 记录访问日志
        AccessLog log = new AccessLog();
        log.setUserId(post.getAuthorId());
        log.setPostId(post.getId());
        log.setAction("CREATE_POST");
        accessLogMapper.insert(log);
        
        // 调试日志：记录创建的动态信息（事务提交前）
        System.out.println("PostService.createPost: BEFORE commit - authorId=" + post.getAuthorId() + ", postId=" + post.getId() + ", content=" + (post.getContent() != null ? post.getContent().substring(0, Math.min(30, post.getContent().length())) : "null"));
        
        // 事务提交后，数据立即可见（Spring的@Transactional默认行为）
        return post;
    }

    /**
     * 更新文章
     */
    public void updatePost(Post post) {
        postMapper.update(post);
    }

    /**
     * 删除文章（带权限验证）
     */
    public void deletePost(Long id, Long userId) {
        // 查询动态是否存在
        Post post = postMapper.selectById(id);
        if (post == null) {
            throw new RuntimeException("动态不存在");
        }
        
        // 验证是否是作者本人
        if (!post.getAuthorId().equals(userId)) {
            throw new RuntimeException("无权删除他人的动态");
        }
        
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
    @Transactional(readOnly = true, propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    public List<Post> getFriendTimeline(Long userId) {
        // 获取所有好友ID
        List<Long> friendIds = friendshipMapper.selectFriendIdsByUserId(userId);
        
        // 添加自己的ID（确保总是包含自己的动态）
        List<Long> userIds = new ArrayList<>();
        userIds.add(userId);
        if (friendIds != null && !friendIds.isEmpty()) {
            userIds.addAll(friendIds);
        }
        
        // 查询这些用户的动态
        List<Post> posts = postMapper.selectFriendTimeline(userIds);
        
        // 调试日志：记录查询到的动态数量
        System.out.println("getFriendTimeline: userId=" + userId + ", userIds=" + userIds + ", posts count=" + posts.size());
        if (posts.size() > 0) {
            System.out.println("getFriendTimeline: first post authorId=" + posts.get(0).getAuthorId() + ", content=" + (posts.get(0).getContent() != null ? posts.get(0).getContent().substring(0, Math.min(30, posts.get(0).getContent().length())) : "null"));
        } else {
            System.out.println("getFriendTimeline: No posts found, checking if posts exist for userId=" + userId);
            // 直接查询数据库验证
            List<Post> directPosts = postMapper.selectByAuthorId(userId);
            System.out.println("getFriendTimeline: Direct query by authorId=" + userId + " returned " + directPosts.size() + " posts");
        }
        
        // 设置点赞状态
        for (Post post : posts) {
            post.setLiked(likeMapper.selectByPostIdAndUserId(post.getId(), userId) != null);
        }
        
        return posts;
    }
}
