<template>
  <div class="profile-page">
    <div class="profile-header">
      <!-- 封面图片区域 -->
      <div class="cover-image" :style="coverStyle" @click="triggerCoverUpload">
        <!-- 隐藏的文件上传input -->
        <input
          ref="coverInput"
          type="file"
          accept="image/*"
          style="display: none"
          @change="handleCoverUpload"
          @click.stop
        />

        <!-- 上传提示（仅在无封面或hover时显示） -->
        <div class="cover-overlay" :class="{ 'has-cover': hasCover }">
          <span class="cover-icon">📷</span>
          <span class="cover-text">{{
            hasCover ? "更换封面" : "点击设置封面"
          }}</span>
        </div>

        <!-- 上传loading -->
        <div v-if="coverUploading" class="cover-loading">
          <div class="loading-spinner"></div>
          <span class="loading-text">上传中...</span>
        </div>
      </div>

      <div class="profile-info">
        <div class="profile-avatar-wrapper" @click="triggerAvatarUpload">
          <!-- 隐藏的文件上传input -->
          <input
            ref="avatarInput"
            type="file"
            accept="image/*"
            style="display: none"
            @change="handleAvatarUpload"
            @click.stop
          />

          <img
            :src="avatarUrl || userInfo?.avatar || defaultAvatar"
            :alt="userInfo?.nickname"
            class="profile-avatar"
            :class="{ uploading: avatarUploading }"
          />

          <!-- 上传提示遮罩 -->
          <div
            class="avatar-overlay"
            :class="{ 'has-avatar': avatarUrl || userInfo?.avatar }"
          >
            <span class="avatar-icon">📷</span>
            <span class="avatar-text">{{
              avatarUrl || userInfo?.avatar ? "更换头像" : "点击上传"
            }}</span>
          </div>

          <!-- 上传loading -->
          <div v-if="avatarUploading" class="avatar-loading">
            <div class="loading-spinner-small"></div>
          </div>
        </div>

        <div class="profile-details">
          <h2 class="profile-name">
            {{ userInfo?.nickname || userInfo?.username }}
          </h2>
          <div class="profile-meta">
            <span class="meta-item">
              <span class="meta-icon">📧</span>
              <span class="meta-text">{{ userInfo?.email }}</span>
            </span>
            <span class="meta-item">
              <span class="meta-icon">📝</span>
              <span class="meta-text">{{ userMoments.length }} 条动态</span>
            </span>
          </div>
        </div>
      </div>
    </div>

    <div class="profile-content">
      <div class="content-container">
        <div class="moments-section">
          <div class="section-header">
            <h3>我的动态</h3>
          </div>

          <div class="moments-list">
            <div
              v-for="(moment, index) in userMoments"
              :key="moment.id"
              class="moment-wrapper"
            >
              <MomentItem
                :moment="moment"
                :index="index"
                @update="loadUserMoments"
              />
            </div>

            <div v-if="userMoments.length === 0" class="empty-state">
              <div class="empty-icon">📝</div>
              <div class="empty-text">还没有发表动态</div>
              <button class="btn-primary" @click="goToPublish">
                发表第一条动态
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { useRouter } from "vue-router";
import { useUserStore } from "@/stores/user";
import { getMyPosts } from "@/api/post";
import { uploadImage } from "@/api/upload";
import { updateUser, getCurrentUser } from "@/api/auth";
import { ElMessage } from "element-plus";
import MomentItem from "@/components/MomentItem.vue";
import { getResourceUrl } from "@/config";

const router = useRouter();
const userStore = useUserStore();

const userMoments = ref([]);
const loading = ref(false);
const coverUploading = ref(false);
const coverInput = ref(null);
const coverUrl = ref("");
const avatarUploading = ref(false);
const avatarInput = ref(null);
const avatarUrl = ref("");
const defaultAvatar = "https://via.placeholder.com/80?text=头像";

const userInfo = computed(() => userStore.userInfo);

