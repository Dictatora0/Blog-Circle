package com.cloudcom.blog.mapper;

import com.cloudcom.blog.entity.Statistic;
import org.apache.ibatis.annotations.Mapper;

import java.util.List;

/**
 * 统计Mapper接口
 */
@Mapper
public interface StatisticMapper {
    
    /**
     * 插入或更新统计数据
     */
    int insertOrUpdate(Statistic statistic);
    
    /**
     * 根据类型查询统计数据
     */
    List<Statistic> selectByType(String statType);
    
    /**
     * 查询所有统计数据
     */
    List<Statistic> selectAll();
    
    /**
     * 统计用户发文数量（SQL备用方案）
     */
    List<Statistic> selectUserPostCounts();
    
    /**
     * 统计文章浏览次数（SQL备用方案）
     */
    List<Statistic> selectPostViewCounts();
    
    /**
     * 统计评论数量（SQL备用方案）
     */
    List<Statistic> selectCommentCounts();
    
    /**
     * 统计总动态数
     */
    long countTotalPosts();
    
    /**
     * 统计总浏览量
     */
    long countTotalViews();
    
    /**
     * 统计总点赞数
     */
    long countTotalLikes();
    
    /**
     * 统计总评论数
     */
    long countTotalComments();
    
    /**
     * 统计总用户数
     */
    long countTotalUsers();
}



    long countTotalPosts();
    
    /**
     * 统计总浏览量
     */
    long countTotalViews();
    
    /**
     * 统计总点赞数
     */
    long countTotalLikes();
    
    /**
     * 统计总评论数
     */
    long countTotalComments();
    
    /**
     * 统计总用户数
     */
    long countTotalUsers();
}


