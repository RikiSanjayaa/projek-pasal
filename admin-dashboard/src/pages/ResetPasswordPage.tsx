import { useMemo, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { Alert, Box, Button, Card, PasswordInput, Stack, Text, Title, rem } from '@mantine/core'
import { useForm } from '@mantine/form'
import { showNotification } from '@mantine/notifications'
import { IconAlertCircle, IconCheck } from '@tabler/icons-react'
import { resetPasswordWithToken } from '@/lib/auth'

type ResetPasswordFormValues = {
  password: string
  password_confirmation: string
}

export function ResetPasswordPage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [loading, setLoading] = useState(false)
  const [done, setDone] = useState(false)
  const email = searchParams.get('email') || ''
  const token = searchParams.get('token') || ''
  const type = searchParams.get('type') === 'mobile' ? 'mobile' : 'admin'
  const isValidLink = useMemo(() => Boolean(email && token), [email, token])
  const form = useForm<ResetPasswordFormValues>({
    initialValues: {
      password: '',
      password_confirmation: '',
    },
    validate: {
      password: (value) => (value.length >= 8 ? null : 'Password minimal 8 karakter'),
      password_confirmation: (value, values) => (value === values.password ? null : 'Konfirmasi password tidak sama'),
    },
  })

  const handleSubmit = async (values: typeof form.values) => {
    setLoading(true)
    try {
      const response = await resetPasswordWithToken({
        email,
        token,
        user_type: type,
        password: values.password,
        password_confirmation: values.password_confirmation,
      })
      setDone(true)
      showNotification({ title: 'Berhasil', message: response.message, color: 'green' })
    } catch (error) {
      showNotification({ title: 'Gagal', message: error instanceof Error ? error.message : 'Reset password gagal.', color: 'red' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <Box
      style={{
        minHeight: '100vh',
        backgroundColor: 'var(--mantine-color-body)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '1rem',
      }}
    >
      <Box mb="xl" ta="center">
        <Title c="blue" order={1} style={{ fontSize: rem(26), fontWeight: 700 }}>CariPasal</Title>
        <Text size="sm" c="dimmed">Reset Password</Text>
      </Box>

      <Card padding="xl" radius="md" withBorder w="100%" maw={420}>
        {!isValidLink ? (
          <Stack>
            <Alert icon={<IconAlertCircle size={16} />} title="Link tidak valid" color="red" variant="light">
              Link reset password tidak lengkap. Minta link reset password baru dari halaman login.
            </Alert>
            <Button fullWidth onClick={() => navigate('/login')}>
              Kembali ke Login
            </Button>
          </Stack>
        ) : done ? (
          <Stack>
            <Alert icon={<IconCheck size={16} />} title="Password berhasil direset" color="green" variant="light">
              {type === 'mobile'
                ? 'Password berhasil diganti. Silakan kembali ke aplikasi mobile dan login memakai password baru.'
                : 'Silakan login kembali ke admin dashboard memakai password baru.'}
            </Alert>
            {type === 'admin' ? (
              <Button fullWidth onClick={() => navigate('/login')}>
                Ke Halaman Login
              </Button>
            ) : (
              <Button fullWidth variant="light" onClick={() => window.close()}>
                Tutup Halaman
              </Button>
            )}
          </Stack>
        ) : (
          <form onSubmit={form.onSubmit(handleSubmit)}>
            <Stack>
              <Text size="sm" c="dimmed">
                Reset password untuk {email}. Password baru akan dipakai untuk akun {type === 'admin' ? 'admin' : 'mobile'}.
              </Text>
              <PasswordInput label="Password Baru" required {...form.getInputProps('password')} />
              <PasswordInput label="Konfirmasi Password" required {...form.getInputProps('password_confirmation')} />
              <Button fullWidth type="submit" loading={loading}>
                Simpan Password Baru
              </Button>
            </Stack>
          </form>
        )}
      </Card>
    </Box>
  )
}
