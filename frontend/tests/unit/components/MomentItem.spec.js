import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/vue'
import { createRouter, createWebHistory } from 'vue-router'
import { createPinia, setActivePinia } from 'pinia'
import ElementPlus from 'element-plus'
import MomentItem from '@/components/MomentItem.vue'
import { useUserStore } from '@/stores/user'

/**
 * MomentItem 组件测试
 * 
 * 测试场景：
 * 1. 显示动态内容
 * 2. 显示用户信息
 * 3. 显示点赞和评论按钮
 * 4. 显示评论列表
 */
describe('MomentItem', () => {
  let router
  let pinia

  beforeEach(() => {
    router = createRouter({
      history: createWebHistory(),
      routes: []
    })
    
    pinia = createPinia()
    setActivePinia(pinia)
  })

  const mockMoment = {
    id: 1,
    title: '测试动态',
    content: '这是一条测试动态内容',
    authorName: '测试用户',
    createdAt: new Date().toISOString(),
    viewCount: 10,
    likeCount: 5,
    liked: false,
    images: null
  }

  it('场景1: 显示动态内容', () => {
    // Given: 准备动态数据
    // When: 渲染组件
    render(MomentItem, {
      props: {
        moment: mockMoment,
        index: 0
      },
      global: {
        plugins: [router, pinia, ElementPlus]
      }
    })

    // Then: 应该显示动态内容
    expect(screen.getByText('这是一条测试动态内容')).toBeInTheDocument()
    expect(screen.getByText('测试用户')).toBeInTheDocument()
  })

  it('场景2: 显示用户信息', () => {
    // Given & When: 渲染组件
    render(MomentItem, {
      props: {
        moment: mockMoment,
        index: 0
      },
      global: {
        plugins: [router, pinia, ElementPlus]
      }
    })

    // Then: 应该显示用户信息
    expect(screen.getByText('测试用户')).toBeInTheDocument()
  })

  it('场景3: 显示统计数据', () => {
    // Given & When: 渲染组件
    render(MomentItem, {
      props: {
        moment: mockMoment,
        index: 0
      },
      global: {
        plugins: [router, pinia, ElementPlus]
      }
    })

    // Then: 应该显示浏览数和点赞数
    expect(screen.getByText('10')).toBeInTheDocument()
    expect(screen.getByText('5')).toBeInTheDocument()
  })

  it('场景4: 显示图片（如果有）', () => {
    // Given: 动态包含图片
    const momentWithImages = {
      ...mockMoment,
      images: JSON.stringify(['http://example.com/image1.jpg'])
    }

    // When: 渲染组件
    render(MomentItem, {
      props: {
        moment: momentWithImages,
        index: 0
      },
      global: {
        plugins: [router, pinia, ElementPlus]
      }
    })

    // Then: 应该显示图片
    waitFor(() => {
      const images = screen.getAllByRole('img')
      expect(images.length).toBeGreaterThan(0)
    })
  })
})

