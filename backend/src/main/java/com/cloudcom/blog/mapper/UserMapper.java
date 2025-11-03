package com.cloudcom.blog.mapper;

import com.cloudcom.blog.entity.User;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 用户Mapper接口
 */
@Mapper
public interface UserMapper {
    
    /**
     * 插入用户
     */
    int insert(User user);
    
    /**
     * 根据ID删除用户
     */
    int deleteById(Long id);
    
    /**
     * 更新用户信息
     */
    int update(User user);
    
    /**
     * 根据ID查询用户
     */
    User selectById(Long id);
    
    /**
     * 根据用户名查询用户
     */
    User selectByUsername(String username);
    
    /**
     * 查询所有用户
     */
    List<User> selectAll();
    
    /**
     * 搜索用户（通过用户名或邮箱）
     */
    List<User> searchUsers(@Param("keyword") String keyword);
}


