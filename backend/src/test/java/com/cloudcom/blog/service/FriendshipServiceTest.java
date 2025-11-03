package com.cloudcom.blog.service;

import com.cloudcom.blog.entity.Friendship;
import com.cloudcom.blog.entity.User;
import com.cloudcom.blog.mapper.FriendshipMapper;
import com.cloudcom.blog.mapper.UserMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * 好友关系服务测试类
 * 
 * Given-When-Then 风格测试：
 * 1. 发送好友请求成功
 * 2. 发送好友请求失败（不能添加自己为好友）
 * 3. 发送好友请求失败（目标用户不存在）
 * 4. 发送好友请求失败（已经是好友）
 * 5. 接受好友请求成功
 * 6. 拒绝好友请求成功
 * 7. 删除好友成功
 * 8. 获取好友列表
 * 9. 获取待处理好友请求
 * 10. 搜索用户
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("好友关系服务测试")
class FriendshipServiceTest {

    @Mock
    private FriendshipMapper friendshipMapper;

    @Mock
    private UserMapper userMapper;

    @InjectMocks
    private FriendshipService friendshipService;

    private User requester;
    private User receiver;
    private Friendship pendingFriendship;
    private Friendship acceptedFriendship;

    @BeforeEach
    void setUp() {
        // Given: 准备测试数据
        requester = new User();
        requester.setId(1L);
        requester.setUsername("user1");
        requester.setNickname("用户1");
        requester.setEmail("user1@example.com");

        receiver = new User();
        receiver.setId(2L);
        receiver.setUsername("user2");
        receiver.setNickname("用户2");
        receiver.setEmail("user2@example.com");

        pendingFriendship = new Friendship();
        pendingFriendship.setId(1L);
        pendingFriendship.setRequesterId(1L);
        pendingFriendship.setReceiverId(2L);
        pendingFriendship.setStatus("PENDING");

        acceptedFriendship = new Friendship();
        acceptedFriendship.setId(2L);
        acceptedFriendship.setRequesterId(1L);
        acceptedFriendship.setReceiverId(2L);
        acceptedFriendship.setStatus("ACCEPTED");
    }

    @Test
    @DisplayName("场景1: 发送好友请求成功")
    void testSendFriendRequestSuccess() {
        // Given: 目标用户存在，且不是好友
        when(userMapper.selectById(2L)).thenReturn(receiver);
        when(friendshipMapper.selectByUsers(1L, 2L)).thenReturn(null);
        when(friendshipMapper.insert(any(Friendship.class))).thenAnswer(invocation -> {
            Friendship friendship = invocation.getArgument(0);
            friendship.setId(1L);
            return 1;
        });

        // When: 发送好友请求
        Friendship result = friendshipService.sendFriendRequest(1L, 2L);

        // Then: 验证结果
        assertThat(result).isNotNull();
        verify(userMapper).selectById(2L);
        verify(friendshipMapper).selectByUsers(1L, 2L);
        verify(friendshipMapper).insert(any(Friendship.class));
    }

