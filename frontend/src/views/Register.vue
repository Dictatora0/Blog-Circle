<template>
  <div class="register-page">
    <div class="register-container">
      <div class="register-card slide-up">
        <div class="card-header">
          <div class="logo-large">
            <span class="logo-icon">🟢</span>
            <h1 class="logo-title">Blog Circle</h1>
            <p class="logo-subtitle">加入我们，开始分享</p>
          </div>
        </div>
        
        <el-form :model="registerForm" :rules="rules" ref="registerFormRef" class="register-form">
          <el-form-item prop="username">
            <el-input
              v-model="registerForm.username"
              placeholder="用户名"
              prefix-icon="User"
              size="large"
            />
          </el-form-item>
          
          <el-form-item prop="password">
            <el-input
              v-model="registerForm.password"
              type="password"
              placeholder="密码"
              prefix-icon="Lock"
              size="large"
              show-password
            />
          </el-form-item>
          
          <el-form-item prop="confirmPassword">
            <el-input
              v-model="registerForm.confirmPassword"
              type="password"
              placeholder="确认密码"
              prefix-icon="Lock"
              size="large"
              show-password
            />
          </el-form-item>
          
          <el-form-item prop="email">
            <el-input
              v-model="registerForm.email"
              placeholder="邮箱"
              prefix-icon="Message"
              size="large"
            />
          </el-form-item>
          
          <el-form-item prop="nickname">
            <el-input
              v-model="registerForm.nickname"
              placeholder="昵称"
              prefix-icon="User"
              size="large"
            />
          </el-form-item>
          
          <el-form-item>
            <el-button
              type="primary"
              size="large"
              :loading="loading"
              @click="handleRegister"
              class="register-button"
            >
              注册
            </el-button>
          </el-form-item>
          
          <div class="form-footer">
            <span class="link-text" @click="goToLogin">
              已有账号？立即登录
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
import { register } from '@/api/auth'

const router = useRouter()
const registerFormRef = ref(null)
const loading = ref(false)

const registerForm = reactive({
  username: '',
  password: '',
  confirmPassword: '',
  email: '',
  nickname: ''
})

const validatePassword = (rule, value, callback) => {
  if (value !== registerForm.password) {
    callback(new Error('两次输入的密码不一致'))
  } else {
    callback()
  }
}

const rules = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 20, message: '用户名长度在3-20个字符', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, max: 20, message: '密码长度在6-20个字符', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请确认密码', trigger: 'blur' },
    { validator: validatePassword, trigger: 'blur' }
  ],
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '请输入正确的邮箱格式', trigger: 'blur' }
  ],
  nickname: [
    { required: true, message: '请输入昵称', trigger: 'blur' }
  ]
}

const handleRegister = async () => {
  if (!registerFormRef.value) return
  
  await registerFormRef.value.validate(async (valid) => {
    if (valid) {
      loading.value = true
      try {
        await register({
          username: registerForm.username,
          password: registerForm.password,
          email: registerForm.email,
          nickname: registerForm.nickname
        })
        ElMessage.success('注册成功，请登录')
        router.push('/login')
      } catch (error) {
        console.error('注册失败:', error)
        const errorMsg = error.response?.data?.message || error.message || '注册失败'
        ElMessage.error(errorMsg)
      } finally {
        loading.value = false
      }
    }
  })
}

const goToLogin = () => {
  router.push('/login')
}
</script>

<style scoped>
.register-page {
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-md);
}

.register-container {
  width: 100%;
  max-width: 400px;
}

.register-card {
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

.register-form {
  margin-top: var(--spacing-lg);
}

.register-button {
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
