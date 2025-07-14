import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/components/LoginForm.vue'),
      meta: {
        title: 'Вход в систему',
        requiresAuth: false
      }
    },
    {
      path: '/',
      name: 'dashboard',
      // Используем lazy loading и для главной страницы
      component: () => import('../views/HomeView.vue'),
      meta: {
        title: 'Дашборд',
        requiresAuth: false
      }
    },
    {
      path: '/campaigns',
      name: 'campaigns',
      // Ленивая загрузка компонента
      component: () => import('../views/CampaignsView.vue'),
      meta: {
        title: 'Кампании',
        requiresAuth: false,
        requiredPermissions: ['campaigns_view']
      }
    },
    {
      path: '/campaigns/:id',
      name: 'campaign-detail',
      component: () => import('../views/CampaignDetailView.vue'),
      props: true,
      meta: {
        title: 'Детали кампании',
        requiresAuth: true,
        requiredPermissions: ['campaigns_view']
      }
    },
    {
      path: '/contacts',
      name: 'contacts',
      component: () => import('../views/ContactsView.vue'),
      meta: {
        title: 'Контакты',
        requiresAuth: false,
        requiredPermissions: ['contacts_view']
      }
    },
    {
      path: '/statistics',
      name: 'statistics',
      component: () => import('../views/StatisticsView.vue'),
      meta: {
        title: 'Статистика',
        requiresAuth: true,
        requiredPermissions: ['stats_view']
      }
    },
    {
      path: '/settings',
      name: 'settings',
      component: () => import('../views/SettingsView.vue'),
      meta: {
        title: 'Настройки',
        requiresAuth: true,
        requiredPermissions: ['settings_manage']
      }
    },
    // Маршрут для обработки несуществующих страниц
    {
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      component: () => import('../views/NotFoundView.vue'),
      meta: {
        title: 'Страница не найдена'
      }
    }
  ]
})

// Navigation guard для проверки авторизации
router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore()
  
  // Проверяем требуется ли авторизация для маршрута
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth !== false)
  
  if (requiresAuth) {
    // Если токен есть, но пользователь не загружен, ждем загрузки
    if (authStore.token && !authStore.user) {
      try {
        await authStore.fetchUser()
      } catch (error) {
        console.error('Ошибка получения пользователя:', error)
        // Если не удалось получить пользователя, очищаем авторизацию
        authStore.clearAuth()
      }
    }
    
    // Проверяем авторизацию после возможной загрузки пользователя
    if (!authStore.isAuthenticated) {
      // Если пользователь не авторизован, перенаправляем на страницу входа
      next({
        name: 'login',
        query: to.path !== '/' ? { redirect: to.fullPath } : {}
      })
      return
    }
    
    // Проверяем разрешения для маршрута
    const requiredPermissions = to.meta.requiredPermissions as string[]
    if (requiredPermissions && requiredPermissions.length > 0) {
      const hasPermission = requiredPermissions.some(permission => 
        authStore.hasPermission(permission)
      )
      
      if (!hasPermission) {
        console.warn(`Нет разрешений для маршрута ${to.path}:`, requiredPermissions)
        // Если нет разрешений, перенаправляем на главную страницу
        next({ name: 'dashboard' })
        return
      }
    }
  } else {
    // Если авторизация не требуется, но пользователь уже авторизован
    if (authStore.isAuthenticated && to.name === 'login') {
      // Перенаправляем авторизованного пользователя на главную страницу
      next({ name: 'dashboard' })
      return
    }
  }
  
  next()
})

// Обновление заголовка страницы
router.afterEach((to) => {
  document.title = to.meta.title ? `${to.meta.title} | Dialer System` : 'Dialer System'
})

export default router
