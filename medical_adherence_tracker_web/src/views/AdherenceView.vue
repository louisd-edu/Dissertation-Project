<template>
  <AppLayout>
    <div class="adherence-page">
      <!-- Header -->
      <div class="adh-header">
        <div class="adh-title">
          <button class="back-btn" @click="router.push('/patients')">
            <span class="icon" v-html="chevronLeftIcon"></span>
          </button>
          <span class="patient-heading" v-if="profile">
            {{ profile.name }} {{ profile.surname }}
            <span class="patient-id-label">| {{ patientId.slice(0,8).toUpperCase() }}</span>
          </span>
          <span v-else class="patient-heading">Loading…</span>
        </div>
        <RouterLink :to="`/patients/${patientId}/plan/new`" class="btn-primary add-plan-btn">
          <span class="icon" v-html="plusIcon"></span>
          Add Medication Plan
        </RouterLink>
      </div>

      <div class="adh-body">
        <!-- Left panel -->
        <div class="adh-left">
          <div class="card patient-info-card">
            <div class="pi-avatar">
              <img v-if="profile?.avatar_url" :src="profile.avatar_url" alt="" />
              <span v-else>{{ profileInitials }}</span>
            </div>
            <div class="pi-name">{{ profile ? `${profile.name} ${profile.surname}` : '—' }}</div>
            <div v-if="patient" class="pi-conditions">
              <span v-for="c in patient.condition" :key="c" class="condition-tag">{{ c }}</span>
            </div>
          </div>

          <div class="card stat-card">
            <span class="stat-section-title">Monthly Adherence</span>
            <DonutChart :percentage="monthlyAdherencePct" :size="120" color="#34C759">
              <span class="donut-pct-sm">{{ monthlyAdherencePct }}%</span>
            </DonutChart>

            <div class="stat-section-title" style="margin-top:16px">Monthly Stats</div>
            <div class="stat-rows">
              <div class="stat-row">
                <span class="stat-label-text">Taken</span>
                <span class="badge badge--taken">{{ monthStats.taken }}</span>
              </div>
              <div class="stat-row">
                <span class="stat-label-text">Late</span>
                <span class="badge badge--late">{{ monthStats.late }}</span>
              </div>
              <div class="stat-row">
                <span class="stat-label-text">Skipped</span>
                <span class="badge badge--skipped">{{ monthStats.skipped }}</span>
              </div>
              <div class="stat-row">
                <span class="stat-label-text">Missed</span>
                <span class="badge badge--missed">{{ monthStats.missed }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- calendar + legend -->
        <div class="adh-right card">
          <div class="cal-toolbar">
            <span class="cal-range">{{ calMonthLabel }}</span>
            <div class="cal-nav">
              <button class="cal-nav-btn" @click="shiftMonth(-1)">
                <span class="icon" v-html="chevronLeftIcon"></span>
              </button>
              <button class="cal-nav-btn" @click="shiftMonth(1)" :disabled="isCurrentMonth">
                <span class="icon" v-html="chevronRightIcon"></span>
              </button>
            </div>
          </div>

          <div v-if="loadingDoses" class="cal-loading">
            <div class="spinner"></div>
          </div>

          <div v-else class="cal-body">
            <div
              v-for="row in calRows"
              :key="row.date"
              class="cal-row"
              :class="{ 'cal-row--today': row.isToday }"
            >
              <span class="cal-date-label" :class="{ 'today-label': row.isToday }">{{ row.label }}</span>
              <div class="cal-doses">
                <div
                  v-for="dose in row.doses"
                  :key="dose.id"
                  class="dose-bar"
                  :class="[`dose-bar--${dose.status}`, { 'dose-bar--has-media': dose.media_url }]"
                  @mouseenter="onDoseHover($event, dose)"
                  @mouseleave="tooltip.visible = false"
                  @click="dose.media_url ? openMedia(dose) : undefined"
                ></div>
                <span v-if="row.doses.length === 0" class="no-doses">—</span>
              </div>
            </div>
          </div>

          <!-- Legend pinned inside the calendar card -->
          <div class="legend">
            <span class="legend-item"><span class="legend-dot" style="background:var(--success)"></span>TAKEN</span>
            <span class="legend-item"><span class="legend-dot" style="background:var(--late)"></span>LATE</span>
            <span class="legend-item"><span class="legend-dot" style="background:var(--skipped)"></span>SKIPPED</span>
            <span class="legend-item"><span class="legend-dot" style="background:var(--missed)"></span>MISSED</span>
            <span class="legend-item"><span class="legend-dot video-dot"></span>HAS VIDEO FOOTAGE</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Tooltip -->
    <Teleport to="body">
      <div
        v-if="tooltip.visible"
        class="dose-tooltip"
        :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }"
      >
        <div class="tt-date">{{ tooltip.date }}</div>
        <div class="tt-med">{{ tooltip.med }}</div>
        <div class="tt-time">Scheduled: {{ tooltip.time }}</div>
        <div v-if="tooltip.takenAt" class="tt-time">Taken at: {{ tooltip.takenAt }}</div>
        <div class="tt-status" :class="`tt-status--${tooltip.status}`">{{ tooltip.statusLabel }}</div>
      </div>
    </Teleport>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppLayout from '../components/AppLayout.vue'
