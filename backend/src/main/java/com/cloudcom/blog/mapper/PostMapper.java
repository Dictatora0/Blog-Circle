package com.cloudcom.blog.mapper;

import com.cloudcom.blog.entity.Post;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 文章Mapper接口
 */
@Mapper
public interface PostMapper {
    
    /**
     * 插入文章
     */
    int insert(Post post);
    
    /**
     * 根据ID删除文章
     */
    int deleteById(Long id);
    
    /**
     * 更新文章
     */
    int update(Post post);
    
    /**
     * 根据ID查询文章
     */
    Post selectById(Long id);
    
    /**
     * 查询所有文章（带作者信息）
     */
    List<Post> selectAllWithAuthor();
    
    /**
     * 根据作者ID查询文章
     */
    List<Post> selectByAuthorId(Long authorId);
    
    /**
     * 增加浏览次数
     */
    int incrementViewCount(Long id);
}


