import React, { useEffect, useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import { Card, Title, Text, Stack, PasswordInput, Button, Group, Progress, Box, LoadingOverlay, ThemeIcon } from '@mantine/core'
import { supabase } from '@/lib/supabase'

export function ResetPasswordPage() {
  const navigate = useNavigate()
  const location = useLocation()
  
  const [loading, setLoading] = useState(false)
  const [verifying, setVerifying] = useState(true)
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)

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

  useEffect(() => {
    let checkTimer: NodeJS.Timeout

    const checkSession = async () => {
      // 1. Cek apakah ada error di URL (misal link expired)
      const hash = location.hash.substring(1) // remove #
      const params = new URLSearchParams(hash)
      const errorDescription = params.get('error_description')
      const errorCode = params.get('error')

      if (errorDescription || errorCode) {
        setError(errorDescription?.replace(/\+/g, ' ') || 'Link reset password tidak valid atau sudah kadaluarsa.')
        setVerifying(false)
        return
      }

      // 2. Cek apakah sesi sudah aktif
      const { data: { session } } = await supabase.auth.getSession()
      
      if (session) {
        setVerifying(false)
        return
      }

      // 3. Jika belum aktif, tunggu sebentar
      checkTimer = setTimeout(async () => {
        const { data: { session: retrySession } } = await supabase.auth.getSession()
        if (retrySession) {
          setVerifying(false)
        } else {
          setError('Sesi tidak terdeteksi otomatis. Pastikan Anda membuka link dari email.')
          setVerifying(false)
        }
      }, 2000)
    }

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'PASSWORD_RECOVERY' || (event === 'SIGNED_IN' && session)) {
        if (checkTimer) clearTimeout(checkTimer)
        setError(null)
        setVerifying(false)
      }
    })

    checkSession()

    return () => {
      subscription.unsubscribe()
      if (checkTimer) clearTimeout(checkTimer)
    }
  }, [location])

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleChangePassword()
    }
  }

  const handleChangePassword = async () => {
    if (password.length < 8) {
      setMessage('Password harus minimal 8 karakter')
      return
    }
    if (password !== confirm) {
      setMessage('Password tidak cocok')
      return
    }

    setLoading(true)
    setMessage(null)

    try {
      const { data: { session } } = await supabase.auth.getSession()
      
      if (!session) {
         throw new Error('Sesi kadaluarsa. Silakan minta reset password lagi dari aplikasi.')
      }

      const { error } = await supabase.auth.updateUser({ password })
      if (error) throw error

      try {
        sessionStorage.removeItem('recovery_session')
      } catch (e) { /* ignore */ }

      setSuccess(true)

      // Cek apakah request dari mobile atau web
      const searchParams = new URLSearchParams(location.search)
      const source = searchParams.get('source')

      // Jika BUKAN dari mobile (artinya dari Web/Admin), redirect ke login
      if (source !== 'mobile') {
        setTimeout(() => {
           navigate('/login')
        }, 2000)
      }

    } catch (err: any) {
      setMessage(String(err?.message || err))
    } finally {
      setLoading(false)
    }
  }

  if (success) {
    const searchParams = new URLSearchParams(location.search)
    const isMobile = searchParams.get('source') === 'mobile'

    return (
      <Stack align="center" mt="xl" px="md">
        <Card shadow="sm" padding="xl" radius="md" withBorder w={{ base: '100%', sm: 520 }} ta="center">
          <ThemeIcon color="green" size={60} radius="xl" mx="auto" mb="md">
             <Box style={{ fontSize: 32 }}>✓</Box>
          </ThemeIcon>
          <Title order={3} mb="sm">Password Berhasil Diubah!</Title>
          
          {isMobile ? (
            <>
              <Text c="dimmed" mb="xl">
                Password akun Anda telah diperbarui. Silakan kembali ke aplikasi mobile dan login menggunakan password baru Anda.
              </Text>
              <Text size="xs" c="dimmed">
                Anda boleh menutup halaman ini sekarang.
              </Text>
            </>
          ) : (
            <Text c="dimmed" mb="xl">
              Password berhasil diupdate. Mengalihkan Anda ke halaman login...
            </Text>
          )}
        </Card>
      </Stack>
    )
  }

  return (
    <Stack align="center" mt="xl" px="md">
      <Card shadow="sm" padding="lg" radius="md" withBorder w={{ base: '100%', sm: 520 }} pos="relative">
        <LoadingOverlay visible={verifying} zIndex={1000} overlayProps={{ radius: "sm", blur: 2 }} loaderProps={{ type: 'bars' }} />
        
        <Title order={3}>Reset Password</Title>
        <div style={{ height: 12 }} />

        {error ? (
          <Box mb="md">
             <Text c="red" size="sm" ta="center">{error}</Text>
             <Group justify="center" mt="md">
               <Button variant="light" onClick={() => navigate('/login')}>Kembali ke Login</Button>
             </Group>
          </Box>
        ) : (
          <>
            {message && (
              <Text c={message.includes('berhasil') ? 'green' : 'red'} size="sm" mb="md">
                {message}
              </Text>
            )}

            <Stack mt="md">
              <PasswordInput
                label="Password Baru"
                placeholder="Masukkan password baru"
                value={password}
                onChange={(e) => setPassword(e.currentTarget.value)}
                onKeyDown={handleKeyDown}
                disabled={loading}
              />
              
              {password && (
                <Box>
                  <Text size="xs" c="dimmed" mb={4}>Kekuatan Password</Text>
                  <Progress value={passwordStrength} color={passwordStrength < 50 ? 'red' : passwordStrength < 75 ? 'yellow' : 'green'} size="sm" />
                  <Stack gap="xs" mt="xs">
                    <Text size="xs" c={password.length >= 8 ? 'green' : 'dimmed'}>
                      {password.length >= 8 ? '✓' : '○'} Minimal 8 karakter
                    </Text>
                    <Text size="xs" c={/[a-z]/.test(password) ? 'green' : 'dimmed'}>
                      {/[a-z]/.test(password) ? '✓' : '○'} Huruf kecil (a-z)
                    </Text>
                    <Text size="xs" c={/[A-Z]/.test(password) ? 'green' : 'dimmed'}>
                      {/[A-Z]/.test(password) ? '✓' : '○'} Huruf besar (A-Z)
                    </Text>
                    <Text size="xs" c={/[0-9]/.test(password) ? 'green' : 'dimmed'}>
                      {/[0-9]/.test(password) ? '✓' : '○'} Angka (0-9)
                    </Text>
                    <Text size="xs" c={/[^A-Za-z0-9]/.test(password) ? 'green' : 'dimmed'}>
                      {/[^A-Za-z0-9]/.test(password) ? '✓' : '○'} Simbol (!@#$%^&*)
                    </Text>
                  </Stack>
                </Box>
              )}

              <PasswordInput
                label="Konfirmasi Password"
                placeholder="Ulangi password baru"
                value={confirm}
                onChange={(e) => setConfirm(e.currentTarget.value)}
                onKeyDown={handleKeyDown}
                disabled={loading}
              />

              <Group mt="md">
                <Button color="blue" onClick={handleChangePassword} loading={loading} fullWidth>
                  Simpan Password
                </Button>
              </Group>
            </Stack>
          </>
        )}
      </Card>
    </Stack>
  )
}
