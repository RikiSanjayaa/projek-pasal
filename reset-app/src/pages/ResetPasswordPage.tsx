import React from 'react'
import { supabase } from '../lib/supabase'

export function ResetPasswordPage() {
  const [loading, setLoading] = React.useState(false)
  const [password, setPassword] = React.useState('')
  const [confirm, setConfirm] = React.useState('')
  const [showPassword, setShowPassword] = React.useState(false)
  const [showConfirm, setShowConfirm] = React.useState(false)
  const [message, setMessage] = React.useState<string | null>(null)
  const [success, setSuccess] = React.useState(false)

  const getPasswordStrength = (pwd: string) => {
    let strength = 0
    if (pwd.length >= 8) strength += 25
    if (/[a-z]/.test(pwd)) strength += 25
    if (/[A-Z]/.test(pwd)) strength += 25
    if (/[0-9]/.test(pwd)) strength += 12.5
    if (/[^A-Za-z0-9]/.test(pwd)) strength += 12.5
    return Math.min(strength, 100)
  }

  const passwordStrength = getPasswordStrength(password)

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleChangePassword()
    }
  }

  const handleChangePassword = async () => {
    setMessage(null)

    if (password.length < 8) {
      setMessage('Password minimal 8 karakter')
      return
    }
    if (password !== confirm) {
      setMessage('Password tidak cocok')
      return
    }

    setLoading(true)
    try {
      const { data: sessionData } = await supabase.auth.getSession()
      const session = sessionData?.session

      if (!session) {
        setMessage('Tidak ada sesi aktif. Coba buka kembali link dari email Anda.')
        setLoading(false)
        return
      }

      // Verify this is a recovery session
      const isRecoverySession = (() => {
        try {
          const v = sessionStorage.getItem('recovery_session')
          if (!v) return false
          const ts = Number(v)
          if (!ts || Number.isNaN(ts)) return false
          return Date.now() - ts < 1000 * 60 * 5
        } catch {
          return false
        }
      })()

      if (!isRecoverySession) {
        setMessage('Sesi pemulihan tidak valid. Buka link dari email untuk melanjutkan.')
        setLoading(false)
        return
      }

      const { error } = await supabase.auth.updateUser({ password })
      if (error) throw error

      try {
        sessionStorage.removeItem('recovery_session')
      } catch {
        /* ignore */
      }

      setSuccess(true)
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : String(err)
      setMessage(errorMessage)
    } finally {
      setLoading(false)
    }
  }

  // Listen for PASSWORD_RECOVERY event from Supabase
  React.useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event) => {
      if (event === 'PASSWORD_RECOVERY') {
        try {
          sessionStorage.setItem('recovery_session', Date.now().toString())
        } catch {
          /* ignore */
        }
      }
    })

    return () => subscription.unsubscribe()
  }, [])

  const appStoreUrl = import.meta.env.APP_STORE_URL
  const playStoreUrl = import.meta.env.PLAY_STORE_URL
  const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent)
  const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent)
  const storeUrl = isIOS ? appStoreUrl : playStoreUrl
  const hasStoreUrl = !!storeUrl

  if (success) {
    return (
      <div className="min-h-screen bg-base-100 flex flex-col items-center justify-center p-4">
        {/* Branding */}
        <div className="mb-6 text-center">
          <h1 className="text-2xl font-bold text-primary">CariPasal</h1>
          <p className="text-sm text-base-content/50">Reset Password</p>
        </div>

        <div className="card bg-base-200 shadow-xl w-full max-w-sm">
          <div className="card-body items-center text-center">
            {/* Success Icon */}
            <div className="w-20 h-20 rounded-full bg-success/20 flex items-center justify-center mb-4">
              <svg className="w-10 h-10 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>

            <h2 className="card-title text-xl">Password Berhasil Diperbarui!</h2>
            <p className="text-base-content/70 mt-2">
              Password Anda telah berhasil diperbarui. Anda sekarang dapat login dengan password baru.
            </p>

            {hasStoreUrl && isMobile ? (
              <a
                href={storeUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="btn btn-primary w-full mt-6"
              >
                Buka Aplikasi CariPasal
                <svg className="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                </svg>
              </a>
            ) : (
              <div className="mt-6 p-4 bg-base-300 rounded-lg w-full">
                <p className="text-sm text-base-content/70">
                  Anda dapat menutup halaman ini dan login melalui aplikasi CariPasal di perangkat Anda.
                </p>
              </div>
            )}
          </div>
        </div>
      </div>
    )
  }

  const strengthColor = passwordStrength < 50 ? 'progress-error' : passwordStrength < 75 ? 'progress-warning' : 'progress-success'

  return (
    <div className="min-h-screen bg-base-100 flex flex-col items-center justify-center p-4">
      {/* Branding */}
      <div className="mb-6 text-center">
        <h1 className="text-2xl font-bold text-primary">CariPasal</h1>
        <p className="text-sm text-base-content/50">Reset Password</p>
      </div>

      <div className="card bg-base-200 shadow-xl w-full max-w-sm">
        <div className="card-body">
          {/* Header */}
          <div className="text-center mb-4">
            <h2 className="card-title justify-center text-lg">Buat Password Baru</h2>
            <p className="text-base-content/70 text-sm mt-1">
              Masukkan password baru untuk akun Anda
            </p>
          </div>

          {/* Error Message */}
          {message && (
            <div className="alert alert-error mb-4">
              <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span className="text-sm">{message}</span>
            </div>
          )}

          {/* Password Input */}
          <div className="form-control w-full">
            <label className="label">
              <span className="label-text">Password Baru</span>
            </label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                placeholder="Masukkan password baru"
                className="input input-bordered w-full pr-12"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                onKeyDown={handleKeyDown}
              />
              <button
                type="button"
                className="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/50 hover:text-base-content"
                onClick={() => setShowPassword(!showPassword)}
              >
                {showPassword ? (
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                  </svg>
                ) : (
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                )}
              </button>
            </div>
          </div>

          {/* Password Strength */}
          {password && (
            <div className="mt-3">
              <div className="flex justify-between items-center mb-1">
                <span className="text-xs text-base-content/70">Kekuatan password</span>
                <span className="text-xs text-base-content/70">{Math.round(passwordStrength)}%</span>
              </div>
              <progress className={`progress ${strengthColor} w-full h-2`} value={passwordStrength} max="100"></progress>

              <div className="mt-3 space-y-1">
                <div className={`flex items-center gap-2 text-xs ${password.length >= 8 ? 'text-success' : 'text-base-content/50'}`}>
                  {password.length >= 8 ? '✓' : '○'} Minimal 8 karakter
                </div>
                <div className={`flex items-center gap-2 text-xs ${/[a-z]/.test(password) ? 'text-success' : 'text-base-content/50'}`}>
                  {/[a-z]/.test(password) ? '✓' : '○'} Huruf kecil (a-z)
                </div>
                <div className={`flex items-center gap-2 text-xs ${/[A-Z]/.test(password) ? 'text-success' : 'text-base-content/50'}`}>
                  {/[A-Z]/.test(password) ? '✓' : '○'} Huruf besar (A-Z)
                </div>
                <div className={`flex items-center gap-2 text-xs ${/[0-9]/.test(password) ? 'text-success' : 'text-base-content/50'}`}>
                  {/[0-9]/.test(password) ? '✓' : '○'} Angka (0-9)
                </div>
                <div className={`flex items-center gap-2 text-xs ${/[^A-Za-z0-9]/.test(password) ? 'text-success' : 'text-base-content/50'}`}>
                  {/[^A-Za-z0-9]/.test(password) ? '✓' : '○'} Karakter spesial
                </div>
              </div>
            </div>
          )}

          {/* Confirm Password Input */}
          <div className="form-control w-full mt-4">
            <label className="label">
              <span className="label-text">Konfirmasi Password</span>
            </label>
            <div className="relative">
              <input
                type={showConfirm ? 'text' : 'password'}
                placeholder="Masukkan ulang password"
                className="input input-bordered w-full pr-12"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                onKeyDown={handleKeyDown}
              />
              <button
                type="button"
                className="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/50 hover:text-base-content"
                onClick={() => setShowConfirm(!showConfirm)}
              >
                {showConfirm ? (
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                  </svg>
                ) : (
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                )}
              </button>
            </div>
            {confirm && password !== confirm && (
              <label className="label">
                <span className="label-text-alt text-error">Password tidak cocok</span>
              </label>
            )}
          </div>

          {/* Submit Button */}
          <button
            className={`btn btn-primary w-full mt-6 ${loading ? 'loading' : ''}`}
            onClick={handleChangePassword}
            disabled={loading}
          >
            {loading ? 'Memproses...' : 'Ubah Password'}
          </button>
        </div>
      </div>
    </div>
  )
}