    @Test
    @DisplayName("场景2: 发送好友请求失败 - 不能添加自己为好友")
    void testSendFriendRequestFailed_CannotAddSelf() {
        // When & Then: 尝试添加自己为好友应该抛出异常
        assertThatThrownBy(() -> friendshipService.sendFriendRequest(1L, 1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("不能添加自己为好友");

        verify(friendshipMapper, never()).insert(any(Friendship.class));
    }

    @Test
    @DisplayName("场景3: 发送好友请求失败 - 目标用户不存在")
    void testSendFriendRequestFailed_UserNotFound() {
        // Given: 目标用户不存在
        when(userMapper.selectById(999L)).thenReturn(null);

        // When & Then: 尝试发送请求应该抛出异常
        assertThatThrownBy(() -> friendshipService.sendFriendRequest(1L, 999L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("目标用户不存在");

        verify(userMapper).selectById(999L);
        verify(friendshipMapper, never()).insert(any(Friendship.class));
    }

    @Test
    @DisplayName("场景4: 发送好友请求失败 - 已经是好友")
    void testSendFriendRequestFailed_AlreadyFriends() {
        // Given: 已经是好友关系
        when(userMapper.selectById(2L)).thenReturn(receiver);
        when(friendshipMapper.selectByUsers(1L, 2L)).thenReturn(acceptedFriendship);

        // When & Then: 尝试再次发送请求应该抛出异常
        assertThatThrownBy(() -> friendshipService.sendFriendRequest(1L, 2L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("已经是好友关系");

        verify(friendshipMapper, never()).insert(any(Friendship.class));
    }

    @Test
    @DisplayName("场景5: 发送好友请求失败 - 好友请求已存在")
    void testSendFriendRequestFailed_RequestPending() {
        // Given: 已有待处理的好友请求
        when(userMapper.selectById(2L)).thenReturn(receiver);
        when(friendshipMapper.selectByUsers(1L, 2L)).thenReturn(pendingFriendship);

        // When & Then: 尝试再次发送请求应该抛出异常
        assertThatThrownBy(() -> friendshipService.sendFriendRequest(1L, 2L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("好友请求已存在");

        verify(friendshipMapper, never()).insert(any(Friendship.class));
    }

    @Test
    @DisplayName("场景6: 接受好友请求成功")
    void testAcceptFriendRequestSuccess() {
        // Given: 存在待处理的好友请求
        when(friendshipMapper.selectById(1L)).thenReturn(pendingFriendship);
        when(friendshipMapper.updateStatus(1L, "ACCEPTED")).thenReturn(1);

        // When: 接受好友请求
        friendshipService.acceptFriendRequest(1L, 2L);

        // Then: 验证状态已更新
        verify(friendshipMapper).selectById(1L);
        verify(friendshipMapper).updateStatus(1L, "ACCEPTED");
    }

    @Test
    @DisplayName("场景7: 接受好友请求失败 - 无权操作")
    void testAcceptFriendRequestFailed_Unauthorized() {
        // Given: 当前用户不是接收方
        when(friendshipMapper.selectById(1L)).thenReturn(pendingFriendship);

        // When & Then: 尝试接受请求应该抛出异常
        assertThatThrownBy(() -> friendshipService.acceptFriendRequest(1L, 999L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("无权操作此请求");

        verify(friendshipMapper, never()).updateStatus(anyLong(), anyString());
    }

    @Test
    @DisplayName("场景8: 拒绝好友请求成功")
    void testRejectFriendRequestSuccess() {
        // Given: 存在待处理的好友请求
        when(friendshipMapper.selectById(1L)).thenReturn(pendingFriendship);
        when(friendshipMapper.updateStatus(1L, "REJECTED")).thenReturn(1);

        // When: 拒绝好友请求
        friendshipService.rejectFriendRequest(1L, 2L);

        // Then: 验证状态已更新
        verify(friendshipMapper).selectById(1L);
        verify(friendshipMapper).updateStatus(1L, "REJECTED");
    }

    @Test
    @DisplayName("场景9: 删除好友成功")
    void testDeleteFriendSuccess() {
        // Given: 好友关系存在
        when(friendshipMapper.selectById(2L)).thenReturn(acceptedFriendship);
        when(friendshipMapper.deleteById(2L)).thenReturn(1);

        // When: 删除好友（作为发起方）
        friendshipService.deleteFriend(2L, 1L);

        // Then: 验证已删除
        verify(friendshipMapper).selectById(2L);
        verify(friendshipMapper).deleteById(2L);
    }

    @Test
    @DisplayName("场景10: 删除好友失败 - 无权操作")
    void testDeleteFriendFailed_Unauthorized() {
        // Given: 好友关系存在，但当前用户不是关系中的一方
        when(friendshipMapper.selectById(2L)).thenReturn(acceptedFriendship);

        // When & Then: 尝试删除应该抛出异常
        assertThatThrownBy(() -> friendshipService.deleteFriend(2L, 999L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("无权操作此关系");

        verify(friendshipMapper, never()).deleteById(anyLong());
    }

    @Test
    @DisplayName("场景11: 获取好友列表")
    void testGetFriendList() {
        // Given: 用户有多个好友
        List<Friendship> friendships = Arrays.asList(acceptedFriendship);
        when(friendshipMapper.selectFriendsByUserId(1L)).thenReturn(friendships);
        when(userMapper.selectById(2L)).thenReturn(receiver);

        // When: 获取好友列表
        List<User> friends = friendshipService.getFriendList(1L);

        // Then: 验证结果
        assertThat(friends).isNotNull();
        assertThat(friends).hasSize(1);
        assertThat(friends.get(0).getId()).isEqualTo(2L);
        assertThat(friends.get(0).getPassword()).isNull(); // 密码已移除

        verify(friendshipMapper).selectFriendsByUserId(1L);
        verify(userMapper).selectById(2L);
    }

    @Test
    @DisplayName("场景12: 获取待处理好友请求")
    void testGetPendingRequests() {
        // Given: 有待处理的好友请求
        List<Friendship> requests = Arrays.asList(pendingFriendship);
        when(friendshipMapper.selectPendingRequestsByReceiverId(2L)).thenReturn(requests);

        // When: 获取待处理请求
        List<Friendship> result = friendshipService.getPendingRequests(2L);

        // Then: 验证结果
        assertThat(result).isNotNull();
        assertThat(result).hasSize(1);
        assertThat(result.get(0).getStatus()).isEqualTo("PENDING");

        verify(friendshipMapper).selectPendingRequestsByReceiverId(2L);
    }

    @Test
    @DisplayName("场景13: 搜索用户")
    void testSearchUsers() {
        // Given: 搜索关键词匹配多个用户
        List<User> users = Arrays.asList(requester, receiver);
        when(userMapper.searchUsers("user")).thenReturn(users);

        // When: 搜索用户（作为用户1搜索）
        List<User> result = friendshipService.searchUsers("user", 1L);

        // Then: 验证结果（应该排除自己）
        assertThat(result).isNotNull();
        assertThat(result).hasSize(1);
        assertThat(result.get(0).getId()).isEqualTo(2L);
        assertThat(result.get(0).getPassword()).isNull(); // 密码已移除

        verify(userMapper).searchUsers("user");
    }

    @Test
    @DisplayName("场景14: 检查好友关系")
    void testIsFriend() {
        // Given: 两个用户是好友
        when(friendshipMapper.selectByUsers(1L, 2L)).thenReturn(acceptedFriendship);

        // When: 检查好友关系
        boolean isFriend = friendshipService.isFriend(1L, 2L);

        // Then: 验证结果
        assertThat(isFriend).isTrue();
        verify(friendshipMapper).selectByUsers(1L, 2L);
    }

    @Test
    @DisplayName("场景15: 检查非好友关系")
    void testIsNotFriend() {
        // Given: 两个用户不是好友
        when(friendshipMapper.selectByUsers(1L, 3L)).thenReturn(null);

        // When: 检查好友关系
        boolean isFriend = friendshipService.isFriend(1L, 3L);

        // Then: 验证结果
        assertThat(isFriend).isFalse();
        verify(friendshipMapper).selectByUsers(1L, 3L);
    }

    @Test
    @DisplayName("场景16: 获取好友ID列表")
    void testGetFriendIds() {
        // Given: 用户有多个好友
        List<Long> friendIds = Arrays.asList(2L, 3L, 4L);
        when(friendshipMapper.selectFriendIdsByUserId(1L)).thenReturn(friendIds);

        // When: 获取好友ID列表
        List<Long> result = friendshipService.getFriendIds(1L);

        // Then: 验证结果
        assertThat(result).isNotNull();
        assertThat(result).hasSize(3);
        assertThat(result).containsExactly(2L, 3L, 4L);

        verify(friendshipMapper).selectFriendIdsByUserId(1L);
    }
}

