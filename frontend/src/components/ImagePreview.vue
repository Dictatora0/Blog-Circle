<template>
  <div v-if="visible" class="image-preview-modal" @click="close">
    <div class="modal-content" @click.stop>
      <button class="close-btn" @click="close">×</button>
      <img :src="currentImage" :alt="`图片${currentIndex + 1}`" class="preview-image" />
      <button v-if="images.length > 1" class="nav-btn prev-btn" @click="prevImage">‹</button>
      <button v-if="images.length > 1" class="nav-btn next-btn" @click="nextImage">›</button>
      <div v-if="images.length > 1" class="image-counter">
        {{ currentIndex + 1 }} / {{ images.length }}
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'

const props = defineProps({
  visible: {
    type: Boolean,
    default: false
  },
  images: {
    type: Array,
    default: () => []
  },
  initialIndex: {
    type: Number,
    default: 0
  }
})

const emit = defineEmits(['update:visible', 'close'])

const currentIndex = ref(props.initialIndex)
const currentImage = ref(props.images[props.initialIndex] || '')

watch(() => props.visible, (newVal) => {
  if (newVal) {
    currentIndex.value = props.initialIndex
    currentImage.value = props.images[props.initialIndex] || ''
  }
})

watch(() => props.images, (newVal) => {
  if (newVal.length > 0 && currentIndex.value < newVal.length) {
    currentImage.value = newVal[currentIndex.value]
  }
})

const close = () => {
  emit('update:visible', false)
  emit('close')
}

const prevImage = () => {
  if (currentIndex.value > 0) {
    currentIndex.value--
    currentImage.value = props.images[currentIndex.value]
  } else {
    currentIndex.value = props.images.length - 1
    currentImage.value = props.images[currentIndex.value]
  }
}

const nextImage = () => {
  if (currentIndex.value < props.images.length - 1) {
    currentIndex.value++
    currentImage.value = props.images[currentIndex.value]
  } else {
    currentIndex.value = 0
    currentImage.value = props.images[0]
  }
}
</script>

<style scoped>
.image-preview-modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.9);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: fadeIn 0.3s ease-out;
}

.modal-content {
  position: relative;
  max-width: 90vw;
  max-height: 90vh;
  display: flex;
  align-items: center;
  justify-content: center;
}

.preview-image {
  max-width: 100%;
  max-height: 90vh;
  object-fit: contain;
  border-radius: var(--radius-md);
}

.close-btn {
  position: absolute;
  top: -40px;
  right: 0;
  background: rgba(255, 255, 255, 0.2);
  color: white;
  border: none;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-full);
  font-size: 24px;
  line-height: 1;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.close-btn:hover {
  background: rgba(255, 255, 255, 0.3);
}

.nav-btn {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  background: rgba(255, 255, 255, 0.2);
  color: white;
  border: none;
  width: 48px;
  height: 48px;
  border-radius: var(--radius-full);
  font-size: 32px;
  line-height: 1;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.nav-btn:hover {
  background: rgba(255, 255, 255, 0.3);
}

.prev-btn {
  left: 20px;
}

.next-btn {
  right: 20px;
}

.image-counter {
  position: absolute;
  bottom: -40px;
  left: 50%;
  transform: translateX(-50%);
  color: white;
  font-size: var(--font-size-md);
  background: rgba(0, 0, 0, 0.5);
  padding: var(--spacing-xs) var(--spacing-md);
  border-radius: var(--radius-md);
}
</style>

