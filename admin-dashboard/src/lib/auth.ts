export async function requestPasswordRecovery(email: string, redirectTo?: string) {
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
  const anonKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY
  if (!supabaseUrl || !anonKey) throw new Error('Missing Supabase env vars')

  const target = (redirectTo || `${window.location.origin}/reset-password`).replace(/\/$/, '')
  const res = await fetch(`${supabaseUrl.replace(/\/$/, '')}/auth/v1/recover`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: anonKey,
    },
    body: JSON.stringify({ email, redirect_to: target }),
  })

  const text = await res.text()
  if (!res.ok) throw new Error(text || `Request failed with status ${res.status}`)
  return
}

export default requestPasswordRecovery
