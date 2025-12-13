import { useState } from 'react'
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
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { IconAlertCircle } from '@tabler/icons-react'
import { useAuth } from '@/contexts/AuthContext'

export function LoginPage() {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const { signIn, user } = useAuth()
  const navigate = useNavigate()

  // Redirect if already logged in
  if (user) {
    navigate('/')
    return null
  }

  const form = useForm({
    initialValues: {
      email: '',
      password: '',
    },
    validate: {
      email: (value) => (/^\S+@\S+$/.test(value) ? null : 'Email tidak valid'),
      password: (value) => (value.length >= 6 ? null : 'Password minimal 6 karakter'),
    },
  })

  const handleSubmit = async (values: { email: string; password: string }) => {
    setLoading(true)
    setError(null)

    const { error } = await signIn(values.email, values.password)

    if (error) {
      setError('Email atau password salah. Pastikan Anda terdaftar sebagai admin.')
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
      </Container>
    </Center>
  )
}
