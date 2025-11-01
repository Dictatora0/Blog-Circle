package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.AccessLog;
import com.cloudcom.blog.entity.Post;
import com.cloudcom.blog.mapper.AccessLogMapper;
import com.cloudcom.blog.mapper.LikeMapper;
import com.cloudcom.blog.mapper.PostMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
            // 增加浏览次数
            postMapper.incrementViewCount(id);
            
            // 设置点赞状态
            if (userId != null && userId > 0) {
                post.setLiked(likeMapper.selectByPostIdAndUserId(id, userId) != null);
            }
            
            // 记录访问日志
            AccessLog log = new AccessLog();
            log.setUserId(userId != null ? userId : 0L);
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
}

