import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('token') || '')
  const userInfo = ref(JSON.parse(localStorage.getItem('userInfo') || 'null'))

  const setToken = (newToken) => {
    if (newToken) {
      token.value = newToken
      localStorage.setItem('token', newToken)
    } else {
      token.value = ''
      localStorage.removeItem('token')
    }
  }

  const setUserInfo = (info) => {
    if (info) {
      userInfo.value = info
      localStorage.setItem('userInfo', JSON.stringify(info))
    } else {
      userInfo.value = null
      localStorage.removeItem('userInfo')
    }
  }

  const logout = () => {
    token.value = ''
    userInfo.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('userInfo')
  }

  const isLoggedIn = computed(() => {
    return !!token.value
  })

  return {
    token,
    userInfo,
    isLoggedIn,
    setToken,
    setUserInfo,
    logout
  }
})


