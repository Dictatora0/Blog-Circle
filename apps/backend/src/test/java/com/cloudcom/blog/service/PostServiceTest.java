package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.AccessLog;
import com.cloudcom.blog.entity.Post;
import com.cloudcom.blog.mapper.AccessLogMapper;
import com.cloudcom.blog.mapper.LikeMapper;
import com.cloudcom.blog.mapper.PostMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.*;

/**
 * 文章服务测试类
 * 
 * Given-When-Then 风格测试，重点测试浏览量逻辑：
 * 1. 首次访问增加浏览量
 * 2. 同一天重复访问不增加浏览量
 * 3. 作者查看自己的文章不增加浏览量
 * 4. 未登录用户访问逻辑
 * 5. 访问日志始终记录
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("文章服务测试 - 浏览量逻辑")
class PostServiceTest {

    @Mock
    private PostMapper postMapper;

    @Mock
    private AccessLogMapper accessLogMapper;

    @Mock
    private LikeMapper likeMapper;

    @InjectMocks
    private PostService postService;

    private Post testPost;
    private Post authorPost;

    @BeforeEach
    void setUp() {
        // Given: 准备测试数据
        testPost = new Post();
        testPost.setId(1L);
        testPost.setTitle("测试文章");
        testPost.setContent("这是一篇测试文章的内容");
        testPost.setAuthorId(2L); // 作者ID为2
        testPost.setViewCount(10);
        testPost.setCreatedAt(LocalDateTime.now());

        authorPost = new Post();
        authorPost.setId(2L);
        authorPost.setTitle("作者的文章");
        authorPost.setContent("作者自己的文章");
        authorPost.setAuthorId(1L); // 作者ID为1
        authorPost.setViewCount(5);
        authorPost.setCreatedAt(LocalDateTime.now());
    }

    @Test
    @DisplayName("场景1: 首次访问增加浏览量")
    void testGetPostById_FirstVisit_IncrementsViewCount() {
        // Given: 用户首次访问文章，今天未访问过
        Long userId = 1L;
        Long postId = 1L;
        
        when(postMapper.selectById(postId)).thenReturn(testPost);
        when(likeMapper.selectByPostIdAndUserId(postId, userId)).thenReturn(null);
        when(accessLogMapper.countTodayViewByUserAndPost(userId, postId)).thenReturn(0);
        when(accessLogMapper.insert(any(AccessLog.class))).thenAnswer(invocation -> {
            AccessLog log = invocation.getArgument(0);
            log.setId(1L);
            return 1;
        });

        // When: 获取文章详情
        Post result = postService.getPostById(postId, userId);

        // Then: 验证浏览量已增加
        assertThat(result).isNotNull();
        assertThat(result.getViewCount()).isEqualTo(11); // 10 + 1
        
        // 验证调用了增加浏览量方法
        verify(postMapper).incrementViewCount(postId);
        
        // 验证访问日志已记录
        ArgumentCaptor<AccessLog> logCaptor = ArgumentCaptor.forClass(AccessLog.class);
        verify(accessLogMapper).insert(logCaptor.capture());
        AccessLog capturedLog = logCaptor.getValue();
        assertThat(capturedLog.getUserId()).isEqualTo(userId);
        assertThat(capturedLog.getPostId()).isEqualTo(postId);
        assertThat(capturedLog.getAction()).isEqualTo("VIEW_POST");
    }

    @Test
    @DisplayName("场景2: 同一天重复访问不增加浏览量")
    void testGetPostById_RepeatVisitSameDay_NoIncrement() {
        // Given: 用户今天已经访问过这篇文章
        Long userId = 1L;
        Long postId = 1L;
        
        when(postMapper.selectById(postId)).thenReturn(testPost);
        when(likeMapper.selectByPostIdAndUserId(postId, userId)).thenReturn(null);
        when(accessLogMapper.countTodayViewByUserAndPost(userId, postId)).thenReturn(1); // 今天已访问过
        when(accessLogMapper.insert(any(AccessLog.class))).thenAnswer(invocation -> {
            AccessLog log = invocation.getArgument(0);
            log.setId(2L);
            return 1;
        });

        // When: 再次获取文章详情
        Post result = postService.getPostById(postId, userId);

        // Then: 验证浏览量未增加
        assertThat(result).isNotNull();
        assertThat(result.getViewCount()).isEqualTo(10); // 保持原值
        
        // 验证未调用增加浏览量方法
        verify(postMapper, never()).incrementViewCount(postId);
        
        // 验证访问日志仍然记录
        verify(accessLogMapper).insert(any(AccessLog.class));
    }

    @Test
    @DisplayName("场景3: 作者查看自己的文章不增加浏览量")
    void testGetPostById_AuthorViewsOwnPost_NoIncrement() {
        // Given: 作者查看自己的文章
        Long authorId = 1L;
        Long postId = 2L;
        
        when(postMapper.selectById(postId)).thenReturn(authorPost);
        when(likeMapper.selectByPostIdAndUserId(postId, authorId)).thenReturn(null);
        when(accessLogMapper.insert(any(AccessLog.class))).thenAnswer(invocation -> {
            AccessLog log = invocation.getArgument(0);
            log.setId(1L);
            return 1;
        });

        // When: 作者获取自己的文章详情
        Post result = postService.getPostById(postId, authorId);

        // Then: 验证浏览量未增加
        assertThat(result).isNotNull();
        assertThat(result.getViewCount()).isEqualTo(5); // 保持原值
        
        // 验证未调用增加浏览量方法
        verify(postMapper, never()).incrementViewCount(postId);
        
        // 验证未检查访问日志（因为作者不增加浏览量）
        verify(accessLogMapper, never()).countTodayViewByUserAndPost(anyLong(), anyLong());
        
        // 验证访问日志仍然记录
        verify(accessLogMapper).insert(any(AccessLog.class));
    }

    @Test
    @DisplayName("场景4: 未登录用户首次访问增加浏览量")
    void testGetPostById_AnonymousUserFirstVisit_IncrementsViewCount() {
        // Given: 未登录用户首次访问
        Long userId = null; // 未登录
        Long postId = 1L;
        
        when(postMapper.selectById(postId)).thenReturn(testPost);
        when(accessLogMapper.countTodayViewByUserAndPost(0L, postId)).thenReturn(0); // 未登录用户ID为0
        when(accessLogMapper.insert(any(AccessLog.class))).thenAnswer(invocation -> {
            AccessLog log = invocation.getArgument(0);
            log.setId(1L);
            return 1;
        });

        // When: 未登录用户获取文章详情
        Post result = postService.getPostById(postId, userId);

        // Then: 验证浏览量已增加
        assertThat(result).isNotNull();
        assertThat(result.getViewCount()).isEqualTo(11); // 10 + 1
        
        // 验证调用了增加浏览量方法
        verify(postMapper).incrementViewCount(postId);
        
        // 验证访问日志已记录（userId为0）
        ArgumentCaptor<AccessLog> logCaptor = ArgumentCaptor.forClass(AccessLog.class);
        verify(accessLogMapper).insert(logCaptor.capture());
        AccessLog capturedLog = logCaptor.getValue();
        assertThat(capturedLog.getUserId()).isEqualTo(0L);
        assertThat(capturedLog.getPostId()).isEqualTo(postId);
        assertThat(capturedLog.getAction()).isEqualTo("VIEW_POST");
    }

    @Test
    @DisplayName("场景5: 未登录用户重复访问不增加浏览量")
    void testGetPostById_AnonymousUserRepeatVisit_NoIncrement() {
        // Given: 未登录用户今天已经访问过
        Long userId = null;
        Long postId = 1L;
        
        when(postMapper.selectById(postId)).thenReturn(testPost);
        when(accessLogMapper.countTodayViewByUserAndPost(0L, postId)).thenReturn(1); // 今天已访问过
        when(accessLogMapper.insert(any(AccessLog.class))).thenAnswer(invocation -> {
            AccessLog log = invocation.getArgument(0);
            log.setId(2L);
            return 1;
        });

        // When: 未登录用户再次访问
        Post result = postService.getPostById(postId, userId);

        // Then: 验证浏览量未增加
        assertThat(result).isNotNull();
        assertThat(result.getViewCount()).isEqualTo(10); // 保持原值
        
        // 验证未调用增加浏览量方法
        verify(postMapper, never()).incrementViewCount(postId);
        
        // 验证访问日志仍然记录
        verify(accessLogMapper).insert(any(AccessLog.class));
    }

    @Test
    @DisplayName("场景6: 访问日志始终记录，无论是否增加浏览量")
    void testGetPostById_AccessLogAlwaysRecorded() {
        // Given: 用户今天已访问过
        Long userId = 1L;
        Long postId = 1L;
        
        when(postMapper.selectById(postId)).thenReturn(testPost);
        when(likeMapper.selectByPostIdAndUserId(postId, userId)).thenReturn(null);
        when(accessLogMapper.countTodayViewByUserAndPost(userId, postId)).thenReturn(1);
        when(accessLogMapper.insert(any(AccessLog.class))).thenAnswer(invocation -> {
            AccessLog log = invocation.getArgument(0);
            log.setId(2L);
            return 1;
        });

        // When: 获取文章详情（不增加浏览量）
        Post result = postService.getPostById(postId, userId);

        // Then: 验证访问日志仍然记录
        assertThat(result).isNotNull();
        verify(accessLogMapper, times(1)).insert(any(AccessLog.class));
    }

    @Test
    @DisplayName("场景7: 文章不存在时返回null")
    void testGetPostById_PostNotFound_ReturnsNull() {
        // Given: 文章不存在
        Long userId = 1L;
        Long postId = 999L;
        
        when(postMapper.selectById(postId)).thenReturn(null);

        // When: 获取不存在的文章详情
        Post result = postService.getPostById(postId, userId);

        // Then: 验证返回null
        assertThat(result).isNull();
        
        // 验证未调用任何增加浏览量或记录日志的方法
        verify(postMapper, never()).incrementViewCount(anyLong());
        verify(accessLogMapper, never()).insert(any(AccessLog.class));
    }
}














