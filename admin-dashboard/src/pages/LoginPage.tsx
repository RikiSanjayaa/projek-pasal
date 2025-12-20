import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  TextInput,
  PasswordInput,
  Button,
  Paper,
  Title,
  Text,
  Container,
  Stack,
  Center,
  Alert,
  Modal,
  Group,
  Anchor,
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { showNotification } from '@mantine/notifications'
import { IconAlertCircle } from '@tabler/icons-react'
import { useAuth } from '@/contexts/AuthContext'
import { requestPasswordRecovery } from '@/lib/auth'

export function LoginPage() {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [resetModalOpened, setResetModalOpened] = useState(false)
  const [resetLoading, setResetLoading] = useState(false)
  const { signIn, user, serverDown } = useAuth()
  const navigate = useNavigate()

  // Redirect if already logged in (do imperative navigation inside effect)
  useEffect(() => {
    if (user) navigate('/')
  }, [user, navigate])

  type LoginFormValues = {
    email: string
    password: string
  }

  const resetForm = useForm({
    initialValues: {
      email: '',
    },
    validate: {
      email: (value) => (/^\S+@\S+$/.test(value) ? null : 'Email tidak valid'),
    },
  })

  const form = useForm<LoginFormValues>({
    initialValues: {
      email: '',
      password: '',
    },
    validate: {
      email: (value) => (/^\S+@\S+$/.test(value) ? null : 'Email tidak valid'),
      password: (value) => (value.length >= 6 ? null : 'Password minimal 6 karakter'),
    },
  })

  const handleResetPassword = async (values: { email: string }) => {
    setResetLoading(true)
    try {
      await requestPasswordRecovery(values.email)
      showNotification({
        title: 'Email Reset Password Terkirim',
        message: `Link reset password telah dikirim ke ${values.email}. Periksa inbox dan folder spam Anda.`,
        color: 'green'
      })
      setResetModalOpened(false)
      resetForm.reset()
    } catch (err: any) {
      console.error('Failed to request password reset', err)
      showNotification({
        title: 'Gagal Mengirim Email Reset',
        message: String(err?.message || err),
        color: 'red'
      })
    } finally {
      setResetLoading(false)
    }
  }

  const handleSubmit = async (values: { email: string; password: string }) => {
    setLoading(true)
    setError(null)

    const { error, serverDown: signInServerDown } = await signIn(values.email, values.password)

    if (error) {
      if (signInServerDown || serverDown) {
        setError('Server sedang bermasalah. Silakan coba lagi nanti.')
      } else {
        setError('Email atau password salah. Pastikan Anda terdaftar sebagai admin.')
      }
      setLoading(false)
      return
    }

    navigate('/')
  }

  return (
    <Center h="100vh" bg="var(--mantine-color-body)">
      <Container size={420} my={40}>
        <Title ta="center" fw={900}>
          CariPasal Admin
        </Title>
        <Text c="dimmed" size="sm" ta="center" mt={5}>
          Masuk untuk mengelola data pasal
        </Text>

        <Paper withBorder shadow="md" p={30} mt={30} radius="md">
          <form onSubmit={form.onSubmit(handleSubmit)}>
            <Stack>
              {error && (
                <Alert
                  icon={<IconAlertCircle size={16} />}
                  title="Login Gagal"
                  color="red"
                  variant="light"
                >
                  {error}
                </Alert>
              )}

              <TextInput
                label="Email"
                placeholder="admin@example.com"
                required
                {...form.getInputProps('email')}
              />

              <PasswordInput
                label="Password"
                placeholder="Masukkan password"
                required
                {...form.getInputProps('password')}
              />

              <Button type="submit" fullWidth mt="xl" loading={loading}>
                Masuk
              </Button>
            </Stack>
          </form>
        </Paper>

        <Text c="dimmed" size="xs" ta="center" mt={20}>
          Hubungi administrator jika Anda belum memiliki akun.
        </Text>

        <Text ta="center" mt="md">
          <Anchor
            component="button"
            type="button"
            size="sm"
            onClick={() => setResetModalOpened(true)}
          >
            Lupa Password?
          </Anchor>
        </Text>

        <Modal
          opened={resetModalOpened}
          onClose={() => setResetModalOpened(false)}
          title="Reset Password"
          centered
        >
          <Text size="sm" c="dimmed" mb="md">
            Masukkan email akun admin Anda. Link reset password akan dikirim ke email tersebut.
          </Text>

          <form onSubmit={resetForm.onSubmit(handleResetPassword)}>
            <Stack>
              <TextInput
                label="Email Admin"
                placeholder="admin@example.com"
                required
                {...resetForm.getInputProps('email')}
              />

              <Group justify="flex-end" mt="md">
                <Button variant="default" onClick={() => setResetModalOpened(false)}>
                  Batal
                </Button>
                <Button type="submit" loading={resetLoading}>
                  Kirim Link Reset
                </Button>
              </Group>
            </Stack>
          </form>
        </Modal>
      </Container>
    </Center>
  )
}
