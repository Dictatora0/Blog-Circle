package com.cloudcom.blog.mapper;

import com.cloudcom.blog.entity.AccessLog;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 访问日志Mapper接口
 */
@Mapper
public interface AccessLogMapper {
    
    /**
     * 插入访问日志
     */
    int insert(AccessLog log);
    
    /**
     * 查询所有日志
     */
    List<AccessLog> selectAll();
    
    /**
     * 检查用户今天是否访问过某篇文章
     * @param userId 用户ID（0表示未登录用户）
     * @param postId 文章ID
     * @return 访问日志数量
     */
    int countTodayViewByUserAndPost(@Param("userId") Long userId, @Param("postId") Long postId);
}


