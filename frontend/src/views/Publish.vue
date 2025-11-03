<template>
  <div class="publish-page">
    <div class="page-container">
      <div class="publish-card">
        <div class="card-header">
          <h2>发表动态</h2>
        </div>
        
        <div class="card-body">
          <div class="publish-header">
            <img 
              :src="userStore.userInfo?.avatar || defaultAvatar" 
              :alt="userStore.userInfo?.nickname"
              class="avatar"
            />
            <div class="publish-author">{{ userStore.userInfo?.nickname || '我' }}</div>
          </div>
          
          <el-input
            v-model="content"
            type="textarea"
            :rows="8"
            placeholder="分享你的想法..."
            class="content-input"
            maxlength="2000"
            show-word-limit
          />
          
          <!-- 图片上传区域 -->
          <div class="image-upload-section">
            <div class="upload-grid">
              <div 
                v-for="(img, index) in images" 
                :key="index"
                class="image-preview"
              >
                <img :src="img" alt="预览" />
                <button class="remove-btn" @click="removeImage(index)">×</button>
              </div>
              
              <div 
                v-if="images.length < 9"
                class="upload-placeholder"
                @click="triggerFileInput"
              >
                <span class="upload-icon">📷</span>
                <span class="upload-text">添加图片</span>
              </div>
            </div>
            
            <input
              ref="fileInput"
              type="file"
              multiple
              accept="image/*"
              style="display: none"
              @change="handleFileSelect"
            />
          </div>
          
          <div class="publish-footer">
            <div class="word-count">{{ content.length }}/2000</div>
            <button 
              class="btn-publish"
              :disabled="!content.trim() || publishing"
              @click="handlePublish"
            >
              {{ publishing ? '发布中...' : '发布' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'
import { createPost } from '@/api/post'
import { uploadImage } from '@/api/upload'

const router = useRouter()
const userStore = useUserStore()

const content = ref('')
const images = ref([]) // 存储图片URL
const imageFiles = ref([]) // 存储文件对象
const fileInput = ref(null)
const publishing = ref(false)
const uploading = ref(false)
const defaultAvatar = 'https://via.placeholder.com/40?text=头像'

const triggerFileInput = () => {
  fileInput.value?.click()
}

const handleFileSelect = async (e) => {
  const files = Array.from(e.target.files)
  const remaining = 9 - images.value.length
  
  if (remaining <= 0) {
    ElMessage.warning('最多只能上传9张图片')
    return
  }
  
  uploading.value = true
  
  try {
    for (const file of files.slice(0, remaining)) {
      if (!file.type.startsWith('image/')) {
        ElMessage.warning(`${file.name} 不是图片文件`)
        continue
      }
      
      // 先显示预览
      const reader = new FileReader()
      reader.onload = (e) => {
        images.value.push(e.target.result)
        imageFiles.value.push(file)
      }
      reader.readAsDataURL(file)
    }
  } finally {
    uploading.value = false
    e.target.value = ''
  }
}

const removeImage = (index) => {
  images.value.splice(index, 1)
  imageFiles.value.splice(index, 1)
}

const uploadImages = async () => {
  const uploadedUrls = []
  
  for (const file of imageFiles.value) {
    try {
      const res = await uploadImage(file)
      if (res.data && res.data.data) {
        uploadedUrls.push(`http://localhost:8080${res.data.data.url}`)
      }
    } catch (error) {
      console.error('图片上传失败:', error)
      ElMessage.error('部分图片上传失败')
    }
  }
  
  return uploadedUrls
}

const handlePublish = async () => {
  if (!content.value.trim()) {
    ElMessage.warning('请输入内容')
    return
  }
  
  publishing.value = true
  try {
    // 先上传图片
    let imageUrls = []
    if (imageFiles.value.length > 0) {
      imageUrls = await uploadImages()
    }
    
    // 发布动态
    await createPost({
      title: content.value.substring(0, 50),
      content: content.value,
      images: JSON.stringify(imageUrls)
    })
    
    ElMessage.success('发布成功')
    router.push('/home')
  } catch (error) {
    console.error('发布失败:', error)
    ElMessage.error('发布失败，请重试')
  } finally {
    publishing.value = false
  }
}
</script>

<style scoped>
.publish-page {
  min-height: 100vh;
  background: var(--bg-secondary);
  padding-top: 80px;
}

.page-container {
  max-width: 680px;
  margin: 0 auto;
  padding: var(--spacing-lg) var(--spacing-md);
}

.publish-card {
  background: var(--bg-primary);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-card);
  overflow: hidden;
  border: 1px solid var(--border-light);
  transition: all var(--transition-base);
}

.publish-card:hover {
  box-shadow: var(--shadow-card-hover);
}

.card-header {
  padding: var(--spacing-lg) var(--spacing-xl);
  border-bottom: 1px solid var(--border-light);
  background: linear-gradient(135deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
}

.card-header h2 {
  font-size: var(--font-size-2xl);
  font-weight: var(--font-weight-bold);
  color: var(--text-primary);
  letter-spacing: -0.02em;
  background: var(--primary-gradient);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.card-body {
  padding: var(--spacing-lg);
}

.publish-header {
  display: flex;
  align-items: center;
  gap: var(--spacing-md);
  margin-bottom: var(--spacing-lg);
}

.publish-author {
  font-weight: 500;
  color: var(--text-primary);
}

.content-input {
  margin-bottom: var(--spacing-lg);
}

.content-input :deep(.el-textarea__inner) {
  border: 1.5px solid var(--border-color);
  box-shadow: 0 0 0 1px var(--border-color) inset;
  resize: none;
  font-size: var(--font-size-md);
  line-height: 1.75;
  padding: var(--spacing-md);
  border-radius: var(--radius-md);
  transition: all var(--transition-base);
  background: var(--bg-secondary);
  min-height: 200px;
}

.content-input :deep(.el-textarea__inner):hover {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 1.5px var(--primary-color) inset;
  background: var(--bg-primary);
}

.content-input :deep(.el-textarea__inner):focus {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 2px var(--primary-color) inset, 0 0 0 4px var(--primary-light);
  background: var(--bg-primary);
}

.image-upload-section {
  margin-bottom: var(--spacing-lg);
}

.upload-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--spacing-sm);
}

.image-preview {
  position: relative;
  aspect-ratio: 1;
  border-radius: var(--radius-md);
  overflow: hidden;
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  transition: all var(--transition-base);
}

.image-preview:hover {
  transform: scale(1.02);
  box-shadow: var(--shadow-md);
}

.image-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform var(--transition-base);
}

