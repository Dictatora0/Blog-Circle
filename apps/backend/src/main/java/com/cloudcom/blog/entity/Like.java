package com.cloudcom.blog.entity;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 点赞实体类
 */
@Data
public class Like {
    private Long id;
    private Long postId;
    private Long userId;
    private LocalDateTime createdAt;
}

