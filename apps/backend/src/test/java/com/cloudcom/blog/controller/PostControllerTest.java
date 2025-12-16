package com.cloudcom.blog.controller;

import com.cloudcom.blog.entity.Post;
import com.cloudcom.blog.interceptor.JwtInterceptor;
import com.cloudcom.blog.service.PostService;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * 文章控制器测试类
 * 
 * Given-When-Then 风格测试：
 * 1. 创建文章成功
 * 2. 获取文章列表成功
 * 3. 获取文章详情成功
 * 4. 更新文章成功
 * 5. 删除文章成功
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("文章控制器测试")
class PostControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PostService postService;

    @MockBean
    private JwtInterceptor jwtInterceptor;

    @Autowired
    private ObjectMapper objectMapper;

    private Post testPost;

    @BeforeEach
    void setUp() throws Exception {
        // Given: 准备测试数据
        testPost = new Post();
        testPost.setId(1L);
        testPost.setTitle("测试文章");
        testPost.setContent("这是一篇测试文章的内容");
        testPost.setAuthorId(1L);
        testPost.setViewCount(0);
        testPost.setCreatedAt(LocalDateTime.now());

        // Mock拦截器行为：允许所有请求通过并设置userId
        when(jwtInterceptor.preHandle(any(HttpServletRequest.class), any(HttpServletResponse.class), any()))
                .thenAnswer(invocation -> {
                    HttpServletRequest request = invocation.getArgument(0);
                    request.setAttribute("userId", 1L);
                    return true;
                });
    }

    @Test
    @DisplayName("场景1: 创建文章成功")
    void testCreatePost() throws Exception {
        // Given: 模拟文章服务返回新创建的文章
        Post newPost = new Post();
        newPost.setId(1L);
        newPost.setTitle("新文章");
        newPost.setContent("新文章内容");
        newPost.setAuthorId(1L);

        when(postService.createPost(any(Post.class))).thenReturn(newPost);

        // When: 发送创建文章请求
        Post postData = new Post();
        postData.setTitle("新文章");
        postData.setContent("新文章内容");

        // Then: 验证响应
        mockMvc.perform(post("/api/posts")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(postData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("发布成功"))
                .andExpect(jsonPath("$.data.title").value("新文章"));

        verify(postService).createPost(any(Post.class));
    }

    @Test
    @DisplayName("场景2: 获取文章列表成功")
    void testGetAllPosts() throws Exception {
        // Given: 模拟文章服务返回文章列表
        Post post1 = new Post();
        post1.setId(1L);
        post1.setTitle("文章1");
        post1.setAuthorId(1L);

        Post post2 = new Post();
        post2.setId(2L);
        post2.setTitle("文章2");
        post2.setAuthorId(2L);

        List<Post> posts = Arrays.asList(post1, post2);
        // /api/posts/list 被排除在拦截器外，userId可能为null
        when(postService.getAllPosts(any())).thenReturn(posts);

        // When: 发送获取文章列表请求
        // Then: 验证响应
        mockMvc.perform(get("/api/posts/list"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data").isArray())
                .andExpect(jsonPath("$.data.length()").value(2));

        verify(postService).getAllPosts(any());
    }

    @Test
    @DisplayName("场景3: 获取文章详情成功")
    void testGetPostDetail() throws Exception {
        // Given: 模拟文章服务返回文章详情
        when(postService.getPostById(eq(1L), anyLong())).thenReturn(testPost);

        // When: 发送获取文章详情请求
        // Then: 验证响应
        mockMvc.perform(get("/api/posts/1/detail"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.id").value(1))
                .andExpect(jsonPath("$.data.title").value("测试文章"));

        verify(postService).getPostById(eq(1L), anyLong());
    }

    @Test
    @DisplayName("场景4: 更新文章成功")
    void testUpdatePost() throws Exception {
        // Given: 模拟文章服务更新成功
        doNothing().when(postService).updatePost(any(Post.class));

        // When: 发送更新文章请求
        Post updateData = new Post();
        updateData.setTitle("更新后的标题");
        updateData.setContent("更新后的内容");

        // Then: 验证响应
        mockMvc.perform(put("/api/posts/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updateData)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("更新成功"));

        verify(postService).updatePost(any(Post.class));
    }

    @Test
    @DisplayName("场景5: 删除文章成功")
    void testDeletePost() throws Exception {
        // Given: 模拟文章服务删除成功
        doNothing().when(postService).deletePost(1L, 1L);

        // When: 发送删除文章请求
        // Then: 验证响应
        mockMvc.perform(delete("/api/posts/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("删除成功"));

        verify(postService).deletePost(eq(1L), anyLong());
    }

    @Test
    @DisplayName("场景6: 获取我的文章成功")
    void testGetMyPosts() throws Exception {
        // Given: 模拟文章服务返回我的文章列表
        Post myPost = new Post();
        myPost.setId(1L);
        myPost.setTitle("我的文章");
        myPost.setAuthorId(1L);

        List<Post> myPosts = Arrays.asList(myPost);
        when(postService.getPostsByAuthorId(anyLong(), anyLong())).thenReturn(myPosts);

        // When: 发送获取我的文章请求
        // Then: 验证响应
        mockMvc.perform(get("/api/posts/my"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data").isArray())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].title").value("我的文章"));

        verify(postService).getPostsByAuthorId(anyLong(), anyLong());
    }
}