import DonutChart from '../components/DonutChart.vue'
import { supabase, STATUS_LABELS } from '../supabase'
import type { Profile, Patient, Dose, MedicationPlan } from '../supabase'
import chevronLeftIcon  from '@/assets/chevron-left.svg?raw'
import chevronRightIcon from '@/assets/chevron-right.svg?raw'
import plusIcon         from '@/assets/plus.svg?raw'

const route = useRoute()
const router = useRouter()
const patientId = route.params.id as string

const profile     = ref<Profile | null>(null)
const patient     = ref<Patient | null>(null)
const plans       = ref<MedicationPlan[]>([])
const allDoses    = ref<(Dose & { medication_name: string })[]>([])
const loadingDoses = ref(true)

// Calendar navigation
const viewDate = ref(new Date())
const calYear  = computed(() => viewDate.value.getFullYear())
const calMonth = computed(() => viewDate.value.getMonth())

const calStart = computed(() => new Date(calYear.value, calMonth.value, 1))
const calEnd   = computed(() => new Date(calYear.value, calMonth.value + 1, 0))

const isCurrentMonth = computed(() => {
  const now = new Date()
  return calYear.value === now.getFullYear() && calMonth.value === now.getMonth()
})

const calMonthLabel = computed(() =>
  viewDate.value.toLocaleString('en-GB', { month: 'long', year: 'numeric' })
)

function shiftMonth(delta: number) {
  const d = new Date(viewDate.value)
  d.setMonth(d.getMonth() + delta)
  viewDate.value = d
}

// Local date string (YYYY‑MM‑DD) using browser timezone avoids UTC slice bug
function localDateStr(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
}

const DAY_NAMES = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday']

// Missing slots in the past become 'missed', future ones 'scheduled'.
const displayDoses = computed(() => {
  type D = Dose & { medication_name: string }

  const realKeys = new Set<string>()
  for (const d of allDoses.value) {
    realKeys.add(`${d.plan_id}|${localDateStr(new Date(d.scheduled_for))}`)
  }

  const virtual: D[] = []
  const todayStr = localDateStr(new Date())

  for (const plan of plans.value) {
    if (!plan.time || !plan.start_date || !plan.end_date) continue
    const freqArr = Array.isArray(plan.frequency) ? plan.frequency : []
    if (!freqArr.length) continue

    const planStart  = new Date(plan.start_date + 'T00:00:00')
    const planEnd    = new Date(plan.end_date   + 'T23:59:59')
    const monthFirst = new Date(calStart.value)
    const monthLast  = new Date(calEnd.value)

    const genStart = planStart > monthFirst ? planStart : monthFirst
    const genEnd   = planEnd   < monthLast  ? planEnd   : monthLast
    if (genStart > genEnd) continue

    const freqLower = freqArr.map((f: string) => f.toLowerCase())
    const isDaily   = freqLower.includes('daily') || freqLower.includes('everyday')

    const cur = new Date(genStart)
    while (cur <= genEnd) {
      const dateStr = localDateStr(cur)
      if (isDaily || freqLower.includes(DAY_NAMES[cur.getDay()])) {
        const key = `${plan.id}|${dateStr}`
        if (!realKeys.has(key) && dateStr <= todayStr) {
          virtual.push({
            id:             `virtual|${plan.id}|${dateStr}`,
            plan_id:        plan.id,
            status:         'missed',
            scheduled_for:  `${dateStr}T${plan.time.slice(0, 5)}:00`,
            taken_at:       null,
            medication_name: plan.name,
          } as D)
        }
      }
      cur.setDate(cur.getDate() + 1)
    }
  }

  return [...allDoses.value, ...virtual]
})