.image-preview:hover img {
  transform: scale(1.05);
}

.remove-btn {
  position: absolute;
  top: var(--spacing-xs);
  right: var(--spacing-xs);
  width: 28px;
  height: 28px;
  background: rgba(0, 0, 0, 0.7);
  color: white;
  border: none;
  border-radius: var(--radius-full);
  cursor: pointer;
  font-size: 18px;
  font-weight: var(--font-weight-bold);
  line-height: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all var(--transition-base);
  backdrop-filter: blur(4px);
  z-index: 2;
}

.remove-btn:hover {
  background: var(--primary-color);
  transform: scale(1.1) rotate(90deg);
}

.upload-placeholder {
  aspect-ratio: 1;
  border: 2px dashed var(--border-color);
  border-radius: var(--radius-md);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all var(--transition-base);
  background: var(--bg-secondary);
  position: relative;
  overflow: hidden;
}

.upload-placeholder::before {
  content: '';
  position: absolute;
  inset: 0;
  background: var(--primary-gradient);
  opacity: 0;
  transition: opacity var(--transition-base);
}

.upload-placeholder:hover {
  border-color: var(--primary-color);
  transform: scale(1.02);
  box-shadow: var(--shadow-sm);
}

.upload-placeholder:hover::before {
  opacity: 0.05;
}

.upload-icon {
  font-size: 40px;
  margin-bottom: var(--spacing-sm);
  position: relative;
  z-index: 1;
  transition: transform var(--transition-base);
}

.upload-placeholder:hover .upload-icon {
  transform: scale(1.1);
}

.upload-text {
  font-size: var(--font-size-sm);
  color: var(--text-tertiary);
  font-weight: var(--font-weight-medium);
  position: relative;
  z-index: 1;
  transition: color var(--transition-base);
}

.upload-placeholder:hover .upload-text {
  color: var(--primary-color);
}

.publish-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: var(--spacing-md);
  border-top: 1px solid var(--border-light);
}

.word-count {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
}

.btn-publish {
  background: var(--primary-gradient);
  color: var(--text-white);
  border: none;
  border-radius: var(--radius-full);
  padding: var(--spacing-md) var(--spacing-2xl);
  font-size: var(--font-size-md);
  font-weight: var(--font-weight-semibold);
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

.btn-publish:hover:not(:disabled) {
  background: var(--primary-hover);
  box-shadow: var(--shadow-md), var(--primary-glow);
  transform: translateY(-2px);
}

.btn-publish:hover:not(:disabled)::before {
  left: 100%;
}

.btn-publish:active:not(:disabled) {
  transform: translateY(0);
}

.btn-publish:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  transform: none;
}

@media (max-width: 768px) {
  .upload-grid {
    grid-template-columns: repeat(3, 1fr);
    gap: var(--spacing-xs);
  }
  
  .card-body {
    padding: var(--spacing-md);
  }
}
</style>

