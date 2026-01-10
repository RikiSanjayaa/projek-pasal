import { createContext, useContext, useEffect, useState } from 'react'
import type { User, Session } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import type { AdminUser } from '@/lib/database.types'

interface AuthContextType {
  user: User | null
  session: Session | null
  adminUser: AdminUser | null
  serverDown: boolean
  loading: boolean
  signIn: (email: string, password: string) => Promise<{ error: Error | null; serverDown?: boolean }>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

// Helper function to add timeout to promises
function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  const timeout = new Promise<never>((_, reject) => {
    setTimeout(() => reject(new Error('Timeout')), ms)
  })
  return Promise.race([promise, timeout])
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [adminUser, setAdminUser] = useState<AdminUser | null>(null)
  const [serverDown, setServerDown] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let isMounted = true

    const initAuth = async () => {
      try {
        // Tidak perlu timeout untuk getSession
        const { data: { session } } = await supabase.auth.getSession();

        if (!isMounted) return;

        setSession(session);
        setUser(session?.user ?? null);
        // selesai memproses session — jangan biarkan UI tetap loading menunggu data profil
        setLoading(false)

        if (session?.user) {
          // Fetch admin_user di background dengan timeout
          ; (async () => {
            try {
              const promise = supabase
                .from('admin_users')
                .select('*')
                .eq('id', session.user.id)
                .single()

              const result = await withTimeout(Promise.resolve(promise), 5000) as { data: AdminUser | null, error?: any }

              if (isMounted && result?.data) {
                setAdminUser(result.data)
              }
            } catch (adminError: any) {
              const msg = String(adminError?.message || adminError)
              if (msg.includes('Failed to fetch') || msg.includes('timeout') || adminError?.status >= 500) {
                setServerDown(true)
              }
            }
          })()
        }
      } catch {
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    initAuth()

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      // If GoTrue emits PASSWORD_RECOVERY when user clicks recovery link,
      // redirect to the reset UI so the app can prompt for new password.
      if (event === 'PASSWORD_RECOVERY') {
        try {
          // Mark that this session was created via a recovery flow so the UI
          // can distinguish it from a normal logged-in session.
          try {
            sessionStorage.setItem('recovery_session', Date.now().toString())
          } catch (e) {
            /* ignore sessionStorage errors */
          }

          window.location.href = `${window.location.origin}/reset-password`
          return
        } catch {
        }
      }
      if (!isMounted) return;

      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false)

      if (session?.user) {
        ; (async () => {
          try {
            const promise = supabase
              .from('admin_users')
              .select('*')
              .eq('id', session.user.id)
              .single()

            const result = await withTimeout(Promise.resolve(promise), 5000) as { data: AdminUser | null, error?: any }

            if (isMounted && result?.data) {
              setAdminUser(result.data)
            }
          } catch (error: any) {
            const msg = String(error?.message || error)
            if (msg.includes('Failed to fetch') || msg.includes('timeout') || error?.status >= 500) {
              setServerDown(true)
            }
          }
        })()
      } else {
        setAdminUser(null)
      }
    });

    return () => {
      isMounted = false
      subscription.unsubscribe()
    }
  }, [])

  const signIn = async (email: string, password: string) => {
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      if (error) {
        const msg = String(error.message || error)
        const isServerDown = /failed to fetch|timeout|service unavailable|502|503|gateway/i.test(msg) || (error as any)?.status >= 500

        if (isServerDown) {
          setServerDown(true)
          return { error, serverDown: true }
        }

        return { error, serverDown: false }
      }

      return { error: null }
    } catch (e: any) {
      setServerDown(true)
      return { error: e as Error, serverDown: true }
    }
  }

  const signOut = async () => {
    await supabase.auth.signOut()
    setUser(null)
    setSession(null)
    setAdminUser(null)
  }

  const value = {
    user,
    session,
    adminUser,
    serverDown,
    loading,
    signIn,
    signOut,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
