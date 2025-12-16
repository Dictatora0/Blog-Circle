package com.cloudcom.blog.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.Arrays;
import java.util.Collections;

/**
 * CORS配置 - 使用过滤器方式（优先级更高）
 * 
 * 该配置提供了比 WebMvcConfigurer 更高优先级的CORS处理
 * 确保在所有情况下都能正确处理跨域请求
 * 
 * @author Lying
 * @since 2025-11-05
 */
@Configuration
public class CorsConfig {

    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        
        // 获取当前运行环境
        String activeProfile = System.getProperty("spring.profiles.active", "default");
        
        // 开发/测试环境：允许所有来源
        if ("default".equals(activeProfile) || "test".equals(activeProfile)) {
            config.setAllowedOriginPatterns(Collections.singletonList("*"));
            System.out.println("CORS配置: 开发模式 - 允许所有来源");
        } else {
            // 生产环境：明确指定允许的来源
            config.setAllowedOrigins(Arrays.asList(
                "http://localhost:5173",
                "http://localhost:3000",
                "http://localhost:8080",
                "http://10.211.55.11:8080"
            ));
            System.out.println("CORS配置: 生产模式 - 仅允许指定来源");
        }
        
        // 允许携带认证信息（cookies, authorization headers）
        config.setAllowCredentials(true);
        
        // 允许所有请求头
        config.setAllowedHeaders(Collections.singletonList("*"));
        
        // 允许的HTTP方法
        config.setAllowedMethods(Arrays.asList(
            "GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"
        ));
        
        // 暴露的响应头（前端可以访问的响应头）
        config.setExposedHeaders(Arrays.asList(
            "Authorization",
            "Content-Type",
            "X-Total-Count",
            "X-Token",
            "Access-Control-Allow-Origin"
        ));
        
        // 预检请求的缓存时间（秒）
        config.setMaxAge(3600L);
        
        // 注册CORS配置到所有路径
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        
        return new CorsFilter(source);
    }
}

