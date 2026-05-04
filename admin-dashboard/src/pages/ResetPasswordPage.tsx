import { useNavigate } from 'react-router-dom'
import { Alert, Box, Button, Card, Stack, Text, Title, rem } from '@mantine/core'
import { IconAlertCircle } from '@tabler/icons-react'

export function ResetPasswordPage() {
  const navigate = useNavigate()

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

      <Card shadow="xl" padding="xl" radius="md" withBorder w="100%" maw={420}>
        <Stack>
          <Alert icon={<IconAlertCircle size={16} />} title="Belum tersedia di backend lokal" color="yellow" variant="light">
            Reset password email masih ditunda sampai SMTP dan endpoint Laravel disiapkan. Untuk migrasi awal, admin membuat password awal baru dari halaman Manage Users atau Manage Admin.
          </Alert>
          <Button fullWidth onClick={() => navigate('/login')}>
            Kembali ke Login
          </Button>
        </Stack>
      </Card>
    </Box>
  )
}
