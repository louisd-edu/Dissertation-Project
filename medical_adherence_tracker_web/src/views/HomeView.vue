<template>
  <AppLayout>
    <div class="home" data-cy="dashboard">
      <div class="page-header">
        <h2>Home</h2>
      </div>

      <div class="dashboard-grid">
        <!-- Clock -->
        <div class="card clock-card">
          <div class="clock-circle">
            <span class="clock-time">{{ timeStr }}</span>
          </div>
        </div>

        <!-- Date -->
        <div class="card date-card">
          <div class="date-day">{{ dateDay }}</div>
          <div class="date-month">{{ dateMonth }}</div>
          <div class="date-weekday">{{ dateWeekday }}</div>
        </div>

        <!-- Total Patients -->
        <div class="card patients-card">
          <span class="stat-label">Total Patients</span>
          <span v-if="loadingStats" class="stat-loading" data-cy="stat-loading">
            <span class="spinner"></span>
          </span>
          <span v-else class="stat-number" data-cy="patient-count">{{ patientCount }}</span>
        </div>

        <!-- Monthly Adherence -->
        <div class="card adherence-card">
          <DonutChart
            :percentage="adherencePct"
            :size="130"
            color="#34C759"
          >
            <span class="donut-pct" data-cy="adherence-pct">{{ adherencePct }}%</span>
            <span class="donut-sub">Adherence</span>
          </DonutChart>
          <div class="adherence-info">
            <span class="stat-label">Monthly Adherence</span>
            <div class="adherence-breakdown">
              <div class="breakdown-row">
                <span class="dot" style="background:var(--success)"></span>
                <span>Taken</span>
                <span class="breakdown-val" data-cy="stat-taken">{{ stats.taken }}</span>
              </div>
              <div class="breakdown-row">
                <span class="dot" style="background:var(--late)"></span>
                <span>Late</span>
                <span class="breakdown-val" data-cy="stat-late">{{ stats.late }}</span>
              </div>
              <div class="breakdown-row">
                <span class="dot" style="background:var(--skipped)"></span>
                <span>Skipped</span>
                <span class="breakdown-val" data-cy="stat-skipped">{{ stats.skipped }}</span>
              </div>
              <div class="breakdown-row">
                <span class="dot" style="background:var(--missed)"></span>
                <span>Missed</span>
                <span class="breakdown-val" data-cy="stat-missed">{{ stats.missed }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import AppLayout from '../components/AppLayout.vue'
import DonutChart from '../components/DonutChart.vue'
import { currentUser } from '../stores/auth'
import { supabase } from '../supabase'

const now = ref(new Date())
let timer: ReturnType<typeof setInterval>

onMounted(() => { timer = setInterval(() => { now.value = new Date() }, 1000) })
onUnmounted(() => clearInterval(timer))

const timeStr = computed(() => {
  const d = now.value
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`
})
const dateDay     = computed(() => String(now.value.getDate()).padStart(2,'0'))
const dateMonth   = computed(() => now.value.toLocaleString('en-GB', { month: 'short' }).toUpperCase())
const dateWeekday = computed(() => now.value.toLocaleString('en-GB', { weekday: 'long' }))

const patientCount  = ref(0)
const loadingStats  = ref(true)
const stats         = ref({ taken: 0, late: 0, skipped: 0, missed: 0 })
const adherencePct  = ref(0)

onMounted(async () => {
  if (!currentUser.value) return
  loadingStats.value = true
  try {
    const { count } = await supabase
      .from('patient')
      .select('id', { count: 'exact', head: true })
      .eq('doctor_id', currentUser.value.id)
    patientCount.value = count ?? 0

    const today = new Date()
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().slice(0, 10)
    const monthEnd   = new Date(today.getFullYear(), today.getMonth() + 1, 0).toISOString().slice(0, 10)

    const { data: plans } = await supabase
      .from('medication_plan')
      .select('id, patient_id')
      .eq('doctor_id', currentUser.value.id)

    if (plans && plans.length > 0) {
      const planIds = plans.map(p => p.id)
      const planToPatient = new Map(plans.map(p => [p.id, p.patient_id as string]))

      const { data: doses } = await supabase
        .from('dose')
        .select('status, plan_id')
        .in('plan_id', planIds)
        .neq('status', 'scheduled')
        .gte('scheduled_for', monthStart)
        .lte('scheduled_for', monthEnd)

      if (doses && doses.length > 0) {
        const perPatient = new Map<string, { taken: number; late: number; skipped: number; missed: number }>()

        for (const d of doses) {
          const pid = planToPatient.get(d.plan_id) ?? 'unknown'
          if (!perPatient.has(pid)) perPatient.set(pid, { taken: 0, late: 0, skipped: 0, missed: 0 })
          const s = perPatient.get(pid)!
          if      (d.status === 'taken')   s.taken++
          else if (d.status === 'late')    s.late++
          else if (d.status === 'skipped') s.skipped++
          else if (d.status === 'missed')  s.missed++
        }

        
        for (const [, s] of perPatient) {
          stats.value.taken   += s.taken
          stats.value.late    += s.late
          stats.value.skipped += s.skipped
          stats.value.missed  += s.missed
        }

        // Average adherence % across patients (not implemented yet)
        let totalPct = 0
        let activeCount = 0
        for (const [, s] of perPatient) {
          const adherent = s.taken + s.late
          const total    = adherent + s.skipped + s.missed
          if (total > 0) {
            totalPct += (adherent / total) * 100
            activeCount++
          }
        }
        adherencePct.value = activeCount > 0 ? Math.round(totalPct / activeCount) : 0
      }
    }
  } finally {
    loadingStats.value = false
  }
})
</script>

<style scoped>
.home {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 28px;
  gap: 24px;
}

.page-header {
  display: flex;
  align-items: baseline;
  gap: 12px;
}
.page-header h2 { font-size: 22px; font-weight: 700; }
.greeting       { font-size: 14px; color: var(--text-secondary); }

.dashboard-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  grid-template-rows: 1fr 1fr;
  gap: 20px;
  flex: 1;
  min-height: 0;
}

/* gradient cards ── */
.clock-card,
.date-card,
.patients-card,
.adherence-card {
  background: linear-gradient(135deg, #EEF3FD 0%, #DCE8FF 100%);
  border: 1.5px solid rgba(59, 111, 232, 0.12);
  box-shadow: 0 4px 18px rgba(59, 111, 232, 0.10);
}

/* Clock card */
.clock-card {
  display: flex;
  align-items: center;
  justify-content: center;
}
.clock-circle {
  width: 170px;
  height: 170px;
  border-radius: 50%;
  background: rgba(59, 111, 232, 0.06);
  border: 3px solid rgba(59, 111, 232, 0.18);
  display: flex;
  align-items: center;
  justify-content: center;
}
.clock-time {
  font-size: 40px;
  font-weight: 700;
  color: var(--primary);
  letter-spacing: -1px;
}

/* Date card */
.date-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
}
.date-day     { font-size: 52px; font-weight: 700; color: var(--primary); line-height: 1; }
.date-month   { font-size: 26px; font-weight: 700; color: var(--primary); }
.date-weekday { font-size: 14px; font-weight: 600; color: var(--text-secondary); margin-top: 4px; }

/* Patients card */
.patients-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
}
.stat-label  { font-size: 14px; font-weight: 600; color: var(--text-secondary); text-align: center; }
.stat-number { font-size: 56px; font-weight: 700; color: var(--primary); line-height: 1; }
.stat-loading { display: flex; justify-content: center; padding: 12px; }

/* Adherence card */
.adherence-card {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 24px;
  padding: 24px;
}
.donut-pct { font-size: 22px; font-weight: 700; color: var(--text-primary); }
.donut-sub { font-size: 11px; color: var(--text-secondary); font-weight: 500; }
.adherence-info { display: flex; flex-direction: column; gap: 6px; }
.adherence-breakdown { margin-top: 8px; display: flex; flex-direction: column; gap: 4px; }
.breakdown-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--text-secondary);
  padding: 4px 8px;
  background: rgba(59, 111, 232, 0.06);
  border-radius: 6px;
}
.breakdown-val {
  margin-left: auto;
  font-weight: 700;
  color: var(--text-primary);
  min-width: 24px;
  text-align: right;
}
.dot {
  width: 10px; height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
</style>
