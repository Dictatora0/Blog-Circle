import { createRouter, createWebHistory } from 'vue-router'
import { useUserStore } from '@/stores/user'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue'),
    meta: { requiresAuth: false }
  },
  {
    path: '/register',
    name: 'Register',
    component: () => import('@/views/Register.vue'),
    meta: { requiresAuth: false }
  },
  {
    path: '/',
    name: 'Layout',
    component: () => import('@/views/Layout.vue'),
    redirect: '/home',
    children: [
      {
        path: '/home',
        name: 'Home',
        component: () => import('@/views/Home.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: '/publish',
        name: 'Publish',
        component: () => import('@/views/Publish.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: '/profile',
        name: 'Profile',
        component: () => import('@/views/Profile.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: '/posts/:id',
        name: 'PostDetail',
        component: () => import('@/views/PostDetail.vue'),
        meta: { requiresAuth: false }
      },
      {
        path: '/statistics',
        name: 'Statistics',
        component: () => import('@/views/Statistics.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: '/friends',
        name: 'Friends',
        component: () => import('@/views/Friends.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: '/timeline',
        name: 'Timeline',
        component: () => import('@/views/Timeline.vue'),
        meta: { requiresAuth: true }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// 路由守卫
router.beforeEach((to, from, next) => {
  const userStore = useUserStore()
  
  if (to.meta.requiresAuth && !userStore.token) {
    next('/login')
  } else if (to.path === '/login' && userStore.token) {
    next('/home')
  } else {
    next()
  }
})

export default router


