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
  padding-top: 72px;
}

.page-container {
  max-width: 680px;
  margin: 0 auto;
  padding: var(--spacing-lg) var(--spacing-md);
}

.publish-card {
  background: var(--bg-primary);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-md);
  overflow: hidden;
}

.card-header {
  padding: var(--spacing-lg);
  border-bottom: 1px solid var(--border-light);
}

.card-header h2 {
  font-size: var(--font-size-xl);
  font-weight: 600;
  color: var(--text-primary);
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
  border: none;
  box-shadow: none;
  resize: none;
  font-size: var(--font-size-md);
  line-height: 1.6;
  padding: 0;
}

.content-input :deep(.el-textarea__inner):focus {
  box-shadow: none;
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
}

.image-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.remove-btn {
  position: absolute;
  top: var(--spacing-xs);
  right: var(--spacing-xs);
  width: 24px;
  height: 24px;
  background: rgba(0, 0, 0, 0.6);
  color: white;
  border: none;
  border-radius: var(--radius-full);
  cursor: pointer;
  font-size: 18px;
  line-height: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.2s;
}

.remove-btn:hover {
  background: rgba(0, 0, 0, 0.8);
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
  transition: all 0.2s;
  background: var(--bg-secondary);
}

.upload-placeholder:hover {
  border-color: var(--primary-color);
  background: var(--primary-light);
}

.upload-icon {
  font-size: 32px;
  margin-bottom: var(--spacing-xs);
}

.upload-text {
  font-size: var(--font-size-sm);
  color: var(--text-tertiary);
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
  background: var(--primary-color);
  color: white;
  border: none;
  border-radius: var(--radius-full);
  padding: var(--spacing-sm) var(--spacing-xl);
  font-size: var(--font-size-md);
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: var(--shadow-sm);
}

.btn-publish:hover:not(:disabled) {
  background: var(--primary-hover);
  box-shadow: var(--shadow-md);
  transform: translateY(-1px);
}

.btn-publish:disabled {
  opacity: 0.5;
  cursor: not-allowed;
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

