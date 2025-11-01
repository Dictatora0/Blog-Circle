package com.cloudcom.blog.entity;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 统计结果实体类
 */
@Data
public class Statistic {
    private Long id;
    private String statType;
    private String statKey;
    private Long statValue;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}


