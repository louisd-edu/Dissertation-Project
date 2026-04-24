import { ref } from 'vue'
import { supabase } from '../supabase'
import type { Profile } from '../supabase'

export const currentUser     = ref<Profile | null>(null)
export const isAuthenticated = ref(false)
export const authLoading     = ref(true)

// prevent triggering profile loading temporary signUp because of session switch for patient creation
let _suppressAuthChanges = false
export function suppressAuthChanges(v: boolean) { _suppressAuthChanges = v }

export async function initAuth(): Promise<void> {
  try {
    const { data: { session } } = await supabase.auth.getSession()
    if (session?.user) await loadProfile(session.user.id)
  } finally {
    authLoading.value = false
  }

  supabase.auth.onAuthStateChange(async (_event, session) => {
    if (_suppressAuthChanges) return
    if (session?.user) {
      await loadProfile(session.user.id)
    } else {
      currentUser.value     = null
      isAuthenticated.value = false
    }
  })
}

async function loadProfile(userId: string): Promise<void> {
  const { data } = await supabase.from('profile').select('*').eq('id', userId).single()
  if (data?.role === 'doctor') {
    currentUser.value     = data as Profile
    isAuthenticated.value = true
  } else {
    currentUser.value     = null
    isAuthenticated.value = false
  }
}

export async function login(email: string, password: string): Promise<void> {
  const { error, data } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error

  const { data: profile } = await supabase
    .from('profile')
    .select('*')
    .eq('id', data.user.id)
    .single()

  if (!profile || profile.role !== 'doctor') {
    await supabase.auth.signOut()
    throw new Error('Access denied. This portal is for doctors only.')
  }

  currentUser.value     = profile as Profile
  isAuthenticated.value = true
}

export async function logout(): Promise<void> {
  await supabase.auth.signOut()
  currentUser.value     = null
  isAuthenticated.value = false
}
