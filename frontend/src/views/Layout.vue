<template>
  <div class="layout-container">
    <TopNavbar />

    <div class="layout-content">
      <router-view v-slot="{ Component }">
        <transition name="fade" mode="out-in">
          <component :is="Component" />
        </transition>
      </router-view>
    </div>

    <!-- 底部导航栏（移动端） -->
    <div v-if="showBottomNav" class="bottom-nav">
      <div
        class="nav-item"
        :class="{ active: $route.path === '/home' }"
        @click="goTo('/home')"
      >
        <span class="nav-icon">🏠</span>
        <span class="nav-label">首页</span>
      </div>
      <div
        class="nav-item"
        :class="{ active: $route.path === '/publish' }"
        @click="goTo('/publish')"
      >
        <span class="nav-icon">✏️</span>
        <span class="nav-label">发表</span>
      </div>
      <div
        class="nav-item"
        :class="{ active: $route.path === '/profile' }"
        @click="goTo('/profile')"
      >
        <span class="nav-icon">👤</span>
        <span class="nav-label">我的</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import TopNavbar from "@/components/TopNavbar.vue";

const route = useRoute();
const router = useRouter();

const showBottomNav = computed(() => {
  const paths = ["/home", "/publish", "/profile"];
  return paths.includes(route.path) && window.innerWidth <= 768;
});

const goTo = (path) => {
  router.push(path);
};
</script>

<style scoped>
.layout-container {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.layout-content {
  flex: 1;
}

/* 路由过渡动画 */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

/* 底部导航栏 */
.bottom-nav {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: 56px;
  background: var(--bg-primary);
  border-top: 1px solid var(--border-light);
  display: flex;
  justify-content: space-around;
  align-items: center;
  z-index: 1000;
  box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.05);
}

.nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  flex: 1;
  cursor: pointer;
  transition: all 0.2s;
  padding: var(--spacing-xs);
}

.nav-item:hover {
  background: var(--bg-hover);
}

.nav-item.active {
  color: var(--primary-color);
}

.nav-icon {
  font-size: 24px;
  line-height: 1;
}

.nav-label {
  font-size: var(--font-size-xs);
}

@media (min-width: 769px) {
  .bottom-nav {
    display: none;
  }
}
</style>
