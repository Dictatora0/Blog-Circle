<template>
  <div class="top-navbar">
    <div class="navbar-content">
      <div class="navbar-left">
        <div class="logo" @click="goToHome">
          <span class="logo-icon">🟢</span>
          <span class="logo-text">Blog Circle</span>
        </div>
      </div>
      
      <div class="navbar-right">
        <button 
          v-if="userStore.token" 
          class="btn-nav"
          @click="goToTimeline"
          title="好友动态"
        >
          <span class="btn-icon">🌟</span>
          <span class="btn-text">好友动态</span>
        </button>

        <button 
          v-if="userStore.token" 
          class="btn-nav"
          @click="goToFriends"
          title="好友管理"
        >
          <span class="btn-icon">👥</span>
          <span class="btn-text">好友</span>
        </button>

        <button 
          v-if="userStore.token" 
          class="btn-publish"
          @click="handlePublish"
        >
          <span class="btn-icon">✏️</span>
          <span class="btn-text">发表动态</span>
        </button>
        
        <div v-if="userStore.token" class="user-menu">
          <el-dropdown @command="handleCommand" trigger="click" placement="bottom-end">
            <div class="user-avatar-wrapper">
              <img 
                :src="userStore.userInfo?.avatar || defaultAvatar" 
                :alt="userStore.userInfo?.nickname"
                class="user-avatar"
              />
              <span class="user-name">{{ userStore.userInfo?.nickname || '我' }}</span>
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="profile">
                  <span class="menu-icon">👤</span>
                  个人主页
                </el-dropdown-item>
                <el-dropdown-item command="statistics">
                  <span class="menu-icon">📊</span>
                  数据统计
                </el-dropdown-item>
                <el-dropdown-item command="logout" divided>
                  <span class="menu-icon">🚪</span>
                  退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
        
        <div v-else class="auth-buttons">
          <button class="btn-ghost" @click="goToLogin">登录</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()
const defaultAvatar = 'https://via.placeholder.com/32?text=头像'

const goToHome = () => {
  router.push('/home')
}

const handlePublish = () => {
  router.push('/publish')
}

const goToTimeline = () => {
  router.push('/timeline')
}

const goToFriends = () => {
  router.push('/friends')
}

const handleCommand = (command) => {
  if (command === 'profile') {
    router.push('/profile')
  } else if (command === 'statistics') {
    router.push('/statistics')
  } else if (command === 'logout') {
    userStore.logout()
    ElMessage.success('已退出登录')
    router.push('/home')
  }
}

const goToLogin = () => {
  router.push('/login')
}
</script>

<style scoped>
.top-navbar {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  height: 64px;
  background: var(--bg-overlay);
  border-bottom: 1px solid var(--border-light);
  box-shadow: var(--shadow-sm);
  z-index: 1000;
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
}

.navbar-content {
  max-width: 1200px;
  margin: 0 auto;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--spacing-md);
}

.navbar-left {
  display: flex;
  align-items: center;
}

.logo {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  font-size: var(--font-size-xl);
  font-weight: var(--font-weight-bold);
  color: var(--text-primary);
  cursor: pointer;
  transition: all var(--transition-base);
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--radius-md);
}

.logo:hover {
  transform: scale(1.05);
  background: var(--bg-hover);
}

.logo:hover .logo-text {
  background: var(--primary-gradient);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.logo-icon {
  font-size: 28px;
  line-height: 1;
  transition: transform var(--transition-base);
}

.logo:hover .logo-icon {
  transform: rotate(15deg) scale(1.1);
}

.logo-text {
  letter-spacing: -0.02em;
  transition: all var(--transition-base);
}

.navbar-right {
  display: flex;
  align-items: center;
  gap: var(--spacing-md);
}

.btn-nav {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  background: transparent;
  color: var(--text-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-full);
  padding: var(--spacing-sm) var(--spacing-md);
  font-size: var(--font-size-sm);
  font-weight: var(--font-weight-medium);
  cursor: pointer;
  transition: all var(--transition-base);
}

.btn-nav:hover {
  background: var(--bg-hover);
  border-color: var(--primary-color);
  color: var(--primary-color);
  transform: translateY(-1px);
}

.btn-nav:active {
  transform: translateY(0);
}

.btn-publish {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  background: var(--primary-gradient);
  color: var(--text-white);
  border: none;
  border-radius: var(--radius-full);
  padding: var(--spacing-sm) var(--spacing-lg);
  font-size: var(--font-size-md);
  font-weight: var(--font-weight-medium);
  cursor: pointer;
  transition: all var(--transition-base);
  box-shadow: var(--shadow-sm);
  position: relative;
  overflow: hidden;
}

.btn-publish::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.3), transparent);
  transition: left var(--transition-slow);
}

.btn-publish:hover {
  background: var(--primary-hover);
  box-shadow: var(--shadow-md), var(--primary-glow);
  transform: translateY(-2px);
}

.btn-publish:hover::before {
  left: 100%;
}

.btn-publish:active {
  transform: translateY(0);
}

.btn-icon {
  font-size: var(--font-size-sm);
}

.btn-text {
  font-weight: 500;
}

.user-menu {
  display: flex;
  align-items: center;
}

.user-avatar-wrapper {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  cursor: pointer;
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--radius-md);
  transition: background 0.2s;
  user-select: none; /* 防止文本选择干扰点击 */
  -webkit-user-select: none;
  pointer-events: auto; /* 确保可以接收点击事件 */
}

.user-avatar-wrapper:hover {
  background: var(--bg-hover);
}

.user-avatar {
  width: 32px;
  height: 32px;
  border-radius: var(--radius-full);
  object-fit: cover;
  border: 1px solid var(--border-light);
  pointer-events: none; /* 让点击事件穿透到父元素 */
}

.user-name {
  font-size: var(--font-size-sm);
  color: var(--text-primary);
  font-weight: 500;
  pointer-events: none; /* 让点击事件穿透到父元素 */
}

.auth-buttons {
  display: flex;
  gap: var(--spacing-sm);
}

.menu-icon {
  margin-right: var(--spacing-xs);
}

@media (max-width: 768px) {
  .logo-text {
    display: none;
  }
  
  .btn-nav .btn-text,
  .btn-publish .btn-text {
    display: none;
  }
  
  .btn-nav,
  .btn-publish {
    padding: var(--spacing-sm);
    border-radius: var(--radius-full);
  }
  
  .navbar-right {
    gap: var(--spacing-sm);
  }
  
  .user-name {
    display: none;
  }
}

:deep(.el-dropdown-menu__item) {
  display: flex;
  align-items: center;
  padding: var(--spacing-sm) var(--spacing-md);
}

:deep(.el-dropdown-menu__item:hover) {
  background: var(--bg-hover);
  color: var(--primary-color);
}
</style>
