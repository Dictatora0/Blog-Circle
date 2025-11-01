package com.cloudcom.blog.controller;

import com.cloudcom.blog.common.Result;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * 根路径控制器（避免 Whitelabel Error Page）
 */
@RestController
public class IndexController {

    @GetMapping("/")
    public Result<Map<String, Object>> index() {
        Map<String, Object> info = new HashMap<>();
        info.put("name", "简易博客系统");
        info.put("version", "1.0.0");
        info.put("status", "running");
        info.put("api", "/api");
        return Result.success("博客系统 API 服务正在运行", info);
    }

    @GetMapping("/api")
    public Result<Map<String, String>> api() {
        Map<String, String> endpoints = new HashMap<>();
        endpoints.put("登录", "POST /api/auth/login");
        endpoints.put("注册", "POST /api/auth/register");
        endpoints.put("文章列表", "GET /api/posts/list");
        endpoints.put("文章详情", "GET /api/posts/{id}/detail");
        endpoints.put("创建文章", "POST /api/posts");
        endpoints.put("评论列表", "GET /api/comments/post/{postId}");
        endpoints.put("统计数据", "GET /api/stats");
        return Result.success("API 接口列表", endpoints);
    }
}

