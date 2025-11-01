<template>
  <div class="home-page">
    <!-- 下拉刷新提示 -->
    <div v-if="refreshing" class="refresh-indicator">
      <span class="refresh-icon">🔄</span>
      <span>刷新中...</span>
    </div>
    
    <div class="page-container">
      <div class="moments-list">
        <div 
          v-for="(moment, index) in moments" 
          :key="moment.id"
          class="moment-wrapper"
        >
          <MomentItem 
            :moment="moment" 
            :index="index"
            @update="loadMoments"
          />
        </div>
        
        <div v-if="loading" class="loading-more">
          <span>加载中...</span>
        </div>
        
        <div v-if="!loading && moments.length === 0" class="empty-state">
          <div class="empty-icon">📝</div>
          <div class="empty-text">还没有动态，快来发表第一条吧~</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useIntersectionObserver } from '@vueuse/core'
import { getPostList } from '@/api/post'
import { useUserStore } from '@/stores/user'
import MomentItem from '@/components/MomentItem.vue'

const userStore = useUserStore()
const moments = ref([])
const loading = ref(false)
const refreshing = ref(false)
const page = ref(1)
const hasMore = ref(true)

let touchStartY = 0
let touchEndY = 0

const loadMoments = async (reset = false) => {
  if (loading.value) return
  
  loading.value = true
  try {
    const res = await getPostList()
    // 后端返回格式: { code: 200, message: "...", data: [...] }
    const responseData = res.data?.data || res.data || []
    const newMoments = Array.isArray(responseData) ? responseData : []
    
    const processedMoments = newMoments.map(post => ({
      ...post,
      content: post.content || post.title,
      images: post.images || null,
      liked: post.liked || false,
      likeCount: post.likeCount || 0,
      commentCount: post.commentCount || 0
    }))
    
    if (reset) {
      moments.value = processedMoments
    } else {
      moments.value.push(...processedMoments)
    }
    
    hasMore.value = newMoments.length >= 10
  } catch (error) {
    console.error('加载动态失败:', error)
  } finally {
    loading.value = false
  }
}

const handleRefresh = async () => {
  if (refreshing.value || loading.value) return
  
  refreshing.value = true
  try {
    await loadMoments(true)
  } finally {
    refreshing.value = false
  }
}

const handleTouchStart = (e) => {
  touchStartY = e.touches[0].clientY
}

const handleTouchMove = (e) => {
  const scrollTop = window.pageYOffset || document.documentElement.scrollTop
  if (scrollTop === 0 && !refreshing.value) {
    touchEndY = e.touches[0].clientY
    const diff = touchEndY - touchStartY
    
    if (diff > 80) {
      handleRefresh()
    }
  }
}

let mouseStartY = 0
let mouseDown = false

const handleMouseDown = (e) => {
  if (window.pageYOffset === 0) {
    mouseDown = true
    mouseStartY = e.clientY
  }
}

const handleMouseMove = (e) => {
  if (mouseDown && window.pageYOffset === 0 && !refreshing.value) {
    const diff = e.clientY - mouseStartY
    if (diff > 80) {
      handleRefresh()
      mouseDown = false
    }
  }
}

const handleMouseUp = () => {
  mouseDown = false
}

onMounted(() => {
  loadMoments(true)
  
  // 无限滚动
  const target = document.querySelector('.loading-more')
  if (target) {
    useIntersectionObserver(target, ([{ isIntersecting }]) => {
      if (isIntersecting && hasMore.value && !loading.value) {
        page.value++
        loadMoments()
      }
    })
  }
  
  // 下拉刷新（移动端）
  window.addEventListener('touchstart', handleTouchStart)
  window.addEventListener('touchmove', handleTouchMove)
  
  // 鼠标下拉刷新（桌面端）
  window.addEventListener('mousedown', handleMouseDown)
  window.addEventListener('mousemove', handleMouseMove)
  window.addEventListener('mouseup', handleMouseUp)
})

onUnmounted(() => {
  window.removeEventListener('touchstart', handleTouchStart)
  window.removeEventListener('touchmove', handleTouchMove)
  window.removeEventListener('mousedown', handleMouseDown)
  window.removeEventListener('mousemove', handleMouseMove)
  window.removeEventListener('mouseup', handleMouseUp)
})
</script>

<style scoped>
.home-page {
  min-height: 100vh;
  background: var(--bg-secondary);
  padding-top: 72px;
  position: relative;
}

.refresh-indicator {
  position: fixed;
  top: 72px;
  left: 50%;
  transform: translateX(-50%);
  background: var(--primary-color);
  color: white;
  padding: var(--spacing-sm) var(--spacing-lg);
  border-radius: 0 0 var(--radius-md) var(--radius-md);
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  font-size: var(--font-size-sm);
  z-index: 100;
  animation: slideDown 0.3s ease-out;
}

.refresh-icon {
  animation: rotate 1s linear infinite;
}

@keyframes slideDown {
  from {
    transform: translateX(-50%) translateY(-100%);
  }
  to {
    transform: translateX(-50%) translateY(0);
  }
}

@keyframes rotate {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.page-container {
  max-width: 680px;
  margin: 0 auto;
  padding: var(--spacing-lg) var(--spacing-md);
}

.moments-list {
  display: flex;
  flex-direction: column;
}

.moment-wrapper {
  margin-bottom: var(--spacing-md);
}

.loading-more {
  text-align: center;
  padding: var(--spacing-lg);
  color: var(--text-tertiary);
  font-size: var(--font-size-sm);
}

.empty-state {
  text-align: center;
  padding: var(--spacing-xl) var(--spacing-md);
  color: var(--text-tertiary);
}

.empty-icon {
  font-size: 64px;
  margin-bottom: var(--spacing-md);
  opacity: 0.5;
}

.empty-text {
  font-size: var(--font-size-md);
}

@media (max-width: 768px) {
  .page-container {
    padding: var(--spacing-md) var(--spacing-sm);
  }
}
</style>
