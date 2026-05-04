import { createContext, useContext, useEffect, useState } from 'react'
import { api, ApiError, clearAuthToken, getAuthToken, setAuthToken } from '@/lib/api'
import type { AdminUser } from '@/lib/database.types'

interface AuthUser {
  id: string
  email: string
}

interface AuthSession {
  access_token: string
}

interface SignInResult {
  error: Error | null
  serverDown?: boolean
  inactive?: boolean
}

interface AuthContextType {
  user: AuthUser | null
  session: AuthSession | null
  adminUser: AdminUser | null
  serverDown: boolean
  loading: boolean
  signIn: (email: string, password: string) => Promise<SignInResult>
  signOut: () => Promise<void>
}

interface AuthResponse {
  token: string
  user: AdminUser
}

interface MeResponse {
  user: AdminUser
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

function toAuthUser(admin: AdminUser): AuthUser {
  return { id: admin.id, email: admin.email }
}

function isServerError(error: unknown) {
  return error instanceof ApiError && (error.status === 0 || error.status >= 500)
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null)
  const [session, setSession] = useState<AuthSession | null>(null)
  const [adminUser, setAdminUser] = useState<AdminUser | null>(null)
  const [serverDown, setServerDown] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let isMounted = true

    async function initAuth() {
      const token = getAuthToken()
      if (!token) {
        setLoading(false)
        return
      }

      try {
        const response = await api.get<MeResponse>('/admin/me')
        if (!isMounted) return
        setSession({ access_token: token })
        setAdminUser(response.user)
        setUser(toAuthUser(response.user))
        setServerDown(false)
      } catch (error) {
        if (!isMounted) return
        if (isServerError(error)) {
          setServerDown(true)
        } else {
          clearAuthToken()
          setSession(null)
          setAdminUser(null)
          setUser(null)
        }
      } finally {
        if (isMounted) setLoading(false)
      }
    }

    initAuth()

    return () => {
      isMounted = false
    }
  }, [])

  const signIn = async (email: string, password: string): Promise<SignInResult> => {
    try {
      const response = await api.post<AuthResponse>('/admin/login', { email, password }, { auth: false })
      setAuthToken(response.token)
      setSession({ access_token: response.token })
      setAdminUser(response.user)
      setUser(toAuthUser(response.user))
      setServerDown(false)
      return { error: null }
    } catch (error) {
      if (isServerError(error)) {
        setServerDown(true)
        return { error: error as Error, serverDown: true }
      }

      const inactive = error instanceof ApiError && error.status === 403
      return { error: error as Error, inactive }
    }
  }

  const signOut = async () => {
    try {
      await api.post('/admin/logout')
    } catch {
      // Local logout must still succeed if server is unreachable.
    } finally {
      clearAuthToken()
      setUser(null)
      setSession(null)
      setAdminUser(null)
    }
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