// 是否有封面
const hasCover = computed(() => !!coverUrl.value);

// 封面样式
const coverStyle = computed(() => {
  if (coverUrl.value) {
    return {
      backgroundImage: `url(${coverUrl.value})`,
      backgroundSize: "cover",
      backgroundPosition: "center",
    };
  }
  return {};
});

// 触发封面上传
const triggerCoverUpload = (event) => {
  if (coverUploading.value) return;
  // 阻止事件冒泡，防止递归
  if (event) {
    event.stopPropagation();
  }
  coverInput.value?.click();
};

// 触发头像上传
const triggerAvatarUpload = (event) => {
  if (avatarUploading.value) return;
  // 阻止事件冒泡，防止递归
  if (event) {
    event.stopPropagation();
  }
  avatarInput.value?.click();
};

// 处理封面上传
const handleCoverUpload = async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;

  // 验证文件类型
  if (!file.type.startsWith("image/")) {
    ElMessage.error("请选择图片文件");
    return;
  }

  // 验证文件大小（最大5MB）
  if (file.size > 5 * 1024 * 1024) {
    ElMessage.error("图片大小不能超过5MB");
    return;
  }

  try {
    coverUploading.value = true;

    // 1. 先显示本地预览
    const reader = new FileReader();
    reader.onload = (e) => {
      coverUrl.value = e.target.result;
    };
    reader.readAsDataURL(file);

    // 2. 上传到服务器
    const uploadRes = await uploadImage(file);
    console.log("上传响应:", uploadRes);

    // 后端返回格式: {code: 200, message: "上传成功", data: {url: "...", filename: "..."}}
    let uploadedUrl = uploadRes.data?.data?.url || uploadRes.data?.url;

    if (!uploadedUrl) {
      throw new Error("上传失败：未获取到图片URL");
    }

    // 如果返回的是相对路径，转换为完整URL
    if (uploadedUrl.startsWith("/")) {
      uploadedUrl = getResourceUrl(uploadedUrl);
    }

    // 3. 更新用户信息
    console.log(
      "更新用户信息，userId:",
      userInfo.value.id,
      "coverImage:",
      uploadedUrl
    );
    await updateUser(userInfo.value.id, {
      coverImage: uploadedUrl,
    });

    // 4. 更新本地状态
    coverUrl.value = uploadedUrl;

    // 5. 刷新用户信息
    const userRes = await getCurrentUser();
    console.log("获取当前用户响应:", userRes);
    if (userRes.data?.data) {
      userStore.setUserInfo(userRes.data.data);
      // 更新封面URL
      if (userRes.data.data.coverImage) {
        coverUrl.value = userRes.data.data.coverImage;
      }
    } else if (userRes.data) {
      userStore.setUserInfo(userRes.data);
      if (userRes.data.coverImage) {
        coverUrl.value = userRes.data.coverImage;
      }
    }

    ElMessage.success("封面上传成功");
  } catch (error) {
    console.error("封面上传失败:", error);
    ElMessage.error(error.response?.data?.message || "封面上传失败，请重试");
    // 恢复为之前的封面或默认
    coverUrl.value = userInfo.value?.coverImage || "";
  } finally {
    coverUploading.value = false;
    // 清空input，允许重复选择同一文件
    if (coverInput.value) {
      coverInput.value.value = "";
    }
  }
};