const profileInitials = computed(() => {
  if (!profile.value) return '?'
  return `${profile.value.name?.[0] ?? ''}${profile.value.surname?.[0] ?? ''}`.toUpperCase()
})

const calRows = computed(() => {
  const rows: { date: string; label: string; isToday: boolean; doses: (Dose & { medication_name: string })[] }[] = []
  const todayStr = localDateStr(new Date())
  const d = new Date(calStart.value)
  const end = new Date(calEnd.value)
  while (d <= end) {
    const dateStr = localDateStr(d)
    rows.push({
      date:    dateStr,
      label:   d.toLocaleDateString('en-GB', { day:'2-digit', month:'2-digit', year:'2-digit' }),
      isToday: dateStr === todayStr,
      doses:   displayDoses.value.filter(dose => localDateStr(new Date(dose.scheduled_for)) === dateStr),
    })
    d.setDate(d.getDate() + 1)
  }
  return rows.reverse()
})

// Stats reflect viewed month
const monthStats = computed(() => {
  const mStart = new Date(calYear.value, calMonth.value, 1).getTime()
  const mEnd   = new Date(calYear.value, calMonth.value + 1, 0, 23, 59, 59, 999).getTime()
  const s = { taken:0, late:0, skipped:0, missed:0 }
  for (const d of displayDoses.value) {
    const t = new Date(d.scheduled_for).getTime()
    if (t < mStart || t > mEnd) continue
    if      (d.status === 'taken')   s.taken++
    else if (d.status === 'late')    s.late++
    else if (d.status === 'skipped') s.skipped++
    else if (d.status === 'missed')  s.missed++
  }
  return s
})

const monthlyAdherencePct = computed(() => {
  const now    = new Date()
  const mStart = new Date(calYear.value, calMonth.value, 1).getTime()
  const mEnd   = new Date(calYear.value, calMonth.value + 1, 0, 23, 59, 59, 999).getTime()
  const cutoff = isCurrentMonth.value ? now.getTime() : mEnd
  let adherent = 0, total = 0
  for (const d of displayDoses.value) {
    const t = new Date(d.scheduled_for).getTime()
    if (t < mStart || t > mEnd) continue
    if (t > cutoff) continue
    total++
    if (d.status === 'taken' || d.status === 'late') adherent++
  }
  return total === 0 ? 0 : Math.round((adherent / total) * 100)
})

const tooltip = ref({ visible: false, x: 0, y: 0, date: '', med: '', time: '', takenAt: '', status: '', statusLabel: '' })

function onDoseHover(e: MouseEvent, dose: Dose & { medication_name: string }) {
  const rect = (e.target as HTMLElement).getBoundingClientRect()
  tooltip.value = {
    visible: true, x: rect.left + window.scrollX, y: rect.top + window.scrollY - 95,
    date: new Date(dose.scheduled_for).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' }),
    med: dose.medication_name,
    time: new Date(dose.scheduled_for).toLocaleTimeString('en-GB', { hour:'2-digit', minute:'2-digit' }),
    takenAt: dose.taken_at
      ? new Date(dose.taken_at).toLocaleTimeString('en-GB', { hour:'2-digit', minute:'2-digit' })
      : '',
    status: dose.status, statusLabel: STATUS_LABELS[dose.status] ?? dose.status,
  }
}

