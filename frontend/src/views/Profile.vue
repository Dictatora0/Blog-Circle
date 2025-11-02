<template>
  <div class="profile-page">
    <div class="profile-header">
      <div class="cover-image">
        <div class="cover-placeholder">
          <span class="cover-icon">📷</span>
          <span class="cover-text">点击设置封面</span>
        </div>
      </div>
      
      <div class="profile-info">
        <div class="profile-avatar-wrapper">
          <img 
            :src="userInfo?.avatar || defaultAvatar" 
            :alt="userInfo?.nickname"
            class="profile-avatar"
          />
        </div>
        
        <div class="profile-details">
          <h2 class="profile-name">{{ userInfo?.nickname || userInfo?.username }}</h2>
          <div class="profile-meta">
            <span class="meta-item">📧 {{ userInfo?.email }}</span>
            <span class="meta-item">📝 {{ userMoments.length }} 条动态</span>
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
              <button class="btn-primary" @click="goToPublish">发表第一条动态</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { getMyPosts } from '@/api/post'
import MomentItem from '@/components/MomentItem.vue'

const router = useRouter()
const userStore = useUserStore()

const userMoments = ref([])
const loading = ref(false)
const defaultAvatar = 'https://via.placeholder.com/80?text=头像'

const userInfo = computed(() => userStore.userInfo)

const loadUserMoments = async () => {
  loading.value = true
  try {
    const res = await getMyPosts()
    userMoments.value = (res.data || []).map(post => ({
      ...post,
      content: post.content || post.title,
      authorName: userInfo.value?.nickname || userInfo.value?.username,
      images: [],
      liked: false,
      commentCount: post.commentCount || 0
    }))
  } catch (error) {
    console.error('加载动态失败:', error)
  } finally {
    loading.value = false
  }
}

const goToPublish = () => {
  router.push('/publish')
}

onMounted(() => {
  loadUserMoments()
})
</script>

<style scoped>
.profile-page {
  min-height: 100vh;
  background: var(--bg-secondary);
  padding-top: 80px;
}

.profile-header {
  position: relative;
  margin-bottom: var(--spacing-lg);
}

.cover-image {
  height: 320px;
  background: var(--primary-gradient);
  position: relative;
  overflow: hidden;
}

.cover-image::before {
  content: '';
  position: absolute;
  inset: 0;
  background: 
    radial-gradient(circle at 20% 50%, rgba(255, 255, 255, 0.15) 0%, transparent 50%),
    radial-gradient(circle at 80% 80%, rgba(255, 255, 255, 0.1) 0%, transparent 50%);
  pointer-events: none;
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.9);
  cursor: pointer;
  transition: all var(--transition-base);
  position: relative;
  z-index: 1;
}

.cover-placeholder:hover {
  background: rgba(0, 0, 0, 0.1);
  backdrop-filter: blur(4px);
}

.cover-placeholder:hover .cover-icon {
  transform: scale(1.1);
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

.profile-info {
  position: relative;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 var(--spacing-md);
  display: flex;
  align-items: flex-end;
  gap: var(--spacing-lg);
  margin-top: -60px;
  padding-bottom: var(--spacing-lg);
}

.profile-avatar-wrapper {
  position: relative;
}

.profile-avatar-wrapper::before {
  content: '';
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
  width: 120px;
  height: 120px;
  border-radius: var(--radius-full);
  border: 4px solid var(--bg-primary);
  object-fit: cover;
  box-shadow: var(--shadow-lg);
  transition: all var(--transition-base);
  cursor: pointer;
  position: relative;
  z-index: 1;
}

.profile-avatar-wrapper:hover .profile-avatar {
  transform: scale(1.05);
  box-shadow: var(--shadow-xl), var(--primary-glow);
}

.profile-details {
  flex: 1;
  padding-bottom: var(--spacing-md);
}

.profile-name {
  font-size: var(--font-size-2xl);
  font-weight: var(--font-weight-bold);
  color: var(--text-primary);
  margin-bottom: var(--spacing-sm);
  letter-spacing: -0.02em;
  background: var(--primary-gradient);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.profile-meta {
  display: flex;
  gap: var(--spacing-lg);
  font-size: var(--font-size-sm);
  color: var(--text-tertiary);
}

.meta-item {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
}

.profile-content {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 var(--spacing-md) var(--spacing-xl);
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
  content: '';
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

@media (max-width: 768px) {
  .cover-image {
    height: 200px;
  }
  
  .profile-info {
    flex-direction: column;
    align-items: center;
    text-align: center;
    margin-top: -80px;
  }
  
  .profile-avatar {
    width: 100px;
    height: 100px;
  }
  
  .profile-meta {
    flex-direction: column;
    gap: var(--spacing-sm);
  }
  
  .moments-section {
    padding: var(--spacing-md);
  }
}
</style>