// 处理头像上传
const handleAvatarUpload = async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;

  // 验证文件类型
  if (!file.type.startsWith("image/")) {
    ElMessage.error("请选择图片文件");
    return;
  }

  // 验证文件大小（最大5MB）
  if (file.size > 5 * 1024 * 1024) {
    ElMessage.error("图片大小不能超过5MB");
    return;
  }

  try {
    avatarUploading.value = true;

    // 1. 先显示本地预览
    const reader = new FileReader();
    reader.onload = (e) => {
      avatarUrl.value = e.target.result;
    };
    reader.readAsDataURL(file);

    // 2. 上传到服务器
    const uploadRes = await uploadImage(file);
    console.log("头像上传响应:", uploadRes);

    // 后端返回格式: {code: 200, message: "上传成功", data: {url: "...", filename: "..."}}
    let uploadedUrl = uploadRes.data?.data?.url || uploadRes.data?.url;

    if (!uploadedUrl) {
      throw new Error("上传失败：未获取到图片URL");
    }

    // 如果返回的是相对路径，转换为完整URL
    if (uploadedUrl.startsWith("/")) {
      uploadedUrl = getResourceUrl(uploadedUrl);
    }

    // 3. 更新用户信息
    console.log(
      "更新用户头像，userId:",
      userInfo.value.id,
      "avatar:",
      uploadedUrl
    );
    await updateUser(userInfo.value.id, {
      avatar: uploadedUrl,
    });

    // 4. 更新本地状态
    avatarUrl.value = uploadedUrl;

    // 5. 刷新用户信息
    const userRes = await getCurrentUser();
    console.log("获取当前用户响应:", userRes);
    if (userRes.data?.data) {
      userStore.setUserInfo(userRes.data.data);
      // 更新头像URL
      if (userRes.data.data.avatar) {
        avatarUrl.value = userRes.data.data.avatar;
      }
    } else if (userRes.data) {
      userStore.setUserInfo(userRes.data);
      if (userRes.data.avatar) {
        avatarUrl.value = userRes.data.avatar;
      }
    }

    ElMessage.success("头像上传成功");
  } catch (error) {
    console.error("头像上传失败:", error);
    ElMessage.error(error.response?.data?.message || "头像上传失败，请重试");
    // 恢复为之前的头像或默认
    avatarUrl.value = userInfo.value?.avatar || "";
  } finally {
    avatarUploading.value = false;
    // 清空input，允许重复选择同一文件
    if (avatarInput.value) {
      avatarInput.value.value = "";
    }
  }
};

// 加载用户动态
const loadUserMoments = async () => {
  loading.value = true;
  try {
    const res = await getMyPosts();
    console.log("获取我的动态响应:", res);

    // 后端返回格式: {code: 200, message: "操作成功", data: [...]}
    const posts = res.data?.data || res.data || [];

    userMoments.value = posts.map((post) => {
      // 处理作者头像URL（相对路径转绝对路径）
      let authorAvatar = post.authorAvatar || null
      if (authorAvatar && authorAvatar.startsWith("/")) {
        authorAvatar = getResourceUrl(authorAvatar)
      }
      
      // 处理图片列表
      let images = [];
      if (post.images) {
        if (typeof post.images === "string") {
          try {
            images = JSON.parse(post.images);
          } catch (e) {
            console.warn("解析图片数据失败:", e);
            images = [];
          }
        } else {
          images = post.images;
        }
      }

      return {
        ...post,
        content: post.content || post.title,
        authorName: post.authorName || userInfo.value?.nickname || userInfo.value?.username,
        authorAvatar, // 使用后端返回的头像，或从用户信息获取
        images,
        liked: post.liked || false,
        commentCount: post.commentCount || 0,
      };
    });

    console.log("加载到的动态数量:", userMoments.value.length);
    console.log("动态数据:", userMoments.value);
  } catch (error) {
    console.error("加载动态失败:", error);
    console.error("错误详情:", error.response?.data || error.message);
    ElMessage.error(error.response?.data?.message || "加载动态失败");
  } finally {
    loading.value = false;
  }
};

const goToPublish = () => {
  router.push("/publish");
};

onMounted(async () => {
  // 加载封面 - 支持 coverImage 和 cover_image 两种字段名
  const cover = userInfo.value?.coverImage || userInfo.value?.cover_image;
  if (cover) {
    // 如果是相对路径，转换为完整URL
    if (cover.startsWith("/")) {
      coverUrl.value = getResourceUrl(cover);
    } else {
      coverUrl.value = cover;
    }
  }

  // 加载头像 - 支持 avatar 字段
  const avatar = userInfo.value?.avatar;
  if (avatar) {
    // 如果是相对路径，转换为完整URL
    if (avatar.startsWith("/")) {
      avatarUrl.value = getResourceUrl(avatar);
    } else {
      avatarUrl.value = avatar;
    }
  }

  // 加载动态
  await loadUserMoments();
});
</script>

