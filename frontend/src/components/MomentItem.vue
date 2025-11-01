<template>
  <div
    class="moment-item fade-in"
    :style="{ animationDelay: `${index * 0.05}s` }"
  >
    <div class="moment-header">
      <img
        :src="moment.authorAvatar || defaultAvatar"
        :alt="moment.authorName"
        class="avatar"
        @error="handleAvatarError"
      />
      <div class="moment-info">
        <div class="moment-author">{{ moment.authorName || "匿名用户" }}</div>
        <div class="moment-time">{{ formatTime(moment.createdAt) }}</div>
      </div>
    </div>

    <div class="moment-content">
      <p class="moment-text">{{ moment.content || moment.title }}</p>

      <!-- 图片九宫格 -->
      <div
        v-if="imageList && imageList.length > 0"
        class="moment-images"
        :class="getImageGridClass(imageList.length)"
      >
        <div
          v-for="(img, idx) in imageList"
          :key="idx"
          class="image-item"
          @click="previewImage(img, imageList, idx)"
        >
          <img
            :src="img"
            :alt="`图片${idx + 1}`"
            class="image-blur"
            @load="handleImageLoad"
          />
        </div>
      </div>
    </div>

    <div class="moment-footer">
      <div class="moment-stats">
        <span class="stat-item">
          <span class="stat-icon">👁️</span>
          {{ moment.viewCount || 0 }}
        </span>
        <span class="stat-item">
          <span class="stat-icon">💬</span>
          {{ comments.length }}
        </span>
        <span class="stat-item">
          <span class="stat-icon">❤️</span>
          {{ likeCount }}
        </span>
      </div>

      <div class="moment-actions">
        <button
          class="action-btn"
          :class="{ active: liked }"
          @click="handleLike"
          :disabled="!userStore.token"
        >
          <span class="action-icon">{{ liked ? "❤️" : "🤍" }}</span>
        </button>
        <button
          class="action-btn"
          @click="showCommentInput = !showCommentInput"
          :disabled="!userStore.token"
        >
          <span class="action-icon">💬</span>
        </button>
      </div>
    </div>

    <!-- 评论区 -->
    <div v-if="comments.length > 0 || showCommentInput" class="moment-comments">
      <div v-for="comment in comments" :key="comment.id" class="comment-item">
        <img
          :src="comment.avatar || defaultAvatar"
          :alt="comment.nickname"
          class="avatar avatar-sm"
        />
        <div class="comment-content">
          <span class="comment-author">{{
            comment.nickname || comment.username
          }}</span>
          <span class="comment-text">{{ comment.content }}</span>
          <div class="comment-time">{{ formatTime(comment.createdAt) }}</div>
        </div>
      </div>

      <!-- 评论输入框 -->
      <div
        v-if="showCommentInput && userStore.token"
        class="comment-input-wrapper"
      >
        <img
          :src="userStore.userInfo?.avatar || defaultAvatar"
          :alt="userStore.userInfo?.nickname"
          class="avatar avatar-sm"
        />
        <el-input
          v-model="commentText"
          placeholder="写评论..."
          class="comment-input"
          @keyup.enter="handleSubmitComment"
        />
        <button
          class="btn-send"
          :disabled="!commentText.trim()"
          @click="handleSubmitComment"
        >
          发送
        </button>
      </div>
    </div>

    <!-- 图片预览 -->
    <ImagePreview
      :visible="showPreview"
      @update:visible="showPreview = $event"
      :images="previewImages"
      :initial-index="previewIndex"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from "vue";
import { ElMessage } from "element-plus";
import { useUserStore } from "@/stores/user";
import { getCommentsByPostId, createComment } from "@/api/comment";
import { toggleLike } from "@/api/upload";
import ImagePreview from "./ImagePreview.vue";