async function openMedia(dose: Dose & { medication_name: string }) {
  if (!dose.media_url) return
  if (dose.media_url.startsWith('http')) {
    window.open(dose.media_url, '_blank', 'noopener')
    return
  }
  const { data, error } = await supabase.storage
    .from('intake-media')
    .createSignedUrl(dose.media_url, 3600)
  if (data?.signedUrl) {
    window.open(data.signedUrl, '_blank', 'noopener')
  } else {
    console.error('Could not get signed URL:', error)
  }
}

onMounted(async () => {
  loadingDoses.value = true
  try {
    const [profileRes, patientRes] = await Promise.all([
      supabase.from('profile').select('*').eq('id', patientId).single(),
      supabase.from('patient').select('*').eq('id', patientId).single(),
    ])
    profile.value = profileRes.data as Profile
    patient.value = patientRes.data as Patient

    const { data: plansData } = await supabase.from('medication_plan').select('*').eq('patient_id', patientId)
    plans.value = (plansData ?? []) as MedicationPlan[]

    if (plans.value.length > 0) {
      const planIds = plans.value.map(p => p.id)
      const planMap = new Map(plans.value.map(p => [p.id, p]))
      const { data: dosesData } = await supabase
        .from('dose').select('*').in('plan_id', planIds).order('scheduled_for', { ascending: true })
      allDoses.value = (dosesData ?? []).map(d => ({
        ...d, medication_name: planMap.get(d.plan_id)?.name ?? 'Unknown',
      })) as (Dose & { medication_name: string })[]
    }
  } finally { loadingDoses.value = false }
})
</script>

<style scoped>
.adherence-page {
  flex: 1; display: flex; flex-direction: column;
  padding: 24px 28px; gap: 20px; min-height: 0; overflow: hidden;
}

.adh-header {
  display: flex; align-items: center; justify-content: space-between;
  gap: 16px; flex-shrink: 0;
}
.adh-title { display: flex; align-items: center; gap: 10px; }

.back-btn {
  width: 34px; height: 34px; border-radius: 50%;
  border: 1.5px solid var(--border);
  display: flex; align-items: center; justify-content: center;
  color: var(--text-secondary); transition: all 0.15s;
}
.back-btn:hover { border-color: var(--primary); color: var(--primary); }
.back-btn .icon :deep(svg) { width: 18px; height: 18px; }

.patient-heading { font-size: 18px; font-weight: 700; }
.patient-id-label { color: var(--text-secondary); font-weight: 500; font-size: 15px; }

.add-plan-btn { gap: 8px; }
.add-plan-btn .icon :deep(svg) { width: 16px; height: 16px; }

.icon { display: inline-flex; align-items: center; justify-content: center; pointer-events: none; }
.icon :deep(svg) { width: 16px; height: 16px; display: block; }

.adh-body { display: flex; gap: 20px; flex: 1; min-height: 0; }

.adh-left {
  width: 220px; flex-shrink: 0;
  display: flex; flex-direction: column; gap: 16px; overflow-y: auto;
}

.patient-info-card {
  padding: 20px 16px; flex-shrink: 0;
  display: flex; flex-direction: column; align-items: center; gap: 8px; text-align: center;
}
.pi-avatar {
  width: 60px; height: 60px; border-radius: 50%;
  background: var(--primary-dim); color: var(--primary);
  font-size: 20px; font-weight: 700;
  display: flex; align-items: center; justify-content: center; overflow: hidden;
}
.pi-avatar img { width: 100%; height: 100%; object-fit: cover; }
.pi-name { font-size: 14px; font-weight: 700; }
.pi-conditions { display: flex; flex-wrap: wrap; gap: 4px; justify-content: center; }
.condition-tag {
  padding: 2px 8px; background: var(--primary-dim); color: var(--primary);
  border-radius: 100px; font-size: 10px; font-weight: 600;
}

.stat-card {
  padding: 20px 16px; flex-shrink: 0;
  display: flex; flex-direction: column; align-items: center; gap: 10px;
}
.stat-section-title {
  font-size: 12px; font-weight: 600; color: var(--text-secondary);
  text-transform: uppercase; letter-spacing: 0.06em; align-self: flex-start;
}
.donut-pct-sm { font-size: 20px; font-weight: 700; color: var(--text-primary); }
.stat-rows { width: 100%; display: flex; flex-direction: column; gap: 8px; }
.stat-row {
  display: flex; align-items: center; justify-content: space-between;
  padding: 6px 10px; background: var(--surface); border-radius: 8px;
}
.stat-label-text { font-size: 13px; font-weight: 500; color: var(--text-secondary); }

