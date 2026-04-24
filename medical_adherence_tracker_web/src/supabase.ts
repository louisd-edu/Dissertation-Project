import { createClient } from '@supabase/supabase-js'

// Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in a .env file
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL as string || 'https://your-project.supabase.co'
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY as string || 'your-anon-key'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// Creates a patient auth user, profile row, and patient row in one transaction-like
// flow. Uses three fully isolated in-memory clients so the main doctor session is
// never read from or written to after the initial token snapshot:
//   1. signupClient  — signs up the new patient (in-memory, never persisted)
//   2. doctorClient  — seeded with the doctor's pre-captured tokens for DB inserts
//   3. main client   — restored at the end so navigation guards still work
export async function createPatientFull(
  email: string,
  password: string,
  name: string,
  surname: string,
  doctorId: string,
  conditions: string[],
): Promise<string> {
  // Snapshot doctor tokens BEFORE signUp — isolated signUp can corrupt main session
  // via supabase-js BroadcastChannel sync even with persistSession: false.
  const { data: { session: drSession } } = await supabase.auth.getSession()
  if (!drSession) throw new Error('No active doctor session. Please log in again.')
  const { access_token, refresh_token } = drSession

  // 1. Create the new patient auth user
  const signupClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })
  const { data: signupData, error: signupErr } = await signupClient.auth.signUp({ email, password })
  if (signupErr) throw signupErr
  if (!signupData.user) throw new Error('Failed to create auth user.')
  const newUserId = signupData.user.id

  // 2. Fresh isolated client seeded with doctor's tokens for all DB writes.
  //    This client is brand-new and has never been touched by the signUp above.
  const doctorClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: true, detectSessionInUrl: false },
  })
  const { error: sessErr } = await doctorClient.auth.setSession({ access_token, refresh_token })
  if (sessErr) throw new Error(`Could not restore doctor session: ${sessErr.message}`)

  // 3. Insert profile row (policy: profile: doctor inserts patient)
  const { error: profileErr } = await doctorClient.from('profile').insert({
    id: newUserId, name, surname, role: 'patient',
  })
  if (profileErr) throw new Error(`Profile insert failed: ${profileErr.message} [${profileErr.code}]`)

  // 4. Insert patient relationship row (policy: patient: doctor inserts)
  const { error: patientErr } = await doctorClient.from('patient').insert({
    id: newUserId, doctor_id: doctorId, condition: conditions,
  })
  if (patientErr) throw new Error(`Patient insert failed: ${patientErr.message} [${patientErr.code}]`)

  // 5. Restore main client so the router auth guard still sees the doctor as logged in
  await supabase.auth.setSession({ access_token, refresh_token })

  return newUserId
}

/** @deprecated use createPatientFull instead */
export async function signUpNewUser(email: string, password: string): Promise<string> {
  const isolated = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })
  const { data, error } = await isolated.auth.signUp({ email, password })
  if (error) throw error
  if (!data.user) throw new Error('Failed to create user account.')
  return data.user.id
}

export interface Profile {
  id: string
  role: 'doctor' | 'patient'
  name: string
  surname: string
  avatar_url?: string
}

export interface Patient {
  id: string
  doctor_id: string
  condition: string[]
}

export interface PatientWithProfile extends Patient {
  profile: Pick<Profile, 'name' | 'surname' | 'avatar_url'>
}

export interface MedicationPlan {
  id: string
  name: string
  dosage: number
  units: string
  frequency: string[]
  time: string
  start_date: string
  end_date: string
  patient_id: string
  doctor_id: string
  plan_name: string
}

export interface Dose {
  id: string
  taken_at: string | null
  status: 'taken' | 'late' | 'missed' | 'scheduled' | 'skipped'
  media_url?: string
  plan_id: string
  scheduled_for: string
}

export interface DoseWithPlan extends Dose {
  medication_name: string
  plan_name: string
}

export const STATUS_COLORS: Record<string, string> = {
  taken:     '#34C759',
  late:      '#FFD60A',
  skipped:   '#FF6B00',
  missed:    '#FF3B30',
  scheduled: '#D1D5DB',
}

export const STATUS_LABELS: Record<string, string> = {
  taken:     'Taken',
  late:      'Late',
  skipped:   'Skipped',
  missed:    'Missed',
  scheduled: 'Scheduled',
}
