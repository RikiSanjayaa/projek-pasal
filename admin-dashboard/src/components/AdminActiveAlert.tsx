import { Alert, Text } from '@mantine/core'
import { IconAlertCircle } from '@tabler/icons-react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export function AdminActiveAlert() {
  const { data: adminReadCheck } = useQuery({
    queryKey: ['admin', 'can-read-self-email'],
    queryFn: async () => {
      const { data: userData } = await supabase.auth.getUser()
      const user = userData?.user
      if (!user) return { canRead: false }

      const { data, error } = await supabase
        .from('admin_users')
        .select('email')
        .eq('id', user.id)
        .maybeSingle()

      return { canRead: !!data && !error }
    },
    staleTime: 30 * 1000,
  })

  const isAdminInactive = adminReadCheck ? !adminReadCheck.canRead : false

  if (!isAdminInactive) return null

  return (
    <Alert icon={<IconAlertCircle size={18} />} color="red" style={{ marginBottom: 30 }}>
      <Text fw={700}>Akun Dinonaktifkan</Text>
      <Text size="sm" c="dimmed">Akun admin Anda saat ini dinonaktifkan — Hubungi administrator untuk mengaktifkan kembali akun Anda.</Text>
    </Alert>
  )
}

export default AdminActiveAlert