const props = defineProps({
  moment: {
    type: Object,
    required: true,
  },
  index: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(["update"]);

const userStore = useUserStore();
const comments = ref([]);
const showCommentInput = ref(false);
const commentText = ref("");
const defaultAvatar = "https://via.placeholder.com/40?text=头像";
const showPreview = ref(false);
const previewImages = ref([]);
const previewIndex = ref(0);

// 本地点赞状态（避免直接修改props）
const liked = ref(props.moment.liked || false);
const likeCount = ref(props.moment.likeCount || 0);

// 监听props变化
watch(
  () => props.moment.liked,
  (newVal) => {
    liked.value = newVal || false;
  }
);
watch(
  () => props.moment.likeCount,
  (newVal) => {
    likeCount.value = newVal || 0;
  }
);

// 解析图片列表
const imageList = computed(() => {
  if (!props.moment.images) return [];
  try {
    const images =
      typeof props.moment.images === "string"
        ? JSON.parse(props.moment.images)
        : props.moment.images;
    return Array.isArray(images) ? images : [];
  } catch (e) {
    return [];
  }
});

const loadComments = async () => {
  try {
    const res = await getCommentsByPostId(props.moment.id);
    // 后端返回格式: { code: 200, message: "...", data: [...] }
    const responseData = res.data?.data || res.data || [];
    comments.value = Array.isArray(responseData) ? responseData : [];
  } catch (error) {
    console.error("加载评论失败:", error);
  }
};

const handleSubmitComment = async () => {
  if (!commentText.value.trim()) return;

  try {
    const res = await createComment({
      postId: props.moment.id,
      content: commentText.value,
    });

    // 后端返回格式: { code: 200, message: "...", data: {...} }
    if (res.data && res.data.code === 200) {
      ElMessage.success(res.data.message || "评论成功");
      commentText.value = "";
      showCommentInput.value = false;
      // 重新加载评论列表
      await loadComments();
      emit("update");
    } else {
      ElMessage.error("评论失败，请重试");
    }
  } catch (error) {
    console.error("评论失败:", error);
    const errorMsg = error.response?.data?.message || "评论失败，请重试";
    ElMessage.error(errorMsg);
  }
};

const handleLike = async () => {
  if (!userStore.token) {
    ElMessage.warning("请先登录");
    return;
  }

  try {
    const res = await toggleLike(props.moment.id);
    // 后端返回格式: { code: 200, message: "...", data: { liked: true/false, likeCount: number } }
    if (res.data && res.data.code === 200 && res.data.data) {
      liked.value = res.data.data.liked;
      likeCount.value = res.data.data.likeCount;

      // 通知父组件更新
      emit("update");
    } else {
      ElMessage.error("操作失败，请重试");
    }
  } catch (error) {
    console.error("点赞失败:", error);
    ElMessage.error("操作失败，请重试");
  }
};

const previewImage = (img, images, index) => {
  previewImages.value = images;
  previewIndex.value = index;
  showPreview.value = true;
};

const getImageGridClass = (count) => {
  if (count === 0) return "";
  if (count === 1) return "grid-1";
  if (count === 2 || count === 4) return "grid-2";
  return "grid-3";
};

const formatTime = (timeStr) => {
  if (!timeStr) return "";
  const now = new Date();
  const time = new Date(timeStr);
  const diff = now - time;
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);

  if (minutes < 1) return "刚刚";
  if (minutes < 60) return `${minutes}分钟前`;
  if (hours < 24) return `${hours}小时前`;
  if (days === 1) return "昨天";
  if (days < 7) return `${days}天前`;

  return time.toLocaleDateString("zh-CN", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
};

const handleImageLoad = (e) => {
  e.target.classList.add("loaded");
};

const handleAvatarError = (e) => {
  e.target.src = defaultAvatar;
};

onMounted(() => {
  loadComments();
});
</script>

<style scoped>
.moment-item {
  background: var(--bg-primary);
  border-radius: var(--radius-md);
  padding: var(--spacing-md);
  margin-bottom: var(--spacing-md);
  box-shadow: var(--shadow-sm);
  transition: all 0.2s;
}

.moment-item:hover {
  box-shadow: var(--shadow-md);
}

.moment-header {
  display: flex;
  align-items: flex-start;
  gap: var(--spacing-md);
  margin-bottom: var(--spacing-md);
}

.moment-info {
  flex: 1;
}

.moment-author {
  font-weight: 500;
  color: var(--text-primary);
  margin-bottom: var(--spacing-xs);
}

.moment-time {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
}

.moment-content {
  margin-bottom: var(--spacing-md);
}

.moment-text {
  color: var(--text-primary);
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
  margin-bottom: var(--spacing-md);
}

.moment-images {
  display: grid;
  gap: var(--spacing-xs);
  margin-top: var(--spacing-md);
}

.grid-1 {
  grid-template-columns: 1fr;
  max-width: 300px;
}

.grid-2 {
  grid-template-columns: repeat(2, 1fr);
}

.grid-3 {
  grid-template-columns: repeat(3, 1fr);
}

.image-item {
  aspect-ratio: 1;
  overflow: hidden;
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: transform 0.2s;
}

.image-item:hover {
  transform: scale(1.02);
}

.image-item img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.moment-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: var(--spacing-sm);
  border-top: 1px solid var(--border-light);
}

.moment-stats {
  display: flex;
  gap: var(--spacing-md);
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
}

.stat-item {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
}

.stat-icon {
  font-size: var(--font-size-sm);
}

.moment-actions {
  display: flex;
  gap: var(--spacing-sm);
}

.action-btn {
  background: none;
  border: none;
  cursor: pointer;
  padding: var(--spacing-xs);
  border-radius: var(--radius-sm);
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-btn:hover:not(:disabled) {
  background: var(--bg-hover);
}

.action-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.action-btn.active {
  color: var(--primary-color);
}

.action-icon {
  font-size: var(--font-size-lg);
  line-height: 1;
}

.moment-comments {
  margin-top: var(--spacing-md);
  padding-top: var(--spacing-md);
  border-top: 1px solid var(--border-light);
}

.comment-item {
  display: flex;
  gap: var(--spacing-sm);
  margin-bottom: var(--spacing-md);
  padding: var(--spacing-sm);
  border-radius: var(--radius-sm);
  transition: background 0.2s;
}

.comment-item:hover {
  background: var(--bg-hover);
}

.comment-content {
  flex: 1;
}

.comment-author {
  color: var(--text-secondary);
  font-weight: 500;
  margin-right: var(--spacing-xs);
}

.comment-text {
  color: var(--text-primary);
  word-break: break-word;
}

.comment-time {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
  margin-top: var(--spacing-xs);
}

.comment-input-wrapper {
  display: flex;
  gap: var(--spacing-sm);
  align-items: flex-start;
  padding: var(--spacing-sm);
  background: var(--bg-secondary);
  border-radius: var(--radius-md);
}

.comment-input {
  flex: 1;
}

.comment-input :deep(.el-input__wrapper) {
  background: var(--bg-primary);
  box-shadow: none;
}

.btn-send {
  background: var(--primary-color);
  color: white;
  border: none;
  border-radius: var(--radius-md);
  padding: var(--spacing-xs) var(--spacing-md);
  font-size: var(--font-size-sm);
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.btn-send:hover:not(:disabled) {
  background: var(--primary-hover);
}

.btn-send:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .grid-3 {
    grid-template-columns: repeat(2, 1fr);
  }

  .moment-text {
    font-size: var(--font-size-sm);
  }
}
</style>
