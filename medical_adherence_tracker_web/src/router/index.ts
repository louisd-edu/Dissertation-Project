import { createRouter, createWebHistory } from 'vue-router'
import { watch } from 'vue'
import { isAuthenticated, authLoading } from '../stores/auth'

const routes = [
  { path: '/', redirect: '/home' },
  { path: '/login',    component: () => import('../views/LoginView.vue'),      meta: { public: true } },
  { path: '/home',     component: () => import('../views/HomeView.vue') },
  { path: '/patients',       component: () => import('../views/PatientsView.vue') },
  { path: '/patients/new',   component: () => import('../views/CreatePatientView.vue') },
  { path: '/patients/:id/adherence', component: () => import('../views/AdherenceView.vue') },
  { path: '/patients/:id/plan/new',  component: () => import('../views/CreatePlanView.vue') },
  { path: '/settings', component: () => import('../views/SettingsView.vue') },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  if (authLoading.value) {
    await new Promise<void>((resolve) => {
      const stop = watch(authLoading, (loading) => {
        if (!loading) { stop(); resolve() }
      }, { immediate: true })
    })
  }

  if (!to.meta.public && !isAuthenticated.value) {
    return { path: '/login' }
  }
  if (to.path === '/login' && isAuthenticated.value) {
    return { path: '/home' }
  }
})

export default router
