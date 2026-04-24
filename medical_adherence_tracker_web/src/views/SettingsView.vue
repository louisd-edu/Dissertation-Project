<template>
  <AppLayout>
    <div class="settings-page">
      <div class="settings-grid">
        <!-- Profile card -->
        <div class="card profile-card">
          <div class="section-title">Profile</div>
          <div class="profile-row">
            <div class="profile-avatar">
              <img v-if="currentUser?.avatar_url" :src="currentUser.avatar_url" alt="" />
              <span v-else>{{ initials }}</span>
            </div>
            <div class="profile-info">
              <span class="profile-name">{{ fullName }}</span>
              <span class="profile-role">Doctor</span>
            </div>
          </div>
          <div class="info-rows">
            <div class="info-row">
              <span class="info-label">Name</span>
              <span class="info-value">{{ currentUser?.name ?? '—' }}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Surname</span>
              <span class="info-value">{{ currentUser?.surname ?? '—' }}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Role</span>
              <span class="info-value role-badge">{{ currentUser?.role ?? '—' }}</span>
            </div>
          </div>
        </div>

        <!-- Account card -->
        <div class="card actions-card">
          <div class="section-title">Account</div>
          <div class="action-item">
            <div class="action-info">
              <span class="action-label">Sign out</span>
              <span class="action-sub">You will be returned to the login screen.</span>
            </div>
            <button class="logout-btn btn-ghost" @click="handleLogout">
              <span class="icon" v-html="logOutIcon"></span>
              Sign Out
            </button>
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import AppLayout from '../components/AppLayout.vue'
import { currentUser, logout } from '../stores/auth'
import logOutIcon from '@/assets/log-out.svg?raw'

const router = useRouter()

const fullName = computed(() =>
  `${currentUser.value?.name ?? ''} ${currentUser.value?.surname ?? ''}`.trim() || '—'
)
const initials = computed(() => {
  if (!currentUser.value) return '?'
  return `${currentUser.value.name?.[0] ?? ''}${currentUser.value.surname?.[0] ?? ''}`.toUpperCase()
})

async function handleLogout() {
  await logout()
  router.push('/login')
}
</script>

<style scoped>
.settings-page {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 28px;
}

.settings-grid {
  width: 100%;
  max-width: 520px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.section-title {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-secondary);
  margin-bottom: 16px;
  padding-bottom: 10px;
  border-bottom: 1.5px solid var(--border);
}

.profile-card, .actions-card { padding: 20px 24px; }

.profile-row {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 20px;
}
.profile-avatar {
  width: 56px; height: 56px;
  border-radius: 50%;
  background: var(--primary-dim);
  color: var(--primary);
  font-size: 18px;
  font-weight: 700;
  display: flex; align-items: center; justify-content: center;
  overflow: hidden;
  flex-shrink: 0;
}
.profile-avatar img { width: 100%; height: 100%; object-fit: cover; }
.profile-name { font-size: 16px; font-weight: 700; display: block; }
.profile-role { font-size: 12px; color: var(--text-secondary); text-transform: capitalize; }

.info-rows { display: flex; flex-direction: column; }
.info-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 0;
  border-bottom: 1px solid var(--surface);
  font-size: 14px;
}
.info-row:last-child { border-bottom: none; }
.info-label { color: var(--text-secondary); font-weight: 500; }
.info-value { font-weight: 600; color: var(--text-primary); }
.role-badge {
  padding: 3px 10px;
  background: var(--primary-dim);
  color: var(--primary);
  border-radius: 100px;
  font-size: 12px;
  text-transform: capitalize;
}

.action-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}
.action-label { font-size: 14px; font-weight: 600; display: block; }
.action-sub { font-size: 12px; color: var(--text-secondary); margin-top: 2px; display: block; }
.logout-btn {
  border-color: #FFD0D0;
  color: var(--missed);
  flex-shrink: 0;
  gap: 6px;
}
.logout-btn:hover { background: #FFF1F1; border-color: var(--missed); }

.icon { display: inline-flex; align-items: center; justify-content: center; pointer-events: none; }
.icon :deep(svg) { width: 16px; height: 16px; display: block; }
</style>
