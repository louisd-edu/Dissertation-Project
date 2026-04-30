<template>
  <AppLayout>
    <div class="create-plan-page">
      <div class="page-header">
        <button class="back-btn" @click="router.back()">
          <span class="icon" v-html="chevronLeftIcon"></span>
        </button>
        <div>
          <h2>New Medication Plan</h2>
          <p v-if="patientProfile" class="sub-heading">
            For {{ patientProfile.name }} {{ patientProfile.surname }}
          </p>
        </div>
      </div>

      <div class="plan-content">
        <!-- existing plans panel -->
        <div class="existing-panel card">
          <div class="section-title">Existing Plans</div>

          <div v-if="loadingPlans" class="plans-loading">
            <div class="spinner"></div>
          </div>

          <div v-else-if="existingPlans.length === 0" class="plans-empty">
            <span class="empty-icon" v-html="calendarIcon"></span>
            <span>No plans yet</span>
          </div>

          <div v-else class="plans-list">
            <div v-for="plan in existingPlans" :key="plan.id" class="plan-item">
              <div class="plan-item-info">
                <span class="plan-item-name">{{ plan.plan_name }}</span>
                <span class="plan-item-med">{{ plan.name }} · {{ plan.dosage }}{{ plan.units }}</span>
                <span class="plan-item-dates">{{ formatDate(plan.start_date) }} → {{ formatDate(plan.end_date) }}</span>
                <span class="plan-item-freq">{{ formatFreq(plan.frequency) }}</span>
              </div>
              <button
                class="delete-btn"
                @click="deletePlan(plan.id)"
                :disabled="deletingId === plan.id"
                title="Delete plan"
              >
                <span v-if="deletingId !== plan.id" class="icon" v-html="trash2Icon"></span>
                <span v-else class="mini-spinner"></span>
              </button>
            </div>
          </div>
        </div>

        <!-- form -->
        <div class="form-card card">
          <form @submit.prevent="handleSubmit" class="plan-form" data-cy="create-plan-form">

            <fieldset class="form-section">
              <legend>Plan Identity</legend>
              <div class="fields-row">
                <div class="field">
                  <label>Plan Name</label>
                  <input v-model="form.plan_name" type="text" placeholder="e.g. Morning Routine" required data-cy="plan-name-input" />
                </div>
                <div class="field">
                  <label>Medication Name</label>
                  <input v-model="form.name" type="text" placeholder="e.g. Ibuprofen" required data-cy="medication-name-input" />
                </div>
              </div>
            </fieldset>

            <fieldset class="form-section">
              <legend>Dosage</legend>
              <div class="fields-row">
                <div class="field field--sm">
                  <label>Amount</label>
                  <input v-model.number="form.dosage" type="number" min="0.1" step="0.1" placeholder="200" required data-cy="dosage-input" />
                </div>
                <div class="field field--sm">
                  <label>Units</label>
                  <select v-model="form.units" required data-cy="units-select">
                    <option value="">Select…</option>
                    <option value="mg">mg</option>
                    <option value="g">g</option>
                    <option value="ml">ml</option>
                    <option value="tablet">tablet(s)</option>
                    <option value="capsule">capsule(s)</option>
                    <option value="drop">drop(s)</option>
                    <option value="IU">IU</option>
                  </select>
                </div>
                <div class="field field--sm">
                  <label>Time of Day</label>
                  <input v-model="form.time" type="time" required data-cy="time-input" />
                </div>
              </div>
            </fieldset>

            <fieldset class="form-section">
              <legend>Frequency</legend>
              <div class="days-grid">
                <label
                  v-for="day in ALL_DAYS"
                  :key="day.key"
                  class="day-chip"
                  :class="{ selected: isDaySelected(day.key) }"
                  data-cy="day-chip"
                  :data-day="day.key"
                >
                  <input type="checkbox" :value="day.key" style="display:none" @change="toggleDay(day.key)" />
                  {{ day.label }}
                </label>
              </div>
              <p v-if="form.frequency.length === 0" class="freq-hint" data-cy="freq-hint">Select at least one day.</p>
            </fieldset>

            <fieldset class="form-section">
              <legend>Date Range</legend>
              <div class="fields-row">
                <div class="field">
                  <label>Start Date</label>
                  <input v-model="form.start_date" type="date" required data-cy="start-date-input" />
                </div>
                <div class="field">
                  <label>End Date</label>
                  <input v-model="form.end_date" type="date" required :min="form.start_date" data-cy="end-date-input" />
                </div>
              </div>
              <p v-if="estimatedDoses > 0" class="dose-estimate" data-cy="dose-estimate">
                Approximately <strong>{{ estimatedDoses }}</strong> dose{{ estimatedDoses !== 1 ? 's' : '' }} will be scheduled.
              </p>
            </fieldset>

            <div v-if="errorMsg"   class="error-msg"   data-cy="error-message">{{ errorMsg }}</div>
            <div v-if="successMsg" class="success-msg" data-cy="success-message">
              <span class="icon" v-html="checkIcon"></span>
              {{ successMsg }}
            </div>

            <div class="form-actions">
              <button type="submit" class="btn-primary" :disabled="submitting || form.frequency.length === 0" data-cy="submit-plan-btn">
                <span v-if="submitting" class="btn-spinner"></span>
                {{ submitting ? 'Creating…' : 'Create Plan' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppLayout from '../components/AppLayout.vue'
import { currentUser } from '../stores/auth'
import { supabase } from '../supabase'
import type { Profile, MedicationPlan } from '../supabase'
import chevronLeftIcon from '@/assets/chevron-left.svg?raw'
import trash2Icon      from '@/assets/trash-2.svg?raw'
import calendarIcon    from '@/assets/calendar.svg?raw'
import checkIcon       from '@/assets/check.svg?raw'

const route     = useRoute()
const router    = useRouter()
const patientId = route.params.id as string

const ALL_DAYS = [
  { key: 'daily', label: 'Everyday' },
  { key: 'mo',    label: 'Mon' },
  { key: 'tu',    label: 'Tue' },
  { key: 'we',    label: 'Wed' },
  { key: 'th',    label: 'Thu' },
  { key: 'fr',    label: 'Fri' },
  { key: 'sa',    label: 'Sat' },
  { key: 'su',    label: 'Sun' },
]

const patientProfile = ref<Profile | null>(null)
const existingPlans  = ref<MedicationPlan[]>([])
const loadingPlans   = ref(true)
const deletingId     = ref<string | null>(null)
const submitting     = ref(false)
const errorMsg       = ref('')
const successMsg     = ref('')

const form = ref({
  plan_name:  '',
  name:       '',
  dosage:     200,
  units:      'mg',
  time:       '08:00',
  start_date: new Date().toISOString().slice(0,10),
  end_date:   '',
  frequency:  [] as string[],
})

function isDaySelected(key: string): boolean {
  if (key === 'daily') return form.value.frequency.includes('daily')
  return form.value.frequency.includes('daily') || form.value.frequency.includes(key)
}

function toggleDay(key: string) {
  if (key === 'daily') {
    form.value.frequency = form.value.frequency.includes('daily') ? [] : ['daily']
    return
  }
  const hadDaily = form.value.frequency.includes('daily')
  if (hadDaily) {
    form.value.frequency = ['mo','tu','we','th','fr','sa','su'].filter(d => d !== key)
    return
  }
  const idx = form.value.frequency.indexOf(key)
  if (idx === -1) form.value.frequency.push(key)
  else            form.value.frequency.splice(idx, 1)
}

function formatDate(d: string) {
  return new Date(d).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' })
}
function formatFreq(freq: string[]) {
  if (freq.includes('daily')) return 'Every day'
  return freq.map(d => d.slice(0,3).charAt(0).toUpperCase() + d.slice(1,3)).join(', ')
}

const estimatedDoses = computed(() => {
  if (!form.value.start_date || !form.value.end_date) return 0
  const start = new Date(form.value.start_date)
  const end   = new Date(form.value.end_date)
  if (end < start) return 0
  const totalDays = Math.round((end.getTime() - start.getTime()) / 86400000) + 1
  if (form.value.frequency.includes('daily')) return totalDays
  const freqDays = form.value.frequency.length
  const weeks    = Math.floor(totalDays / 7)
  const rem      = totalDays % 7
  const startDay = start.getDay()
  const dayIndexMap: Record<string,number> = { sunday:0, monday:1, tuesday:2, wednesday:3, thursday:4, friday:5, saturday:6 }
  let extra = 0
  for (const dk of form.value.frequency) {
    if (((dayIndexMap[dk] ?? 0) - startDay + 7) % 7 < rem) extra++
  }
  return weeks * freqDays + extra
})


async function deletePlan(planId: string) {
  if (!confirm('Delete this plan and all its scheduled doses?')) return
  deletingId.value = planId
  try {
    await supabase.from('dose').delete().eq('plan_id', planId)
    await supabase.from('medication_plan').delete().eq('id', planId)
    existingPlans.value = existingPlans.value.filter(p => p.id !== planId)
  } finally { deletingId.value = null }
}

function supaErr(e: { message?: string; code?: string } | null | undefined): string {
  if (!e) return 'Unknown error'
  return e.code ? `${e.message} (code: ${e.code})` : (e.message ?? 'Unknown error')
}

async function handleSubmit() {
  if (!currentUser.value) { errorMsg.value = 'Not logged in. Please refresh and try again.'; return }
  if (form.value.frequency.length === 0) { errorMsg.value = 'Please select at least one day.'; return }
  submitting.value = true; errorMsg.value = ''; successMsg.value = ''
  try {
    const planId = crypto.randomUUID()
    const { error: planErr } = await supabase
      .from('medication_plan')
      .insert({
        id: planId,
        plan_name: form.value.plan_name,
        name: form.value.name,
        dosage: Math.round(form.value.dosage),
        units: form.value.units,
        frequency: form.value.frequency.includes('daily') ? ['mo','tu','we','th','fr','sa','su'] : form.value.frequency,
        time: form.value.time,
        start_date: form.value.start_date,
        end_date: form.value.end_date,
        patient_id: patientId,
        doctor_id: currentUser.value.id,
      })
    if (planErr) throw new Error(`${planErr.message} (code: ${planErr.code})`)
    successMsg.value = 'Plan created successfully.'
    const newPlan: MedicationPlan = {
      id: planId,
      plan_name: form.value.plan_name, name: form.value.name,
      dosage: form.value.dosage, units: form.value.units,
      frequency: [...form.value.frequency], time: form.value.time,
      start_date: form.value.start_date, end_date: form.value.end_date,
      patient_id: patientId, doctor_id: currentUser.value.id,
    }
    existingPlans.value.unshift(newPlan)
    setTimeout(() => router.push(`/patients/${patientId}/adherence`), 1500)
  } catch (e: unknown) {
    errorMsg.value = e instanceof Error ? e.message : 'Something went wrong.'
    console.error('[CreatePlan]', e)
  } finally {
    submitting.value = false
  }
}

onMounted(async () => {
  try {
    const [profileRes, plansRes] = await Promise.all([
      supabase.from('profile').select('*').eq('id', patientId).single(),
      supabase.from('medication_plan').select('*').eq('patient_id', patientId).order('start_date', { ascending: false }),
    ])
    patientProfile.value = profileRes.data as Profile
    existingPlans.value  = (plansRes.data ?? []) as MedicationPlan[]
  } finally {
    loadingPlans.value = false
  }
})
</script>

<style scoped>
.create-plan-page {
  flex: 1; display: flex; flex-direction: column;
  padding: 24px 28px; gap: 20px; min-height: 0; overflow: hidden;
}

.page-header { display: flex; align-items: center; gap: 14px; flex-shrink: 0; }
.back-btn {
  width: 36px; height: 36px; border-radius: 50%;
  border: 1.5px solid var(--border);
  display: flex; align-items: center; justify-content: center;
  color: var(--text-secondary); flex-shrink: 0; transition: all 0.15s;
}
.back-btn:hover { border-color: var(--primary); color: var(--primary); }
.back-btn .icon :deep(svg) { width: 18px; height: 18px; }
.page-header h2  { font-size: 20px; font-weight: 700; }
.sub-heading { font-size: 13px; color: var(--text-secondary); margin-top: 2px; }

.plan-content { display: flex; gap: 20px; flex: 1; min-height: 0; align-items: flex-start; }

/* Left panel */
.existing-panel {
  width: 260px; flex-shrink: 0;
  padding: 20px; display: flex; flex-direction: column; gap: 12px;
  max-height: 100%; overflow-y: auto;
}
.section-title {
  font-size: 11px; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.08em;
  color: var(--text-secondary);
  padding-bottom: 10px; border-bottom: 1.5px solid var(--border); flex-shrink: 0;
}
.plans-loading, .plans-empty {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 8px; padding: 24px 0; color: var(--text-light); font-size: 13px; text-align: center;
}
.empty-icon { display: flex; }
.empty-icon :deep(svg) { width: 32px; height: 32px; stroke: var(--border); }

.plans-list { display: flex; flex-direction: column; gap: 10px; }
.plan-item {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 10px 12px; background: var(--surface);
  border-radius: var(--radius-sm); border: 1px solid var(--border);
}
.plan-item-info { flex: 1; display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.plan-item-name  { font-size: 13px; font-weight: 700; color: var(--text-primary); }
.plan-item-med   { font-size: 12px; color: var(--text-secondary); }
.plan-item-dates { font-size: 11px; color: var(--text-light); }
.plan-item-freq  {
  font-size: 10px; font-weight: 600; color: var(--primary);
  background: var(--primary-dim); border-radius: 100px;
  padding: 1px 8px; display: inline-block; margin-top: 2px; width: fit-content;
}
.delete-btn {
  width: 28px; height: 28px; border-radius: 6px;
  border: 1.5px solid var(--border);
  display: flex; align-items: center; justify-content: center;
  color: var(--text-light); flex-shrink: 0; transition: all 0.15s;
}
.delete-btn:hover:not(:disabled) { border-color: var(--missed); color: var(--missed); background: #FFF1F1; }
.delete-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.delete-btn .icon :deep(svg) { width: 15px; height: 15px; }
.mini-spinner {
  width: 12px; height: 12px;
  border: 2px solid var(--border); border-top-color: var(--missed);
  border-radius: 50%; animation: spin 0.7s linear infinite;
}

/* Right form */
.form-card { flex: 1; padding: 24px 28px; overflow-y: auto; max-height: 100%; }
.plan-form { display: flex; flex-direction: column; gap: 24px; }

fieldset { border: none; padding: 0; }
legend {
  font-size: 11px; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.08em;
  color: var(--text-secondary);
  margin-bottom: 14px; padding-bottom: 8px;
  border-bottom: 1.5px solid var(--border); width: 100%;
}
.fields-row { display: flex; gap: 16px; flex-wrap: wrap; }
.field { display: flex; flex-direction: column; gap: 6px; flex: 1; min-width: 140px; }
.field--sm { flex: 0 0 110px; min-width: 90px; }
.field label {
  font-size: 11px; font-weight: 600;
  color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.05em;
}
.field input, .field select {
  padding: 10px 12px; border: 1.5px solid var(--border);
  border-radius: var(--radius-sm); font-size: 14px;
  color: var(--text-primary); background: var(--surface);
  outline: none; transition: border-color 0.15s;
}
.field input:focus, .field select:focus { border-color: var(--primary); background: #fff; }

.days-grid { display: flex; gap: 8px; flex-wrap: wrap; justify-content: center; }
.day-chip {
  padding: 8px 16px; border-radius: 100px;
  border: 1.5px solid var(--border);
  font-size: 13px; font-weight: 600; color: var(--text-secondary);
  cursor: pointer; transition: all 0.15s; user-select: none;
}
.day-chip.selected { background: var(--primary); border-color: var(--primary); color: #fff; }
.day-chip:hover:not(.selected) { border-color: var(--primary); color: var(--primary); }

.freq-hint  { font-size: 12px; color: var(--missed); margin-top: 8px; text-align: center; }
.dose-estimate { margin-top: 10px; font-size: 13px; color: var(--text-secondary); }
.dose-estimate strong { color: var(--primary); }

.error-msg {
  padding: 12px 16px; background: #FFF1F1; border: 1px solid #FFD0D0;
  border-radius: var(--radius-sm); color: var(--missed); font-size: 13px;
}
.success-msg {
  display: flex; align-items: center; gap: 8px;
  padding: 12px 16px;
  background: rgba(52,199,89,0.1); border: 1px solid rgba(52,199,89,0.3);
  border-radius: var(--radius-sm); color: #1a8c38; font-size: 13px; font-weight: 500;
}
.success-msg .icon :deep(svg) { width: 16px; height: 16px; }

.form-actions {
  display: flex; justify-content: flex-end; gap: 12px;
  padding-top: 8px; border-top: 1px solid var(--border);
}

.icon { display: inline-flex; align-items: center; justify-content: center; pointer-events: none; }
.icon :deep(svg) { width: 22px; height: 22px; display: block; }

.btn-spinner {
  width: 15px; height: 15px;
  border: 2px solid rgba(255,255,255,0.4); border-top-color: #fff;
  border-radius: 50%; animation: spin 0.7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
</style>
