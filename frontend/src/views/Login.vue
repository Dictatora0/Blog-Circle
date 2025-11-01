<template>
  <div class="login-page">
    <div class="login-container">
      <div class="login-card slide-up">
        <div class="card-header">
          <div class="logo-large">
            <span class="logo-icon">🟢</span>
            <h1 class="logo-title">Blog Circle</h1>
            <p class="logo-subtitle">欢迎回来</p>
          </div>
        </div>
        
        <el-form :model="loginForm" :rules="rules" ref="loginFormRef" class="login-form">
          <el-form-item prop="username">
            <el-input
              v-model="loginForm.username"
              placeholder="用户名"
              prefix-icon="User"
              size="large"
            />
          </el-form-item>
          
          <el-form-item prop="password">
            <el-input
              v-model="loginForm.password"
              type="password"
              placeholder="密码"
              prefix-icon="Lock"
              size="large"
              show-password
              @keyup.enter="handleLogin"
            />
          </el-form-item>
          
          <el-form-item>
            <el-button
              type="primary"
              size="large"
              :loading="loading"
              @click="handleLogin"
              class="login-button"
            >
              登录
            </el-button>
          </el-form-item>
          
          <div class="form-footer">
            <span class="link-text" @click="goToRegister">
              还没有账号？立即注册
            </span>
          </div>
        </el-form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { login } from '@/api/auth'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()
const loginFormRef = ref(null)
const loading = ref(false)

const loginForm = reactive({
  username: '',
  password: ''
})

const rules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}

const handleLogin = async () => {
  if (!loginFormRef.value) return
  
  await loginFormRef.value.validate(async (valid) => {
    if (valid) {
      loading.value = true
      try {
        const res = await login(loginForm)
        console.log('登录响应:', res.data)
        
        // 后端返回格式: { code: 200, message: "...", data: { token: "...", user: {...} } }
        if (res.data && res.data.code === 200 && res.data.data) {
          const { token, user } = res.data.data
          if (token && user) {
            userStore.setToken(token)
            userStore.setUserInfo(user)
            ElMessage.success(res.data.message || '登录成功')
            await router.push('/home')
          } else {
            ElMessage.error('登录失败，响应数据格式错误')
          }
        } else {
          const errorMsg = res.data?.message || '登录失败，请检查用户名和密码'
          ElMessage.error(errorMsg)
        }
      } catch (error) {
        console.error('登录失败:', error)
        const errorMsg = error.response?.data?.message || error.message || '登录失败，请检查用户名和密码'
        ElMessage.error(errorMsg)
      } finally {
        loading.value = false
      }
    }
  })
}

const goToRegister = () => {
  router.push('/register')
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-md);
}

.login-container {
  width: 100%;
  max-width: 400px;
}

.login-card {
  background: var(--bg-primary);
  border-radius: var(--radius-xl);
  padding: var(--spacing-xl);
  box-shadow: var(--shadow-lg);
}

.card-header {
  text-align: center;
  margin-bottom: var(--spacing-xl);
}

.logo-large {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--spacing-sm);
}

.logo-icon {
  font-size: 64px;
  line-height: 1;
}

.logo-title {
  font-size: var(--font-size-xl);
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.logo-subtitle {
  font-size: var(--font-size-md);
  color: var(--text-tertiary);
  margin: 0;
}

.login-form {
  margin-top: var(--spacing-lg);
}

.login-button {
  width: 100%;
  height: 48px;
  font-size: var(--font-size-md);
  font-weight: 500;
  border-radius: var(--radius-md);
}

.form-footer {
  text-align: center;
  margin-top: var(--spacing-md);
}

.link-text {
  color: var(--text-secondary);
  cursor: pointer;
  font-size: var(--font-size-sm);
  transition: color 0.2s;
}

.link-text:hover {
  color: var(--primary-color);
}

:deep(.el-input__wrapper) {
  border-radius: var(--radius-md);
  padding: 12px 16px;
}

:deep(.el-form-item) {
  margin-bottom: var(--spacing-lg);
}

:deep(.el-form-item__error) {
  font-size: var(--font-size-xs);
}
</style>