.adh-right { flex: 1; display: flex; flex-direction: column; overflow: hidden; min-height: 0; }

.cal-toolbar {
  display: flex; align-items: center; justify-content: space-between;
  padding: 14px 20px; border-bottom: 1px solid var(--border); flex-shrink: 0;
}
.cal-range { font-size: 13px; font-weight: 600; color: var(--text-secondary); }
.cal-nav { display: flex; gap: 4px; }
.cal-nav-btn {
  width: 30px; height: 30px; border-radius: 50%;
  border: 1.5px solid var(--border);
  display: flex; align-items: center; justify-content: center;
  color: var(--text-secondary); transition: all 0.15s;
}
.cal-nav-btn:hover:not(:disabled) { border-color: var(--primary); color: var(--primary); }
.cal-nav-btn:disabled { opacity: 0.4; cursor: not-allowed; }

.cal-loading { display: flex; align-items: center; justify-content: center; flex: 1; padding: 40px; }
.cal-body { flex: 1; overflow-y: auto; padding: 8px 0; }

.cal-row {
  display: flex; align-items: center; gap: 12px;
  padding: 5px 20px; border-radius: 8px; margin: 1px 8px; transition: background 0.1s;
}
.cal-row:hover { background: var(--surface); }
.cal-row--today { background: rgba(59,111,232,0.05); }

.cal-date-label {
  font-size: 12px; color: var(--text-secondary);
  width: 80px; flex-shrink: 0; font-variant-numeric: tabular-nums;
}
.today-label { color: var(--primary); font-weight: 700; }

.cal-doses { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
.dose-bar {
  height: 18px; width: 72px; border-radius: 100px;
  cursor: pointer; transition: transform 0.1s, opacity 0.1s; flex-shrink: 0;
}
.dose-bar:hover { transform: scaleY(1.2); opacity: 0.85; }
.dose-bar--taken    { background: var(--success); }
.dose-bar--late     { background: var(--late); }
.dose-bar--skipped  { background: var(--skipped); }
.dose-bar--missed   { background: var(--missed); }
.dose-bar--scheduled { background: #D1D5DB; }
.dose-bar--has-media {
  outline: 2px dashed var(--primary);
  outline-offset: -2px;
  cursor: pointer;
}
.no-doses { font-size: 12px; color: var(--border); }

.legend {
  flex-shrink: 0; display: flex; align-items: center; gap: 16px;
  padding: 10px 20px; border-top: 1px solid var(--border); flex-wrap: wrap;
}
.legend-item {
  display: flex; align-items: center; gap: 6px;
  font-size: 11px; font-weight: 600; color: var(--text-secondary); letter-spacing: 0.04em;
}
.legend-dot { width: 14px; height: 14px; border-radius: 3px; flex-shrink: 0; }
.video-dot { background: transparent; border: 2px dashed var(--primary); }

.dose-tooltip {
  position: absolute; z-index: 9999;
  background: var(--text-primary); color: #fff;
  border-radius: 8px; padding: 8px 12px;
  font-size: 12px; pointer-events: none;
  box-shadow: var(--shadow-md); white-space: nowrap; transform: translateX(-50%);
}
.tt-date  { font-size: 10px; opacity: 0.7; margin-bottom: 2px; }
.tt-med   { font-weight: 700; }
.tt-time  { opacity: 0.8; margin-bottom: 4px; }
.tt-status { font-size: 10px; font-weight: 600; padding: 2px 6px; border-radius: 4px; display: inline-block; }
.tt-status--taken    { background: var(--success); }
.tt-status--late     { background: var(--late); color: #1a1a2e; }
.tt-status--skipped  { background: var(--skipped); }
.tt-status--missed   { background: var(--missed); }
.tt-status--scheduled { background: #6b7280; }
</style>
