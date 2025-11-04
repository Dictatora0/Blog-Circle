<template>
  <div class="friend-card">
    <div class="friend-info">
      <img 
        :src="avatarUrl" 
        :alt="friend.nickname || friend.username" 
        class="friend-avatar"
        @error="handleAvatarError"
      />
      <div class="friend-details">
        <div class="friend-name">{{ friend.nickname || friend.username }}</div>
        <div class="friend-email">{{ friend.email }}</div>
      </div>
    </div>
    
    <div class="friend-actions">
      <slot name="actions"></slot>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { getResourceUrl } from '@/config'

const props = defineProps({
  friend: {
    type: Object,
    required: true
  }
})

const avatarUrl = computed(() => {
  if (props.friend.avatar) {
    if (props.friend.avatar.startsWith('http')) {
      return props.friend.avatar
    }
    return getResourceUrl(props.friend.avatar)
  }
  return 'https://api.dicebear.com/7.x/avataaars/svg?seed=' + (props.friend.id || 'default')
})

const handleAvatarError = (e) => {
  e.target.src = 'https://api.dicebear.com/7.x/avataaars/svg?seed=' + (props.friend.id || 'default')
}
</script>

<style scoped>
.friend-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transition: all 0.3s ease;
  margin-bottom: 12px;
}

.friend-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
  transform: translateY(-2px);
}

.friend-info {
  display: flex;
  align-items: center;
  flex: 1;
  gap: 12px;
}

.friend-avatar {
  width: 50px;
  height: 50px;
  border-radius: 50%;
  object-fit: cover;
  border: 2px solid #e8e8e8;
  transition: transform 0.3s ease;
}

.friend-avatar:hover {
  transform: scale(1.1);
}

.friend-details {
  flex: 1;
  min-width: 0;
}

.friend-name {
  font-size: 16px;
  font-weight: 600;
  color: #333;
  margin-bottom: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.friend-email {
  font-size: 13px;
  color: #999;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.friend-actions {
  display: flex;
  gap: 8px;
  align-items: center;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .friend-card {
    padding: 12px;
  }

  .friend-avatar {
    width: 44px;
    height: 44px;
  }

  .friend-name {
    font-size: 15px;
  }

  .friend-email {
    font-size: 12px;
  }
}
</style>

