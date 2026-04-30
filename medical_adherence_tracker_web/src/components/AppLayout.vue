<template>
  <div class="layout">
    <aside class="sidebar">
      <div class="sidebar-brand">
        <img src="@/assets/AppIcon.png" alt="VeriDose" class="brand-logo" />
      </div>

      <nav class="sidebar-nav">
        <RouterLink to="/home"     class="nav-item" :class="{ active: isActive('/home') }"     title="Home"     data-cy="nav-home">
          <span class="icon" v-html="homeIcon"></span>
        </RouterLink>
        <RouterLink to="/patients" class="nav-item" :class="{ active: isActive('/patients') }" title="Patients" data-cy="nav-patients">
          <span class="icon" v-html="listIcon"></span>
        </RouterLink>
        <RouterLink to="/settings" class="nav-item" :class="{ active: isActive('/settings') }" title="Settings" data-cy="nav-settings">
          <span class="icon" v-html="settingsIcon"></span>
        </RouterLink>
      </nav>

      <div class="sidebar-footer">
        <button class="nav-item logout-btn" @click="handleLogout" title="Logout" data-cy="nav-logout">
          <span class="icon" v-html="logOutIcon"></span>
        </button>
      </div>
    </aside>

    <main class="main-content">
      <slot />
    </main>
  </div>
</template>

<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router'
import { logout } from '../stores/auth'
import homeIcon     from '@/assets/home.svg?raw'
import listIcon     from '@/assets/list.svg?raw'
import settingsIcon from '@/assets/settings.svg?raw'
import logOutIcon   from '@/assets/log-out.svg?raw'

const route  = useRoute()
const router = useRouter()

function isActive(path: string): boolean {
  return route.path === path || route.path.startsWith(path + '/')
}

async function handleLogout() {
  await logout()
  router.push('/login')
}
</script>

<style scoped>
.layout {
  display: flex;
  height: 100vh;
  overflow: hidden;
}

.sidebar {
  width: var(--sidebar-w);
  flex-shrink: 0;
  background: var(--card);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 16px 0;
}

.sidebar-brand { padding: 4px 0 0; }
.brand-logo {
  width: 46px;
  height: 46px;
  border-radius: var(--radius-sm);
  object-fit: cover;
  display: block;
}

.sidebar-nav {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  flex: 1;
}

.nav-item {
  width: 46px;
  height: 46px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--radius-sm);
  color: var(--text-light);
  transition: background 0.15s, color 0.15s;
}
.nav-item:hover  { background: var(--surface); color: var(--text-secondary); }
.nav-item.active { background: var(--primary); color: #fff; }

.icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}
.icon :deep(svg) { width: 22px; height: 22px; }

.sidebar-footer {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-bottom: 4px;
}

.logout-btn { color: var(--text-light); }
.logout-btn:hover { background: #FFF1F1; color: var(--missed); }

.main-content {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  display: flex;
  flex-direction: column;
}
</style>
