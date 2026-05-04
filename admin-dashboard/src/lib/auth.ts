import { api } from './api'

const APP_BASE_PATH = import.meta.env.VITE_APP_BASE_PATH || '/'

function defaultResetUrl() {
  const basePath = APP_BASE_PATH.endsWith('/') ? APP_BASE_PATH.slice(0, -1) : APP_BASE_PATH
  return `${window.location.origin}${basePath}/reset-password`
}

export async function requestPasswordRecovery(email: string, redirectTo?: string, userType: 'admin' | 'mobile' = 'admin') {
  return api.post<{ message: string }>('/password/forgot', {
    email,
    user_type: userType,
    reset_url: redirectTo || defaultResetUrl(),
  }, { auth: false })
}

export async function resetPasswordWithToken(payload: {
  email: string
  token: string
  password: string
  password_confirmation: string
  user_type?: 'admin' | 'mobile'
}) {
  return api.post<{ message: string }>('/password/reset', {
    email: payload.email,
    token: payload.token,
    password: payload.password,
    password_confirmation: payload.password_confirmation,
    user_type: payload.user_type || 'admin',
  }, { auth: false })
}

export default requestPasswordRecovery