<style scoped>
.profile-page {
  min-height: 100vh;
  background: var(--bg-secondary);
  padding-top: 80px;
}

.profile-header {
  position: relative;
  margin-bottom: 0;
  background: var(--bg-primary);
}

.cover-image {
  height: 320px;
  background: var(--primary-gradient);
  position: relative;
  overflow: hidden;
  cursor: pointer;
  transition: all var(--transition-base);
}

.cover-image::before {
  content: "";
  position: absolute;
  inset: 0;
  background: radial-gradient(
      circle at 20% 50%,
      rgba(255, 255, 255, 0.15) 0%,
      transparent 50%
    ),
    radial-gradient(
      circle at 80% 80%,
      rgba(255, 255, 255, 0.1) 0%,
      transparent 50%
    );
  pointer-events: none;
}

/* 封面遮罩层 */
.cover-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.95);
  background: rgba(0, 0, 0, 0.1);
  opacity: 1;
  transition: all var(--transition-base);
  z-index: 1;
}

.cover-overlay.has-cover {
  opacity: 0;
}

.cover-image:hover .cover-overlay {
  opacity: 1;
  background: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(8px);
}

.cover-image:hover .cover-overlay .cover-icon {
  transform: scale(1.15);
}

.cover-icon {
  font-size: 56px;
  margin-bottom: var(--spacing-sm);
  transition: transform var(--transition-base);
  filter: drop-shadow(0 2px 8px rgba(0, 0, 0, 0.2));
}

.cover-text {
  font-size: var(--font-size-md);
  font-weight: var(--font-weight-medium);
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
}

/* 封面上传loading */
.cover-loading {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.75);
  backdrop-filter: blur(10px);
  z-index: 10;
  color: #fff;
}

.loading-spinner {
  width: 48px;
  height: 48px;
  border: 4px solid rgba(255, 255, 255, 0.2);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  margin-bottom: var(--spacing-md);
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.loading-text {
  font-size: var(--font-size-md);
  font-weight: var(--font-weight-medium);
}

.profile-info {
  position: relative;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 var(--spacing-md);
  display: flex;
  align-items: flex-end;
  gap: var(--spacing-lg);
  margin-top: -80px;
  padding-bottom: var(--spacing-xl);
  z-index: 2;
}

.profile-avatar-wrapper {
  position: relative;
  flex-shrink: 0;
  cursor: pointer;
}

.profile-avatar-wrapper::before {
  content: "";
  position: absolute;
  inset: -4px;
  background: var(--primary-gradient);
  border-radius: var(--radius-full);
  opacity: 0;
  transition: opacity var(--transition-base);
  z-index: -1;
}

.profile-avatar-wrapper:hover::before {
  opacity: 1;
}

.profile-avatar {
  width: 140px;
  height: 140px;
  border-radius: var(--radius-full);
  border: 5px solid var(--bg-primary);
  object-fit: cover;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  transition: all var(--transition-base);
  cursor: pointer;
  position: relative;
  z-index: 1;
  background: var(--bg-primary);
  display: block;
}

.profile-avatar.uploading {
  opacity: 0.6;
}

.profile-avatar-wrapper:hover .profile-avatar {
  transform: scale(1.02);
  box-shadow: 0 6px 30px rgba(0, 0, 0, 0.2);
}

/* 头像上传遮罩层 */
.avatar-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.5);
  border-radius: var(--radius-full);
  color: #fff;
  opacity: 0;
  transition: all var(--transition-base);
  z-index: 2;
  pointer-events: none;
}

