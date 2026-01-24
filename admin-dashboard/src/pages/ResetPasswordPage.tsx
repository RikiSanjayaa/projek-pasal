import React, { useEffect, useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import {
  Card,
  Title,
  Text,
  Stack,
  PasswordInput,
  Button,
  Progress,
  Box,
  LoadingOverlay,
  ThemeIcon,
  Alert,
  rem,
  Group
} from '@mantine/core'
import { IconCheck, IconAlertCircle } from '@tabler/icons-react'
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

  /* State for Admin Check */
  const [isAdmin, setIsAdmin] = useState(false)
  
  const getPasswordStrength = (pwd: string) => {
    let strength = 0

    if (!isAdmin) {
      // Simple scoring for mobile users
      if (pwd.length >= 6) strength += 50
      if (/[0-9]/.test(pwd)) strength += 50
    } else {
      // Strict scoring for admins or web users
      if (pwd.length >= 8) strength += 25
      if (/[a-z]/.test(pwd)) strength += 25
      if (/[A-Z]/.test(pwd)) strength += 25
      if (/[0-9]/.test(pwd)) strength += 12.5
      if (/[^A-Za-z0-9]/.test(pwd)) strength += 12.5
    }
    return Math.min(strength, 100)
  }

  const passwordStrength = getPasswordStrength(password)

  const checkAdminRole = async (userId: string) => {
    try {
      const { data } = await supabase
        .from('admin_users')
        .select('id')
        .eq('id', userId)
        .single()
      
      if (data) {
        setIsAdmin(true)
        console.log("Security Check: User identified as Admin.")
      }
    } catch (e) {
      // Not an admin or error checking
    }
  }

  useEffect(() => {
    let checkTimer: NodeJS.Timeout

    const checkSession = async () => {
      // 1. Cek apakah ada error di URL (misal link expired)
      const hash = location.hash.startsWith('#') ? location.hash.substring(1) : location.hash
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
        await checkAdminRole(session.user.id)
        setVerifying(false)
        return
      }

      // 3. Jika belum aktif, tunggu sebentar
      checkTimer = setTimeout(async () => {
        const { data: { session: retrySession } } = await supabase.auth.getSession()
        if (retrySession) {
          await checkAdminRole(retrySession.user.id)
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
        // Perform admin check immediately upon event
        if (session) {
             checkAdminRole(session.user.id).then(() => {
                 setError(null)
                 setVerifying(false)
             })
        } else {
            setError(null)
            setVerifying(false)
        }
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
    if (!isAdmin) {
        // Simple Validation for Regular/Mobile Users
        if (password.length < 6) {
          setMessage('Password harus minimal 6 karakter')
          return
        }
        if (!/\d/.test(password)) {
          setMessage('Password harus mengandung minimal 1 angka')
          return
        }
    } else {
        // Strict Validation for Admins
        if (password.length < 8) {
          setMessage('Password harus minimal 8 karakter')
          return
        }
        // Strict complexity check
        if (!(/[a-z]/.test(password) && /[A-Z]/.test(password) && /[0-9]/.test(password) && /[^A-Za-z0-9]/.test(password))) {
           setMessage('Password harus mengandung huruf besar, huruf kecil, angka, dan karakter spesial')
           return
        }
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

      if (!isAdmin) {
         // Force logout for regular users so they don't get stuck in a web session
         setTimeout(async () => {
            await supabase.auth.signOut()
         }, 1000)
      } else {
        setTimeout(() => {
          navigate('/login')
        }, 2000)
      }

    } catch (err: any) {
      // Translate Supabase error messages to Indonesian
      let msg = String(err?.message || err).toLowerCase()
      
      if (msg.includes('different from the old password')) {
        msg = 'Password baru harus berbeda dengan password lama. Harap gunakan password yang belum pernah dipakai.'
      } else if (msg.includes('password should be at least')) {
        msg = 'Password terlalu pendek.'
      } else if (msg.includes('weak_password')) {
        msg = 'Password terlalu lemah. Gunakan kombinasi huruf, angka, dan simbol.'
      } else {
        msg = String(err?.message || err)
      }

      setMessage(msg)

    } finally {
      setLoading(false)
    }
  }

  // Helper for requirement list items
  const RequirementItem = ({ met, label }: { met: boolean; label: string }) => (
    <Group gap={6} align="center">
      {met ? (
        <IconCheck size={14} color="var(--mantine-color-green-6)" />
      ) : (
        <Box
          w={14}
          h={14}
          style={{
            borderRadius: '50%',
            border: '1.5px solid var(--mantine-color-dimmed)',
            opacity: 0.5
          }}
        />
      )}
      <Text size="xs" c={met ? 'green' : 'dimmed'}>{label}</Text>
    </Group>
  );

  return (
    <Box
      style={{
        minHeight: '100vh',
        backgroundColor: 'var(--mantine-color-body)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '1rem'
      }}
    >
      {/* Branding */}
      <Box mb="xl" ta="center">
        <Title c="blue" order={1} style={{ fontSize: rem(26), fontWeight: 700 }}>CariPasal</Title>
        <Text size="sm" c="dimmed">Reset Password</Text>
      </Box>

      <Card shadow="xl" padding="xl" radius="md" withBorder w="100%" maw={400} pos="relative">
        <LoadingOverlay visible={verifying} zIndex={1000} overlayProps={{ radius: "sm", blur: 2 }} loaderProps={{ type: 'bars' }} />

        {success ? (
          <Stack align="center" gap="md" ta="center">
            {/* Success Icon */}
            <ThemeIcon
              color="green"
              variant="light"
              size={80}
              radius={80}
              mb="sm"
            >
              <IconCheck size={40} style={{ strokeWidth: 2.5 }} />
            </ThemeIcon>

            <Title order={2} ms="h3" mb="xs">Password Berhasil Diperbarui!</Title>

            <Text c="dimmed" size="sm" mb="xl">
              Password Anda telah berhasil diperbarui. Anda sekarang dapat login dengan password baru.
            </Text>

            {!isAdmin ? (
              <Box p="md" bg="var(--mantine-color-gray-light)" style={{ borderRadius: 'var(--mantine-radius-md)', width: '100%' }}>
                <Text size="xs" c="var(--mantine-color-gray-light-color)">
                  Anda dapat menutup halaman ini dan login melalui aplikasi CariPasal di perangkat Anda.
                </Text>
              </Box>
            ) : (
              <Box p="md" bg="var(--mantine-color-blue-light)" c="var(--mantine-color-blue-light-color)" style={{ borderRadius: 'var(--mantine-radius-md)', width: '100%' }}>
                <Text size="sm">
                  Mengalihkan ke halaman login...
                </Text>
              </Box>
            )}
          </Stack>
        ) : (
          <Stack>
            {/* Header */}
            <Box ta="center" mb="sm">
              <Title order={2} size="lg">Buat Password Baru</Title>
              <Text size="sm" c="dimmed" mt={4}>
                Masukkan password baru untuk akun Anda
              </Text>
            </Box>

            {/* Error from URL or Session */}
            {error && (
              <Alert icon={<IconAlertCircle size={16} />} title="Gagal Memuat" color="red" variant="light">
                {error}
                <Button variant="subtle" color="red" size="xs" mt="xs" onClick={() => navigate('/login')}>
                  Kembali ke Login
                </Button>
              </Alert>
            )}

            {/* Form Error Message */}
            {message && !error && (
              <Alert icon={<IconAlertCircle size={16} />} color="red" variant="light">
                {message}
              </Alert>
            )}

            {!error && (
              <>
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
                    <Box display="flex" style={{ justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
                      <Text size="xs" c="dimmed">Kekuatan password</Text>
                      <Text size="xs" c="dimmed">{Math.round(passwordStrength)}%</Text>
                    </Box>
                    <Progress
                      value={passwordStrength}
                      color={passwordStrength < 50 ? 'red' : passwordStrength < 75 ? 'yellow' : 'green'}
                      size="sm"
                      radius="xl"
                      mb="sm"
                    />
                    <Stack gap={4}>
                      {!isAdmin ? (
                          <>
                            <RequirementItem met={password.length >= 6} label="Minimal 6 karakter" />
                            <RequirementItem met={/[0-9]/.test(password)} label="Mengandung angka (0-9)" />
                          </>
                      ) : (
                          <>
                              <RequirementItem met={password.length >= 8} label="Minimal 8 karakter" />
                              <RequirementItem met={/[a-z]/.test(password)} label="Huruf kecil (a-z)" />
                              <RequirementItem met={/[A-Z]/.test(password)} label="Huruf besar (A-Z)" />
                              <RequirementItem met={/[0-9]/.test(password)} label="Angka (0-9)" />
                              <RequirementItem met={/[^A-Za-z0-9]/.test(password)} label="Karakter spesial" />
                          </>
                      )}
                    </Stack>
                  </Box>
                )}

                <PasswordInput
                  label="Konfirmasi Password"
                  placeholder="Masukkan ulang password"
                  value={confirm}
                  onChange={(e) => setConfirm(e.currentTarget.value)}
                  onKeyDown={handleKeyDown}
                  disabled={loading}
                  error={confirm && password !== confirm ? "Password tidak cocok" : null}
                />

                <Button
                  fullWidth
                  color="blue"
                  size="md"
                  mt="md"
                  loading={loading}
                  onClick={handleChangePassword}
                >
                  {loading ? 'Memproses...' : 'Ubah Password'}
                </Button>
              </>
            )}
          </Stack>
        )}
      </Card>
    </Box>
  )
}
