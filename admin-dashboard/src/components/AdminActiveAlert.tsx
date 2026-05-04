import { Alert, Text } from '@mantine/core'
import { IconAlertCircle } from '@tabler/icons-react'
import { useAuth } from '@/contexts/AuthContext'

export function AdminActiveAlert() {
  const { user, adminUser, loading } = useAuth()

  if (loading || !user) return null

  if (adminUser?.is_active !== false) return null

  return (
    <Alert icon={<IconAlertCircle size={18} />} color="red" style={{ marginBottom: 30 }}>
      <Text fw={700}>Akun Dinonaktifkan</Text>
      <Text size="sm" c="dimmed">Akun admin Anda saat ini dinonaktifkan — Hubungi administrator untuk mengaktifkan kembali akun Anda.</Text>
    </Alert>
  )
}

export default AdminActiveAlert
