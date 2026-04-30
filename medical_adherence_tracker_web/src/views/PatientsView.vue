<template>
  <AppLayout>
    <div class="patients-page" data-cy="patients-page">
      <div class="page-header">
        <h2>PATIENT LIST</h2>
        <RouterLink to="/patients/new" class="btn-primary header-btn" data-cy="new-patient-btn">
          <span class="icon" v-html="plusIcon"></span>
          New Patient
        </RouterLink>
      </div>

      <div class="list-card card" data-cy="patient-list">
        <div v-if="loading" class="list-loading">
          <div class="spinner"></div>
        </div>

        <div v-else-if="patients.length === 0" class="list-empty" data-cy="empty-state">
          <span class="empty-icon" v-html="usersIcon"></span>
          <p>No patients assigned yet.</p>
        </div>

        <template v-else>
          <div v-for="patient in patients" :key="patient.id" class="patient-row" data-cy="patient-row">
            <div class="patient-avatar">
              <img v-if="patient.profile?.avatar_url" :src="patient.profile.avatar_url" :alt="fullName(patient)" />
              <span v-else>{{ initials(patient) }}</span>
            </div>

            <span class="patient-name" data-cy="patient-name">{{ fullName(patient) }}</span>
            <span class="patient-id" data-cy="patient-id-badge">{{ patient.id.slice(0, 8).toUpperCase() }}</span>

            <div class="patient-conditions" data-cy="patient-conditions">
              <span v-for="c in patient.condition.slice(0, 2)" :key="c" class="condition-tag" data-cy="condition-tag">{{ c }}</span>
              <span v-if="patient.condition.length > 2" class="condition-more">+{{ patient.condition.length - 2 }}</span>
            </div>

            <div class="patient-actions">
              <RouterLink :to="`/patients/${patient.id}/adherence`" class="btn-ghost action-btn" data-cy="view-adherence-btn">
                <span class="icon" v-html="activityIcon"></span>
                View Adherence
              </RouterLink>
              <RouterLink :to="`/patients/${patient.id}/plan/new`" class="btn-primary action-btn" data-cy="add-plan-btn">
                <span class="icon" v-html="plusIcon"></span>
                Add Plan
              </RouterLink>
            </div>
          </div>
        </template>
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AppLayout from '../components/AppLayout.vue'
import { currentUser } from '../stores/auth'
import { supabase } from '../supabase'
import type { PatientWithProfile } from '../supabase'
import activityIcon from '@/assets/activity.svg?raw'
import plusIcon     from '@/assets/plus.svg?raw'
import usersIcon    from '@/assets/users.svg?raw'

const loading  = ref(true)
const patients = ref<PatientWithProfile[]>([])

function fullName(p: PatientWithProfile) {
  return `${p.profile?.name ?? ''} ${p.profile?.surname ?? ''}`.trim() || 'Unknown Patient'
}
function initials(p: PatientWithProfile) {
  const n = p.profile?.name?.[0] ?? ''
  const s = p.profile?.surname?.[0] ?? ''
  return (n + s).toUpperCase() || '?'
}

onMounted(async () => {
  if (!currentUser.value) return
  loading.value = true
  try {
    const { data: rawPatients } = await supabase
      .from('patient').select('*').eq('doctor_id', currentUser.value.id).order('id')
    if (!rawPatients || rawPatients.length === 0) { patients.value = []; return }

    const ids = rawPatients.map(p => p.id)
    const { data: profiles } = await supabase
      .from('profile').select('id, name, surname, avatar_url').in('id', ids)

    const profileMap = new Map((profiles ?? []).map(pr => [pr.id, pr]))
    patients.value = rawPatients.map(p => ({
      ...p,
      profile: profileMap.get(p.id) ?? { name: '', surname: '', avatar_url: undefined },
    })) as PatientWithProfile[]

  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.patients-page {
  flex: 1; display: flex; flex-direction: column; padding: 28px; gap: 20px;
}
.page-header {
  display: flex; align-items: center; justify-content: space-between;
}
.page-header h2 { font-size: 20px; font-weight: 700; letter-spacing: 0.04em; }
.header-btn { gap: 6px; }
.header-btn .icon :deep(svg) { width: 15px; height: 15px; }

.list-card { flex: 1; overflow-y: auto; display: flex; flex-direction: column; }

.list-loading, .list-empty {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 12px; padding: 60px 20px; color: var(--text-light); font-size: 14px; flex: 1;
}
.empty-icon { display: flex; }
.empty-icon :deep(svg) { width: 48px; height: 48px; stroke: var(--border); }

.patient-row {
  display: flex; align-items: center; gap: 16px;
  padding: 12px 20px; border-bottom: 1px solid var(--border); transition: background 0.12s;
}
.patient-row:last-child { border-bottom: none; }
.patient-row:hover { background: var(--surface); }

.patient-avatar {
  width: 42px; height: 42px; border-radius: 50%;
  background: var(--primary-dim); color: var(--primary);
  font-size: 14px; font-weight: 700;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; overflow: hidden;
}
.patient-avatar img { width: 100%; height: 100%; object-fit: cover; }

.patient-name { flex: 1; font-size: 14px; font-weight: 600; min-width: 120px; }
.patient-id { font-size: 12px; color: var(--text-light); font-family: monospace; min-width: 80px; }

.patient-conditions { display: flex; gap: 6px; align-items: center; flex: 1; flex-wrap: wrap; }
.condition-tag {
  padding: 3px 10px; background: var(--primary-dim); color: var(--primary);
  border-radius: 100px; font-size: 11px; font-weight: 600;
}
.condition-more { font-size: 11px; color: var(--text-light); }

.patient-actions { display: flex; gap: 8px; flex-shrink: 0; }
.action-btn { font-size: 13px; padding: 8px 14px; gap: 6px; white-space: nowrap; }

.icon { display: inline-flex; align-items: center; justify-content: center; pointer-events: none; }
.icon :deep(svg) { width: 15px; height: 15px; display: block; }
</style>
