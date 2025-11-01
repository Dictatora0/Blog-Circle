package com.cloudcom.blog.entity;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 评论实体类
 */
@Data
public class Comment {
    private Long id;
    private Long postId;
    private Long userId;
    private String content;
    private LocalDateTime createdAt;
    
    // 关联查询字段（非数据库字段）
    private String username;
    private String nickname;
}


