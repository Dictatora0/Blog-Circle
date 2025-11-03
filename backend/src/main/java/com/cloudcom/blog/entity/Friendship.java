package com.cloudcom.blog.entity;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 好友关系实体类
 */
@Data
public class Friendship {
    private Long id;
    private Long requesterId;  // 发起方用户ID
    private Long receiverId;   // 接收方用户ID
    private String status;     // PENDING / ACCEPTED / REJECTED
    private LocalDateTime createdAt;
    
    // 关联查询字段（非数据库字段）
    private User requester;    // 发起方用户信息
    private User receiver;     // 接收方用户信息
}



