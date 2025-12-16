package com.cloudcom.blog.entity;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 访问日志实体类（用于Spark分析）
 */
@Data
public class AccessLog {
    private Long id;
    private Long userId;
    private Long postId;
    private String action;
    private LocalDateTime createdAt;
}


