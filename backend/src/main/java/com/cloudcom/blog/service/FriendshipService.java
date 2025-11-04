package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.Friendship;
import com.cloudcom.blog.entity.User;
import com.cloudcom.blog.mapper.FriendshipMapper;
import com.cloudcom.blog.mapper.UserMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

/**
 * 好友关系服务类
 */
@Service
public class FriendshipService {

    @Autowired
    private FriendshipMapper friendshipMapper;

    @Autowired
    private UserMapper userMapper;

    /**
     * 发送好友请求
     */
    @Transactional
    public Friendship sendFriendRequest(Long requesterId, Long receiverId) {
        // 验证参数
        if (requesterId.equals(receiverId)) {
            throw new IllegalArgumentException("不能添加自己为好友");
        }

        // 检查目标用户是否存在
        User receiver = userMapper.selectById(receiverId);
        if (receiver == null) {
            throw new IllegalArgumentException("目标用户不存在");
        }

        // 检查是否已存在好友关系
        Friendship existing = friendshipMapper.selectByUsers(requesterId, receiverId);
        if (existing != null) {
            if ("ACCEPTED".equals(existing.getStatus())) {
                throw new IllegalArgumentException("已经是好友关系");
            } else if ("PENDING".equals(existing.getStatus())) {
                throw new IllegalArgumentException("好友请求已存在");
            } else if ("REJECTED".equals(existing.getStatus())) {
                // 如果之前被拒绝，允许重新发送，更新状态为PENDING
                friendshipMapper.updateStatus(existing.getId(), "PENDING");
                return friendshipMapper.selectById(existing.getId());
            }
        }

        // 创建新的好友请求
        Friendship friendship = new Friendship();
        friendship.setRequesterId(requesterId);
        friendship.setReceiverId(receiverId);
        friendship.setStatus("PENDING");
        friendshipMapper.insert(friendship);
        
        return friendship;
    }

    /**
     * 接受好友请求
     */
    @Transactional
    public void acceptFriendRequest(Long requestId, Long currentUserId) {
        Friendship friendship = friendshipMapper.selectById(requestId);
        
        if (friendship == null) {
            throw new IllegalArgumentException("好友请求不存在");
        }

        // 验证当前用户是接收方
        if (!friendship.getReceiverId().equals(currentUserId)) {
            throw new IllegalArgumentException("无权操作此请求");
        }

        // 验证状态
        if (!"PENDING".equals(friendship.getStatus())) {
            throw new IllegalArgumentException("请求状态不正确");
        }

        // 更新状态为已接受
        friendshipMapper.updateStatus(requestId, "ACCEPTED");
    }

    /**
     * 拒绝好友请求
     */
    @Transactional
    public void rejectFriendRequest(Long requestId, Long currentUserId) {
        Friendship friendship = friendshipMapper.selectById(requestId);
        
        if (friendship == null) {
            throw new IllegalArgumentException("好友请求不存在");
        }

        // 验证当前用户是接收方
        if (!friendship.getReceiverId().equals(currentUserId)) {
            throw new IllegalArgumentException("无权操作此请求");
        }

        // 验证状态
        if (!"PENDING".equals(friendship.getStatus())) {
            throw new IllegalArgumentException("请求状态不正确");
        }

        // 更新状态为已拒绝
        friendshipMapper.updateStatus(requestId, "REJECTED");
    }

    /**
     * 删除好友
     */
    @Transactional
    public void deleteFriend(Long friendshipId, Long currentUserId) {
        Friendship friendship = friendshipMapper.selectById(friendshipId);
        
        if (friendship == null) {
            throw new IllegalArgumentException("好友关系不存在");
        }

        // 验证当前用户是好友关系中的一方
        if (!friendship.getRequesterId().equals(currentUserId) 
            && !friendship.getReceiverId().equals(currentUserId)) {
            throw new IllegalArgumentException("无权操作此关系");
        }

        // 删除好友关系
        friendshipMapper.deleteById(friendshipId);
    }

    /**
     * 删除好友（通过用户ID）
     */
    @Transactional
    public void deleteFriendByUserId(Long currentUserId, Long friendUserId) {
        // 查找两个用户之间的好友关系
        Friendship friendship = friendshipMapper.selectByUsers(currentUserId, friendUserId);
        
        if (friendship == null) {
            throw new IllegalArgumentException("好友关系不存在");
        }

        // 只能删除已接受的好友关系
        if (!"ACCEPTED".equals(friendship.getStatus())) {
            throw new IllegalArgumentException("不是好友关系");
        }

        // 删除好友关系
        friendshipMapper.deleteById(friendship.getId());
    }

    /**
     * 获取好友列表（返回User对象列表）
     */
    public List<User> getFriendList(Long userId) {
        List<Friendship> friendships = friendshipMapper.selectFriendsByUserId(userId);
        List<User> friends = new ArrayList<>();
        
        for (Friendship friendship : friendships) {
            // 判断当前用户是发起方还是接收方，返回对方的信息
            Long friendId = friendship.getRequesterId().equals(userId) 
                ? friendship.getReceiverId() 
                : friendship.getRequesterId();
            
            User friend = userMapper.selectById(friendId);
            if (friend != null) {
                // 不返回密码
                friend.setPassword(null);
                friends.add(friend);
            }
        }
        
        return friends;
    }

    /**
     * 获取待处理的好友请求
     */
    public List<Friendship> getPendingRequests(Long userId) {
        List<Friendship> friendships = friendshipMapper.selectPendingRequestsByReceiverId(userId);
        
        // 清理 requester 对象中的密码字段
        for (Friendship friendship : friendships) {
            if (friendship.getRequester() != null) {
                friendship.getRequester().setPassword(null);
            }
        }
        
        return friendships;
    }

    /**
     * 获取我发送的好友请求
     */
    public List<Friendship> getSentRequests(Long userId) {
        return friendshipMapper.selectPendingRequestsByRequesterId(userId);
    }

    /**
     * 检查两个用户是否为好友
     */
    public boolean isFriend(Long userId1, Long userId2) {
        Friendship friendship = friendshipMapper.selectByUsers(userId1, userId2);
        return friendship != null && "ACCEPTED".equals(friendship.getStatus());
    }

    /**
     * 获取用户的所有好友ID（用于时间线查询）
     */
    public List<Long> getFriendIds(Long userId) {
        return friendshipMapper.selectFriendIdsByUserId(userId);
    }

    /**
     * 搜索用户（通过用户名或邮箱）
     */
    public List<User> searchUsers(String keyword, Long currentUserId) {
        List<User> users = userMapper.searchUsers(keyword);
        
        // 过滤掉当前用户（密码字段已在SQL查询中排除，无需手动移除）
        List<User> result = new ArrayList<>();
        for (User user : users) {
            if (!user.getId().equals(currentUserId)) {
                result.add(user);
            }
        }
        
        return result;
    }
}

