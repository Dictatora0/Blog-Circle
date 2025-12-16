package com.cloudcom.blog.entity;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 文章实体类
 */
@Data
public class Post {
    private Long id;
    private String title;
    private String content;
    private Long authorId;
    private Integer viewCount;
    private String images; // JSON格式存储图片URL数组
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    
    // 关联查询字段（非数据库字段）
    private String authorName;
    private String authorAvatar; // 作者头像
    private Integer commentCount;
    private Integer likeCount; // 点赞数
    private Boolean liked; // 当前用户是否已点赞
}


