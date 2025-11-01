package com.cloudcom.blog.mapper;

import com.cloudcom.blog.entity.AccessLog;
import org.apache.ibatis.annotations.Mapper;

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
}


