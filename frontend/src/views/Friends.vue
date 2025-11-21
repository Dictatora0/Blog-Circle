<template>
  <div class="friends-page">
    <div class="page-header">
      <h1>好友管理</h1>
    </div>

    <!-- 搜索栏 -->
    <div class="search-section">
      <h2>🔍 搜索用户</h2>
      <div class="search-box">
        <input
          v-model="searchKeyword"
          type="text"
          placeholder="输入用户名、邮箱或昵称搜索..."
          @keyup.enter="handleSearch"
          class="search-input"
        />
        <button @click="handleSearch" class="search-btn">搜索</button>
      </div>

      <div v-if="searchResults.length > 0" class="search-results">
        <FriendCard v-for="user in searchResults" :key="user.id" :friend="user">
          <template #actions>
            <button
              @click="handleSendRequest(user.id)"
              class="btn-primary"
              :disabled="requestingSending"
            >
              添加好友
            </button>
          </template>
        </FriendCard>
      </div>
      <div v-else-if="searchKeyword && searched" class="empty-state">
        未找到相关用户
      </div>
    </div>

    <!-- 好友请求 -->
    <div class="requests-section" v-if="pendingRequests.length > 0">
      <h2>⏳ 好友请求</h2>
      <FriendCard
        v-for="request in pendingRequests"
        :key="request.id"
        :friend="getRequesterInfo(request)"
      >
        <template #actions>
          <button
            @click="handleAcceptRequest(request.id)"
            class="btn-success"
            :disabled="processing"
          >
            同意
          </button>
          <button
            @click="handleRejectRequest(request.id)"
            class="btn-danger"
            :disabled="processing"
          >
            拒绝
          </button>
        </template>
      </FriendCard>
    </div>

    <!-- 好友列表 -->
    <div class="friends-section">
      <h2>我的好友 ({{ friendList.length }})</h2>
      <div v-if="loading" class="loading">加载中...</div>
      <div v-else-if="friendList.length === 0" class="empty-state">
        暂无好友，快去添加吧！
      </div>
      <div v-else>
        <FriendCard
          v-for="friend in friendList"
          :key="friend.id"
          :friend="friend"
        >
          <template #actions>
            <button
              @click="handleDeleteFriend(friend.id)"
              class="btn-danger-outline"
              :disabled="deleting"
            >
              删除
            </button>
          </template>
        </FriendCard>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import FriendCard from "@/components/FriendCard.vue";
import {
  getFriendList,
  getPendingRequests,
  searchUsers,
  sendFriendRequest,
  acceptFriendRequest,
  rejectFriendRequest,
  deleteFriend,
} from "@/api/friends";

const friendList = ref([]);
const pendingRequests = ref([]);
const searchKeyword = ref("");
const searchResults = ref([]);
const searched = ref(false);
const loading = ref(false);
const processing = ref(false);
const deleting = ref(false);
const requestingSending = ref(false);

onMounted(() => {
  loadFriendList();
  loadPendingRequests();
});

const loadFriendList = async () => {
  try {
    loading.value = true;
    const res = await getFriendList();
    // 处理响应数据：axios返回的response对象，业务数据在res.data中
    // res.data是{code, message, data}，真正的数据在res.data.data
    const responseBody = res.data || res;
    if (responseBody.code === 200) {
      friendList.value = responseBody.data || [];
    }
  } catch (error) {
    console.error("加载好友列表失败:", error);
    ElMessage.error("加载好友列表失败");
  } finally {
    loading.value = false;
  }
};

const loadPendingRequests = async () => {
  try {
    const res = await getPendingRequests();
    // 处理响应数据：axios返回的response对象，业务数据在res.data中
    // res.data是{code, message, data}，真正的数据在res.data.data
    const responseBody = res.data || res;
    if (responseBody.code === 200) {
      pendingRequests.value = responseBody.data || [];
    }
  } catch (error) {
    console.error("加载好友请求失败:", error);
  }
};

const handleSearch = async () => {
  if (!searchKeyword.value.trim()) {
    ElMessage.warning("请输入搜索关键词");
    return;
  }

  try {
    const res = await searchUsers(searchKeyword.value);
    // 处理响应数据：axios返回的response对象，业务数据在res.data中
    // res.data是{code, message, data}，真正的数据在res.data.data
    const responseBody = res.data || res;
    if (responseBody.code === 200) {
      searchResults.value = responseBody.data || [];
      searched.value = true;
    } else {
      ElMessage.error(responseBody.message || "搜索失败");
    }
  } catch (error) {
    console.error("搜索用户失败:", error);
    ElMessage.error("搜索失败");
  }
};

const handleSendRequest = async (receiverId) => {
  try {
    requestingSending.value = true;
    const res = await sendFriendRequest(receiverId);
    // 处理响应数据：axios返回的response对象，业务数据在res.data中
    // res.data是{code, message, data}，真正的数据在res.data.data
    const responseBody = res.data || res;
    if (responseBody.code === 200) {
      ElMessage.success("好友请求已发送");
      // 从搜索结果中移除该用户
      searchResults.value = searchResults.value.filter(
        (u) => u.id !== receiverId
      );
    } else {
      ElMessage.error(responseBody.message || "发送请求失败");
    }
  } catch (error) {
    console.error("发送好友请求失败:", error);
    // 打印更详细的错误信息
    if (error.response?.data) {
      console.error("错误详情:", error.response.data);
      ElMessage.error(error.response.data.message || "发送请求失败");
    } else {
      ElMessage.error("发送请求失败");
    }
  } finally {
    requestingSending.value = false;
  }
};

