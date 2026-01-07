import React from 'react'
import { useNavigate } from 'react-router-dom'
import { Card, Title, Text, Stack, PasswordInput, Button, Group, Progress, Box } from '@mantine/core'
import { supabase } from '@/lib/supabase'

export function ResetPasswordPage() {
  const navigate = useNavigate()
  const [loading, setLoading] = React.useState(false)
  const [password, setPassword] = React.useState('')
  const [confirm, setConfirm] = React.useState('')
  const [message, setMessage] = React.useState<string | null>(null)

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
    if (password.length < 8) {
      setMessage('Password must be at least 8 characters')
      return
    }
    if (password !== confirm) {
      setMessage('Passwords do not match')
      return
    }

    setLoading(true)
    try {
      const { data: sessionData } = await supabase.auth.getSession()
      const session = sessionData?.session

      if (!session) {
        setMessage('No active session. The recovery token may not have been processed. Re-open the recovery link from your email or click the button below.')
        setLoading(false)
        return
      }

      // Determine whether this is a recovery session (user arrived from recovery link)
      const isRecoverySession = (() => {
        try {
          const v = sessionStorage.getItem('recovery_session')
          if (!v) return false
          const ts = Number(v)
          if (!ts || Number.isNaN(ts)) return false
          // only accept recovery marker if it's recent (5 minutes)
          return Date.now() - ts < 1000 * 60 * 5
        } catch (e) {
          return false
        }
      })()


      // If the user is already logged in but this is NOT a recovery session,
      // do not allow changing password via the recovery page to avoid
      // accidental password resets when the user simply navigates here.
      if (!isRecoverySession) {
        setMessage('You are currently not in a password recovery flow. Open the recovery link from the email to continue.')
        setLoading(false)
        return
      }

      const { error } = await supabase.auth.updateUser({ password })
      if (error) throw error

      // Clear recovery markers so the page cannot be reused maliciously
      try {
        sessionStorage.removeItem('recovery_session')
      } catch (e) {
        /* ignore */
      }

      setMessage('Password updated. Redirecting to login...')
      setTimeout(() => navigate('/login'), 1200)
    } catch (err: any) {
      setMessage(String(err?.message || err))
    } finally {
      setLoading(false)
    }
  }

  return (
    <Stack align="center" mt="xl" px="md">
      <Card shadow="sm" padding="lg" radius="md" withBorder w={{ base: '100%', sm: 520 }}>
        <Title order={3}>Reset Password</Title>

        <div style={{ height: 12 }} />

        {message && (
          <Text c={message.includes('Password updated') ? 'green' : 'red'} size="sm">
            {message}
          </Text>
        )}

        <Stack mt="md">
          <PasswordInput
            placeholder="New password"
            value={password}
            onChange={(e) => setPassword(e.currentTarget.value)}
            onKeyDown={handleKeyDown}
          />
          {password && (
            <Box>
              <Text size="xs" c="dimmed">Password strength</Text>
              <Progress value={passwordStrength} color={passwordStrength < 50 ? 'red' : passwordStrength < 75 ? 'yellow' : 'green'} size="sm" />
              <Stack gap="xs" mt="xs">
                <Text size="xs" c={password.length >= 8 ? 'green' : 'dimmed'}>
                  {password.length >= 8 ? '✓' : '○'} At least 8 characters
                </Text>
                <Text size="xs" c={/[a-z]/.test(password) ? 'green' : 'dimmed'}>
                  {/[a-z]/.test(password) ? '✓' : '○'} Lowercase letter (a-z)
                </Text>
                <Text size="xs" c={/[A-Z]/.test(password) ? 'green' : 'dimmed'}>
                  {/[A-Z]/.test(password) ? '✓' : '○'} Uppercase letter (A-Z)
                </Text>
                <Text size="xs" c={/[0-9]/.test(password) ? 'green' : 'dimmed'}>
                  {/[0-9]/.test(password) ? '✓' : '○'} Number (0-9)
                </Text>
                <Text size="xs" c={/[^A-Za-z0-9]/.test(password) ? 'green' : 'dimmed'}>
                  {/[^A-Za-z0-9]/.test(password) ? '✓' : '○'} Special character (!@#$%^&*)
                </Text>
              </Stack>
            </Box>
          )}
          <PasswordInput
            placeholder="Confirm new password"
            value={confirm}
            onChange={(e) => setConfirm(e.currentTarget.value)}
            onKeyDown={handleKeyDown}
          />
          <Group>
            <Button color="blue" onClick={handleChangePassword} loading={loading} fullWidth>Change Password</Button>
          </Group>
        </Stack>
      </Card>
    </Stack>
  )
}
