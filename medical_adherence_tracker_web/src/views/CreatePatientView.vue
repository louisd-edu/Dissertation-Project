<template>
  <AppLayout>
    <div class="create-patient-page">
      <div class="page-header">
        <button class="back-btn" @click="router.push('/patients')">
          <span class="icon" v-html="chevronLeftIcon"></span>
        </button>
        <h2>New Patient</h2>
      </div>

      <div class="form-container">
        <div class="card form-card">
          <form @submit.prevent="createPatient" class="form" data-cy="create-patient-form">

            <div class="field">
              <label>First Name</label>
              <input v-model="form.name" required placeholder="John" data-cy="name-input" />
            </div>

            <div class="field">
              <label>Last Name</label>
              <input v-model="form.surname" required placeholder="Doe" data-cy="surname-input" />
            </div>

            <div class="field">
              <label>Email</label>
              <input v-model="form.email" type="email" required placeholder="patient@mail.com" data-cy="email-input" />
            </div>

            <div class="field">
              <label>Password</label>
              <input v-model="form.password" type="password" required placeholder="Temporary password" minlength="6" data-cy="password-input" />
            </div>

            <div class="field">
              <label>
                Conditions
                <span class="field-hint">(use commas to separate conditions)</span>
              </label>
              <input v-model="form.conditionsInput" placeholder="e.g. Diabetes, Hypertension" data-cy="conditions-input" />
            </div>

            <div v-if="errorMsg" class="error-msg" data-cy="error-message">{{ errorMsg }}</div>

            <div class="form-actions">
              <button type="submit" class="btn-primary" :disabled="saving" data-cy="submit-btn">
                <span v-if="saving" class="btn-spinner"></span>
                {{ saving ? 'Creating…' : 'Create Patient' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import AppLayout from '../components/AppLayout.vue'
import { currentUser, suppressAuthChanges } from '../stores/auth'
import { createPatientFull } from '../supabase'
import chevronLeftIcon from '@/assets/chevron-left.svg?raw'

const router  = useRouter()
const saving  = ref(false)
const errorMsg = ref('')

const form = reactive({
  name:            '',
  surname:         '',
  email:           '',
  password:        '',
  conditionsInput: '',
})

function toMessage(e: unknown): string {
  if (e instanceof Error) return e.message
  if (e && typeof e === 'object' && 'message' in e) return String((e as { message: unknown }).message)
  return 'Failed to create patient.'
}

async function createPatient() {
  if (!currentUser.value) return
  const doctorId = currentUser.value.id
  saving.value   = true
  errorMsg.value = ''
  suppressAuthChanges(true)

  let succeeded = false
  try {
    const conditions = form.conditionsInput.split(',').map(c => c.trim()).filter(Boolean)
    await createPatientFull(form.email, form.password, form.name, form.surname, doctorId, conditions)
    succeeded = true
  } catch (e: unknown) {
    errorMsg.value = toMessage(e)
    console.error('[createPatient]', e)
  } finally {
    suppressAuthChanges(false)
    saving.value = false
  }

  if (succeeded) router.push('/patients')
}
</script>

<style scoped>
.create-patient-page {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 24px 28px;
  gap: 20px;
}

.page-header {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-shrink: 0;
}

.back-btn {
  width: 34px; height: 34px;
  border-radius: 50%;
  border: 1.5px solid var(--border);
  display: flex; align-items: center; justify-content: center;
  color: var(--text-secondary);
  transition: all 0.15s;
  flex-shrink: 0;
}
.back-btn:hover { border-color: var(--primary); color: var(--primary); }
.back-btn .icon :deep(svg) { width: 18px; height: 18px; }

.page-header h2 { font-size: 20px; font-weight: 700; }

.form-container {
  flex: 1;
  display: flex;
  align-items: flex-start;
  justify-content: center;
}

.form-card {
  width: 100%;
  max-width: 440px;
  padding: 28px 32px;
}

.form {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.field { display: flex; flex-direction: column; gap: 5px; }
.field label {
  font-size: 11px;
  font-weight: 700;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.field-hint {
  font-weight: 400;
  text-transform: none;
  letter-spacing: 0;
  font-size: 11px;
  color: var(--text-secondary);
}
.field input {
  padding: 10px 13px;
  border: 1.5px solid var(--border);
  border-radius: var(--radius-sm);
  font-size: 14px;
  color: var(--text-primary);
  background: var(--surface);
  outline: none;
  transition: border-color 0.15s;
}
.field input:focus { border-color: var(--primary); background: #fff; }

.error-msg {
  padding: 10px 14px;
  background: #FFF1F1;
  border: 1px solid #FFD0D0;
  border-radius: var(--radius-sm);
  color: var(--missed);
  font-size: 13px;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 4px;
}

.icon { display: inline-flex; align-items: center; justify-content: center; pointer-events: none; }

.btn-spinner {
  width: 14px; height: 14px;
  border: 2px solid rgba(255,255,255,0.4);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
  display: inline-block;
}
@keyframes spin { to { transform: rotate(360deg); } }
</style>
