import { Alert, Text } from '@mantine/core'
import { IconAlertCircle } from '@tabler/icons-react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/contexts/AuthContext'

export function AdminActiveAlert() {
  const { user, loading } = useAuth()

  const { data: adminReadCheck, isLoading: isQueryLoading } = useQuery({
    queryKey: ['admin', 'can-read-self-email', user?.id],
    queryFn: async () => {
      if (!user) return { canRead: true } // Fallback aman, harusnya tidak terpanggil karena enabled: !!user

      const { data, error } = await supabase
        .from('admin_users')
        .select('email')
        .eq('id', user.id)
        .maybeSingle()

      return { canRead: !!data && !error }
    },
    // Query hanya jalan jika user sudah ada
    enabled: !!user,
    staleTime: 30 * 1000,
  })


  if (loading || !user || isQueryLoading) return null

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
