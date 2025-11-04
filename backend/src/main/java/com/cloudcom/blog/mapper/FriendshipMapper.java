package com.cloudcom.blog.mapper;

import com.cloudcom.blog.entity.Friendship;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 好友关系Mapper接口
 */
@Mapper
public interface FriendshipMapper {
    
    /**
     * 插入好友关系
     */
    int insert(Friendship friendship);
    
    /**
     * 更新好友关系状态
     */
    int updateStatus(@Param("id") Long id, @Param("status") String status);
    
    /**
     * 删除好友关系
     */
    int deleteById(Long id);
    
    /**
     * 根据ID查询好友关系
     */
    Friendship selectById(Long id);
    
    /**
     * 查询两个用户之间的好友关系
     */
    Friendship selectByUsers(@Param("userId1") Long userId1, @Param("userId2") Long userId2);
    
    /**
     * 查询用户的好友列表（ACCEPTED状态）
     */
    List<Friendship> selectFriendsByUserId(Long userId);
    
    /**
     * 查询发送给用户的好友请求（PENDING状态，接收方是当前用户）
     */
    List<Friendship> selectPendingRequestsByReceiverId(Long receiverId);
    
    /**
     * 查询用户发送的好友请求（PENDING状态，发起方是当前用户）
     */
    List<Friendship> selectPendingRequestsByRequesterId(Long requesterId);
    
    /**
     * 获取用户的所有好友ID（包括自己和好友）
     */
    List<Long> selectFriendIdsByUserId(Long userId);
}














