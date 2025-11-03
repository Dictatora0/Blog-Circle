<template>
  <div
    class="moment-item fade-in"
    :style="{ animationDelay: `${index * 0.05}s` }"
  >
    <div class="moment-header">
      <img
        :src="authorAvatarUrl"
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

// 处理作者头像URL（相对路径转绝对路径）
const authorAvatarUrl = computed(() => {
  let avatar = props.moment.authorAvatar || null
  if (avatar && avatar.startsWith("/")) {
    avatar = `http://localhost:8080${avatar}`
  }
  return avatar || defaultAvatar
});

const loadComments = async () => {
  try {
    const res = await getCommentsByPostId(props.moment.id);
    // 后端返回格式: { code: 200, message: "...", data: [...] }
    const responseData = res.data?.data || res.data || [];
    // 处理评论者头像URL（相对路径转绝对路径）
    comments.value = Array.isArray(responseData) ? responseData.map(comment => {
      if (comment.avatar && comment.avatar.startsWith("/")) {
        comment.avatar = `http://localhost:8080${comment.avatar}`
      }
      return comment
    }) : [];
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
  padding: var(--spacing-lg);
  margin-bottom: var(--spacing-lg);
  box-shadow: var(--shadow-card);
  transition: all var(--transition-base);
  border: 1px solid var(--border-light);
  position: relative;
  overflow: hidden;
}

.moment-item::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: var(--primary-gradient);
  opacity: 0;
  transition: opacity var(--transition-base);
}

.moment-item:hover {
  box-shadow: var(--shadow-card-hover);
  transform: translateY(-2px);
}

.moment-item:hover::before {
  opacity: 1;
}

.moment-header {
  display: flex;
  align-items: flex-start;
  gap: var(--spacing-md);
  margin-bottom: var(--spacing-lg);
  padding-bottom: var(--spacing-md);
  border-bottom: 1px solid var(--border-light);
}

.moment-info {
  flex: 1;
}

.moment-author {
  font-weight: var(--font-weight-semibold);
  color: var(--text-primary);
  margin-bottom: var(--spacing-xs);
  font-size: var(--font-size-md);
  letter-spacing: -0.01em;
}

.moment-time {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
  font-weight: var(--font-weight-normal);
}

.moment-content {
  margin-bottom: var(--spacing-md);
}

.moment-text {
  color: var(--text-primary);
  line-height: 1.75;
  white-space: pre-wrap;
  word-break: break-word;
  margin-bottom: var(--spacing-lg);
  font-size: var(--font-size-md);
  letter-spacing: 0.01em;
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
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-base);
  background: var(--bg-tertiary);
  position: relative;
}

.image-item::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(135deg, rgba(42, 183, 169, 0) 0%, rgba(26, 188, 156, 0) 100%);
  opacity: 0;
  transition: opacity var(--transition-base);
}

.image-item:hover {
  transform: scale(1.03);
  box-shadow: var(--shadow-md);
}

.image-item:hover::after {
  opacity: 0.1;
}

.image-item img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform var(--transition-base);
}

.image-item:hover img {
  transform: scale(1.05);
}

.moment-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: var(--spacing-md);
  margin-top: var(--spacing-md);
  border-top: 1px solid var(--border-light);
}

.moment-stats {
  display: flex;
  gap: var(--spacing-lg);
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
  font-weight: var(--font-weight-medium);
}

.stat-item {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  transition: color var(--transition-fast);
}

.stat-item:hover {
  color: var(--primary-color);
}

.stat-icon {
  font-size: var(--font-size-sm);
  transition: transform var(--transition-fast);
}

.stat-item:hover .stat-icon {
  transform: scale(1.1);
}

.moment-actions {
  display: flex;
  gap: var(--spacing-xs);
}

.action-btn {
  background: none;
  border: none;
  cursor: pointer;
  padding: var(--spacing-sm) var(--spacing-md);
  border-radius: var(--radius-md);
  transition: all var(--transition-base);
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}

.action-btn::before {
  content: '';
  position: absolute;
  inset: 0;
  background: var(--primary-light);
  border-radius: var(--radius-md);
  opacity: 0;
  transition: opacity var(--transition-base);
}

.action-btn:hover:not(:disabled)::before {
  opacity: 1;
}

.action-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.action-btn.active .action-icon {
  animation: heartBeat 0.5s cubic-bezier(0.4, 0, 0.2, 1);
}

.action-btn.active {
  color: var(--primary-color);
}

.action-icon {
  font-size: var(--font-size-lg);
  line-height: 1;
  position: relative;
  z-index: 1;
  transition: transform var(--transition-fast);
}

.action-btn:hover .action-icon {
  transform: scale(1.15);
}

.moment-comments {
  margin-top: var(--spacing-lg);
  padding-top: var(--spacing-lg);
  border-top: 1px solid var(--border-light);
  background: var(--bg-secondary);
  border-radius: var(--radius-md);
  padding: var(--spacing-md);
}

.comment-item {
  display: flex;
  gap: var(--spacing-md);
  margin-bottom: var(--spacing-md);
  padding: var(--spacing-md);
  border-radius: var(--radius-md);
  transition: all var(--transition-base);
  background: var(--bg-primary);
  border: 1px solid var(--border-light);
}

.comment-item:last-child {
  margin-bottom: 0;
}

.comment-item:hover {
  background: var(--bg-hover);
  border-color: var(--border-color);
  transform: translateX(4px);
  box-shadow: var(--shadow-sm);
}

.comment-content {
  flex: 1;
  min-width: 0;
}

.comment-author {
  color: var(--primary-color);
  font-weight: var(--font-weight-semibold);
  margin-right: var(--spacing-xs);
  font-size: var(--font-size-sm);
}

.comment-text {
  color: var(--text-primary);
  word-break: break-word;
  line-height: 1.6;
  font-size: var(--font-size-sm);
}

.comment-time {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
  margin-top: var(--spacing-xs);
  font-weight: var(--font-weight-normal);
}

.comment-input-wrapper {
  display: flex;
  gap: var(--spacing-md);
  align-items: flex-start;
  padding: var(--spacing-md);
  background: var(--bg-primary);
  border-radius: var(--radius-md);
  border: 1px solid var(--border-light);
  margin-top: var(--spacing-md);
}

.comment-input {
  flex: 1;
}

.comment-input :deep(.el-input__wrapper) {
  background: var(--bg-secondary);
  box-shadow: 0 0 0 1px var(--border-color) inset;
  border-radius: var(--radius-md);
  transition: all var(--transition-base);
}

.comment-input :deep(.el-input__wrapper:hover) {
  box-shadow: 0 0 0 1.5px var(--primary-color) inset;
  background: var(--bg-primary);
}

.comment-input :deep(.el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 2px var(--primary-color) inset, 0 0 0 4px var(--primary-light);
}

.btn-send {
  background: var(--primary-gradient);
  color: var(--text-white);
  border: none;
  border-radius: var(--radius-md);
  padding: var(--spacing-sm) var(--spacing-lg);
  font-size: var(--font-size-sm);
  font-weight: var(--font-weight-medium);
  cursor: pointer;
  transition: all var(--transition-base);
  white-space: nowrap;
  box-shadow: var(--shadow-sm);
}

.btn-send:hover:not(:disabled) {
  background: var(--primary-hover);
  transform: translateY(-1px);
  box-shadow: var(--shadow-md), var(--primary-glow);
}

.btn-send:active:not(:disabled) {
  transform: translateY(0);
}

.btn-send:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  transform: none;
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