const handleAcceptRequest = async (requestId) => {
  try {
    processing.value = true;
    const res = await acceptFriendRequest(requestId);
    // 处理响应数据：axios返回的response对象，业务数据在res.data中
    const responseBody = res.data || res;
    if (responseBody.code === 200) {
      ElMessage.success("已接受好友请求");
      loadPendingRequests();
      loadFriendList();
    } else {
      ElMessage.error(responseBody.message || "操作失败");
    }
  } catch (error) {
    console.error("接受好友请求失败:", error);
    if (error.response?.data) {
      ElMessage.error(error.response.data.message || "操作失败");
    } else {
      ElMessage.error("操作失败");
    }
  } finally {
    processing.value = false;
  }
};

const handleRejectRequest = async (requestId) => {
  try {
    processing.value = true;
    const res = await rejectFriendRequest(requestId);
    // 处理响应数据：axios返回的response对象，业务数据在res.data中
    const responseBody = res.data || res;
    if (responseBody.code === 200) {
      ElMessage.success("已拒绝好友请求");
      loadPendingRequests();
    } else {
      ElMessage.error(responseBody.message || "操作失败");
    }
  } catch (error) {
    console.error("拒绝好友请求失败:", error);
    if (error.response?.data) {
      ElMessage.error(error.response.data.message || "操作失败");
    } else {
      ElMessage.error("操作失败");
    }
  } finally {
    processing.value = false;
  }
};

const handleDeleteFriend = async (friendId) => {
  try {
    await ElMessageBox.confirm("确定要删除该好友吗？", "提示", {
      confirmButtonText: "确定",
      cancelButtonText: "取消",
      type: "warning",
    });

    deleting.value = true;
    const res = await deleteFriend(friendId);
    // 处理响应数据：axios返回的response对象，业务数据在res.data中
    const responseBody = res.data || res;
    if (responseBody.code === 200) {
      ElMessage.success("已删除好友");
      loadFriendList();
    } else {
      ElMessage.error(responseBody.message || "删除失败");
    }
  } catch (error) {
    if (error !== "cancel") {
      console.error("删除好友失败:", error);
      ElMessage.error("删除失败");
    }
  } finally {
    deleting.value = false;
  }
};

const getRequesterInfo = (request) => {
  return {
    id: request.requesterId,
    nickname: request.requester?.nickname,
    username: request.requester?.username,
    email: request.requester?.email,
    avatar: request.requester?.avatar,
  };
};
</script>

<style scoped>
.friends-page {
  max-width: 800px;
  margin: 0 auto;
  padding: 24px;
}

.page-header {
  margin-bottom: 32px;
}

.page-header h1 {
  font-size: 28px;
  font-weight: 700;
  color: #333;
}

.search-section,
.requests-section,
.friends-section {
  margin-bottom: 32px;
  padding: 20px;
  background: #f8f9fa;
  border-radius: 16px;
}

h2 {
  font-size: 18px;
  font-weight: 600;
  color: #333;
  margin-bottom: 16px;
}

.search-box {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
}

.search-input {
  flex: 1;
  padding: 12px 16px;
  border: 2px solid #e8e8e8;
  border-radius: 8px;
  font-size: 14px;
  transition: all 0.3s ease;
}

.search-input:focus {
  outline: none;
  border-color: #409eff;
}

.search-btn {
  padding: 12px 24px;
  background: #409eff;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.3s ease;
}

.search-btn:hover {
  background: #66b1ff;
}

.search-btn:active {
  transform: scale(0.98);
}

.search-results {
  margin-top: 16px;
}

.btn-primary,
.btn-success,
.btn-danger,
.btn-danger-outline {
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.3s ease;
}

.btn-primary {
  background: #409eff;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #66b1ff;
}

.btn-success {
  background: #67c23a;
  color: white;
}

.btn-success:hover:not(:disabled) {
  background: #85ce61;
}

.btn-danger {
  background: #f56c6c;
  color: white;
}

.btn-danger:hover:not(:disabled) {
  background: #f78989;
}

.btn-danger-outline {
  background: transparent;
  color: #f56c6c;
  border: 1px solid #f56c6c;
}

.btn-danger-outline:hover:not(:disabled) {
  background: #f56c6c;
  color: white;
}

button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.empty-state {
  text-align: center;
  padding: 40px 20px;
  color: #999;
  font-size: 14px;
}

.loading {
  text-align: center;
  padding: 40px 20px;
  color: #999;
  font-size: 14px;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .friends-page {
    padding: 16px;
  }

  .page-header h1 {
    font-size: 24px;
  }

  .search-section,
  .requests-section,
  .friends-section {
    padding: 16px;
    border-radius: 12px;
  }

  .search-box {
    flex-direction: column;
  }

  .search-btn {
    width: 100%;
  }
}
</style>