.avatar-overlay.has-avatar {
  opacity: 0;
}

.profile-avatar-wrapper:hover .avatar-overlay {
  opacity: 1;
}

.avatar-icon {
  font-size: 32px;
  margin-bottom: 4px;
  transition: transform var(--transition-base);
}

.profile-avatar-wrapper:hover .avatar-overlay .avatar-icon {
  transform: scale(1.1);
}

.avatar-text {
  font-size: 12px;
  font-weight: 500;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
}

/* 头像上传loading */
.avatar-loading {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.6);
  border-radius: var(--radius-full);
  z-index: 3;
}

.loading-spinner-small {
  width: 32px;
  height: 32px;
  border: 3px solid rgba(255, 255, 255, 0.2);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

.profile-details {
  flex: 1;
  padding-bottom: var(--spacing-md);
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
}

.profile-name {
  font-size: 32px;
  font-weight: 700;
  color: var(--text-primary);
  letter-spacing: -0.02em;
  margin: 0;
  line-height: 1.2;
}

/* 优化邮箱和动态统计样式 - 更简洁统一 */
.profile-meta {
  display: flex;
  align-items: center;
  gap: var(--spacing-lg);
  font-size: 15px;
  color: var(--text-secondary);
  flex-wrap: wrap;
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--text-secondary);
  font-weight: 400;
  white-space: nowrap;
}

.meta-icon {
  font-size: 16px;
  opacity: 0.8;
}

.meta-text {
  color: var(--text-secondary);
  font-size: 15px;
}

.profile-content {
  max-width: 1200px;
  margin: 0 auto;
  padding: var(--spacing-xl) var(--spacing-md);
  background: var(--bg-secondary);
}

.content-container {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--spacing-lg);
}

.moments-section {
  background: var(--bg-primary);
  border-radius: var(--radius-lg);
  padding: var(--spacing-xl);
  box-shadow: var(--shadow-card);
  border: 1px solid var(--border-light);
  transition: all var(--transition-base);
}

.moments-section:hover {
  box-shadow: var(--shadow-card-hover);
}

.section-header {
  margin-bottom: var(--spacing-xl);
  padding-bottom: var(--spacing-lg);
  border-bottom: 2px solid var(--border-light);
  position: relative;
}

.section-header::after {
  content: "";
  position: absolute;
  bottom: -2px;
  left: 0;
  width: 60px;
  height: 2px;
  background: var(--primary-gradient);
  border-radius: var(--radius-full);
}

.section-header h3 {
  font-size: var(--font-size-xl);
  font-weight: var(--font-weight-bold);
  color: var(--text-primary);
  letter-spacing: -0.01em;
}

.moments-list {
  display: flex;
  flex-direction: column;
}

.empty-state {
  text-align: center;
  padding: var(--spacing-xl) var(--spacing-md);
}

.empty-icon {
  font-size: 64px;
  margin-bottom: var(--spacing-md);
  opacity: 0.5;
}

.empty-text {
  font-size: var(--font-size-md);
  color: var(--text-tertiary);
  margin-bottom: var(--spacing-lg);
}

/* 响应式设计 */
@media (max-width: 768px) {
  .cover-image {
    height: 200px;
  }

  .cover-icon {
    font-size: 40px;
  }

  .cover-text {
    font-size: var(--font-size-sm);
  }

  .profile-info {
    flex-direction: column;
    align-items: center;
    text-align: center;
    margin-top: -70px;
    gap: var(--spacing-md);
  }

  .profile-avatar {
    width: 120px;
    height: 120px;
    border-width: 4px;
  }

  .profile-details {
    align-items: center;
    width: 100%;
  }

  .profile-name {
    font-size: 24px;
    text-align: center;
  }

  .profile-meta {
    justify-content: center;
    gap: var(--spacing-md);
    font-size: 14px;
  }

  .meta-item {
    justify-content: center;
  }

  .moments-section {
    padding: var(--spacing-md);
  }
}
</style>
