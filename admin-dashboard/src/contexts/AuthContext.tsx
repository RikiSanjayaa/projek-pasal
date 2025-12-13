import { createContext, useContext, useEffect, useState } from 'react'
import type { User, Session } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import type { AdminUser } from '@/lib/database.types'

interface AuthContextType {
  user: User | null
  session: Session | null
  adminUser: AdminUser | null
  loading: boolean
  signIn: (email: string, password: string) => Promise<{ error: Error | null }>
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
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let isMounted = true

    const initAuth = async () => {
      try {
        // Add 5 second timeout to getSession
        const { data: { session }, error } = await withTimeout(
          supabase.auth.getSession(),
          5000
        )

        if (error) {
          console.error('Session error:', error)
          // Clear potentially corrupt session
          await supabase.auth.signOut()
        }

        if (!isMounted) return

        setSession(session)
        setUser(session?.user ?? null)

        if (session?.user) {
          try {
            // Fetch admin user data with timeout
            const result = await withTimeout(
              Promise.resolve(
                supabase
                  .from('admin_users')
                  .select('*')
                  .eq('id', session.user.id)
                  .single()
              ),
              5000
            ) as { data: AdminUser | null }

            if (isMounted) {
              setAdminUser(result.data)
            }
          } catch (adminError) {
            console.error('Error fetching admin user:', adminError)
          }
        }
      } catch (error) {
        console.error('Auth initialization error:', error)
        // On timeout or error, clear session and continue
        try {
          await supabase.auth.signOut()
        } catch {
          // Ignore signOut errors
        }
      } finally {
        if (isMounted) {
          setLoading(false)
        }
      }
    }

    initAuth()

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, session) => {
      if (!isMounted) return

      setSession(session)
      setUser(session?.user ?? null)

      if (session?.user) {
        try {
          const result = await withTimeout(
            Promise.resolve(
              supabase
                .from('admin_users')
                .select('*')
                .eq('id', session.user.id)
                .single()
            ),
            5000
          ) as { data: AdminUser | null }

          if (isMounted) {
            setAdminUser(result.data)
          }
        } catch (error) {
          console.error('Error fetching admin user on auth change:', error)
        }
      } else {
        setAdminUser(null)
      }
    })

    return () => {
      isMounted = false
      subscription.unsubscribe()
    }
  }, [])

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })

    if (error) {
      return { error }
    }

    return { error: null }
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
