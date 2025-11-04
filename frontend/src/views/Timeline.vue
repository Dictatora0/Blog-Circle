<template>
  <div class="timeline-page">
    <!-- 下拉刷新提示 -->
    <div v-if="refreshing" class="refresh-indicator">
      <span class="refresh-icon">🔄</span>
      <span>刷新中...</span>
    </div>
    
    <div class="page-container">
      <div class="page-header">
        <h1>好友动态</h1>
        <p class="subtitle">查看你和好友的最新动态</p>
      </div>

      <div class="moments-list">
        <div 
          v-for="(moment, index) in moments" 
          :key="moment.id"
          class="moment-wrapper"
        >
          <MomentItem 
            :moment="moment" 
            :index="index"
            @update="loadTimeline"
          />
        </div>
        
        <div v-if="loading" class="loading-more">
          <span>加载中...</span>
        </div>
        
        <div v-if="!loading && moments.length === 0" class="empty-state">
          <div class="empty-icon">👥</div>
          <div class="empty-text">还没有好友动态</div>
          <div class="empty-hint">快去添加好友吧~</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, onActivated, watch } from 'vue'
import { getFriendTimeline } from '@/api/friends'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'
import MomentItem from '@/components/MomentItem.vue'
import { getResourceUrl } from '@/config'

const userStore = useUserStore()
const moments = ref([])
const loading = ref(false)
const refreshing = ref(false)

let touchStartY = 0
let touchEndY = 0

const loadTimeline = async (reset = false) => {
  if (loading.value) return
  
  loading.value = true
  try {
    const res = await getFriendTimeline()
    // 处理响应数据：res.data是{code, message, data}，真正的数据在res.data.data
    const responseData = res.data?.data || res.data || []
    const newMoments = Array.isArray(responseData) ? responseData : []
    
    const processedMoments = newMoments.map(post => {
      // 处理作者头像URL（相对路径转绝对路径）
      let authorAvatar = post.authorAvatar || null
      if (authorAvatar && authorAvatar.startsWith("/")) {
        authorAvatar = getResourceUrl(authorAvatar)
      }
      
      // 处理图片列表
      let images = post.images || null
      if (images && typeof images === "string") {
        try {
          images = JSON.parse(images)
        } catch (e) {
          console.warn("解析图片数据失败:", e)
          images = []
        }
      }
      
      return {
        ...post,
        content: post.content || post.title,
        authorAvatar, // 处理后的头像URL
        images,
        liked: post.liked || false,
        likeCount: post.likeCount || 0,
        commentCount: post.commentCount || 0
      }
    })
    
    moments.value = processedMoments
  } catch (error) {
    console.error('加载好友动态失败:', error)
    ElMessage.error('加载好友动态失败')
  } finally {
    loading.value = false
  }
}

const handleRefresh = async () => {
  refreshing.value = true
  await loadTimeline(true)
  refreshing.value = false
  ElMessage.success('刷新成功')
}

// 下拉刷新
const handleTouchStart = (e) => {
  touchStartY = e.touches[0].clientY
}

const handleTouchMove = (e) => {
  touchEndY = e.touches[0].clientY
}

const handleTouchEnd = () => {
  const scrollTop = window.pageYOffset || document.documentElement.scrollTop
  if (scrollTop === 0 && touchEndY - touchStartY > 100) {
    handleRefresh()
  }
}

onMounted(() => {
  loadTimeline()
  
  // 添加触摸事件监听
  document.addEventListener('touchstart', handleTouchStart)
  document.addEventListener('touchmove', handleTouchMove)
  document.addEventListener('touchend', handleTouchEnd)
})

// 页面激活时刷新数据（从其他页面返回时，确保头像等信息最新）
onActivated(() => {
  console.log('Timeline页面激活，刷新好友动态列表')
  loadTimeline(true)
})

// 监听用户头像变化
watch(() => userStore.userInfo?.avatar, (newAvatar, oldAvatar) => {
  if (newAvatar !== oldAvatar && oldAvatar !== undefined) {
    console.log('检测到头像更新，刷新好友动态列表')
    loadTimeline(true)
  }
})

onUnmounted(() => {
  // 移除触摸事件监听
  document.removeEventListener('touchstart', handleTouchStart)
  document.removeEventListener('touchmove', handleTouchMove)
  document.removeEventListener('touchend', handleTouchEnd)
})
</script>

<style scoped>
.timeline-page {
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding-bottom: 80px;
}

.refresh-indicator {
  position: fixed;
  top: 60px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(255, 255, 255, 0.95);
  padding: 12px 24px;
  border-radius: 24px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  display: flex;
  align-items: center;
  gap: 8px;
  z-index: 1000;
  animation: slideDown 0.3s ease;
}

@keyframes slideDown {
  from {
    opacity: 0;
    transform: translateX(-50%) translateY(-20px);
  }
  to {
    opacity: 1;
    transform: translateX(-50%) translateY(0);
  }
}

.refresh-icon {
  display: inline-block;
  animation: rotate 1s linear infinite;
}

@keyframes rotate {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.page-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 24px 16px;
}

.page-header {
  text-align: center;
  margin-bottom: 32px;
  color: white;
}

.page-header h1 {
  font-size: 32px;
  font-weight: 700;
  margin-bottom: 8px;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.subtitle {
  font-size: 16px;
  opacity: 0.9;
}

.moments-list {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.moment-wrapper {
  animation: fadeInUp 0.5s ease forwards;
  opacity: 0;
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.loading-more {
  text-align: center;
  padding: 24px;
  color: white;
  font-size: 14px;
}

.empty-state {
  text-align: center;
  padding: 80px 20px;
  color: white;
}

.empty-icon {
  font-size: 64px;
  margin-bottom: 16px;
  animation: bounce 2s ease-in-out infinite;
}

@keyframes bounce {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-10px); }
}

.empty-text {
  font-size: 18px;
  font-weight: 500;
  margin-bottom: 8px;
}

.empty-hint {
  font-size: 14px;
  opacity: 0.8;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .page-container {
    padding: 16px 12px;
  }

  .page-header h1 {
    font-size: 28px;
  }

  .subtitle {
    font-size: 14px;
  }

  .moments-list {
    gap: 16px;
  }
}

/* Skeleton loading */
.skeleton {
  background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: loading 1.5s ease-in-out infinite;
}

@keyframes loading {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
</style>

