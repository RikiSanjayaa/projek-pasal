import {
  Title,
  Text,
  SimpleGrid,
  Card,
  Group,
  ThemeIcon,
  Stack,
  Badge,
  Skeleton,
} from '@mantine/core'
import {
  IconScale,
  IconBook,
  IconHistory,
  IconUsers,
} from '@tabler/icons-react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

interface StatsCardProps {
  title: string
  value: number | string
  icon: React.ReactNode
  color: string
  loading?: boolean
}

function StatsCard({ title, value, icon, color, loading }: StatsCardProps) {
  return (
    <Card shadow="sm" padding="lg" radius="md" withBorder>
      <Group justify="space-between">
        <Stack gap={4}>
          <Text size="xs" c="dimmed" tt="uppercase" fw={700}>
            {title}
          </Text>
          {loading ? (
            <Skeleton height={32} width={60} />
          ) : (
            <Text size="xl" fw={700}>
              {value}
            </Text>
          )}
        </Stack>
        <ThemeIcon size="xl" radius="md" color={color} variant="light">
          {icon}
        </ThemeIcon>
      </Group>
    </Card>
  )
}

export function DashboardPage() {
  // Fetch stats
  const { data: pasalCount, isLoading: loadingPasal } = useQuery({
    queryKey: ['stats', 'pasal'],
    queryFn: async () => {
      const { count, error } = await supabase
        .from('pasal')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true)

      if (error) throw error
      return count || 0
    },
  })

  const { data: uuCount, isLoading: loadingUU } = useQuery({
    queryKey: ['stats', 'undang_undang'],
    queryFn: async () => {
      const { count, error } = await supabase
        .from('undang_undang')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true)

      if (error) throw error
      return count || 0
    },
  })

  const { data: recentLogs, isLoading: loadingLogs } = useQuery({
    queryKey: ['stats', 'recent_logs'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('audit_logs')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(5)

      if (error) throw error
      return data
    },
  })

  const { data: undangUndangList, isLoading: loadingUUList } = useQuery({
    queryKey: ['undang_undang', 'list'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('undang_undang')
        .select('*')
        .eq('is_active', true)
        .order('kode')

      if (error) throw error
      return data
    },
  })

  const { data: pasalCounts, isLoading: loadingPasalCounts } = useQuery({
    queryKey: ['pasal', 'counts'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('pasal')
        .select('undang_undang_id')
        .eq('is_active', true)
        .is('deleted_at', null)

      if (error) throw error

      // Count pasal per undang_undang_id
      const counts: Record<string, number> = {}
      data.forEach((pasal: any) => {
        counts[pasal.undang_undang_id] = (counts[pasal.undang_undang_id] || 0) + 1
      })
      return counts
    },
  })

  return (
    <Stack gap="lg">
      <div>
        <Title order={2}>Dashboard</Title>
        <Text c="dimmed">Selamat datang di CariPasal Admin Dashboard</Text>
      </div>

      {/* Stats Cards */}
      <SimpleGrid cols={{ base: 1, sm: 2, lg: 4 }} spacing="md">
        <StatsCard
          title="Total Pasal"
          value={pasalCount || 0}
          icon={<IconScale size={24} />}
          color="blue"
          loading={loadingPasal}
        />
        <StatsCard
          title="Undang-Undang"
          value={uuCount || 0}
          icon={<IconBook size={24} />}
          color="green"
          loading={loadingUU}
        />
        <StatsCard
          title="Perubahan Hari Ini"
          value={recentLogs?.length || 0}
          icon={<IconHistory size={24} />}
          color="orange"
          loading={loadingLogs}
        />
        <StatsCard
          title="Admin Aktif"
          value="<10"
          icon={<IconUsers size={24} />}
          color="violet"
        />
      </SimpleGrid>

      {/* Undang-Undang Summary */}
      <Card shadow="sm" padding="lg" radius="md" withBorder>
        <Title order={4} mb="md">
          Ringkasan Undang-Undang
        </Title>
        {loadingUUList || loadingPasalCounts ? (
          <Stack gap="sm">
            <Skeleton height={40} />
            <Skeleton height={40} />
            <Skeleton height={40} />
            <Skeleton height={40} />
          </Stack>
        ) : (
          <SimpleGrid cols={{ base: 1, sm: 2, lg: 4 }} spacing="md">
            {undangUndangList?.map((uu: any) => (
              <Card key={uu.id} padding="md" radius="md" withBorder>
                <Badge color="blue" variant="light" mb="xs">
                  {uu.kode}
                </Badge>
                <Text size="sm" fw={500}>
                  {uu.nama}
                </Text>
                <Text size="xs" c="dimmed" mt={4}>
                  {pasalCounts?.[uu.id] || 0} pasal
                </Text>
              </Card>
            ))}
          </SimpleGrid>
        )}
      </Card>

      {/* Recent Activity */}
      <Card shadow="sm" padding="lg" radius="md" withBorder>
        <Title order={4} mb="md">
          Aktivitas Terbaru
        </Title>
        {loadingLogs ? (
          <Stack gap="sm">
            <Skeleton height={30} />
            <Skeleton height={30} />
            <Skeleton height={30} />
          </Stack>
        ) : recentLogs && recentLogs.length > 0 ? (
          <Stack gap="xs">
            {recentLogs.map((log: any) => (
              <Group key={log.id} justify="space-between" py="xs">
                <Group gap="sm">
                  <Badge
                    color={
                      log.action === 'CREATE'
                        ? 'green'
                        : log.action === 'UPDATE'
                          ? 'blue'
                          : 'red'
                    }
                    variant="light"
                    size="sm"
                  >
                    {log.action}
                  </Badge>
                  <Text size="sm">
                    {log.admin_email} - {log.table_name}
                  </Text>
                </Group>
                <Text size="xs" c="dimmed">
                  {new Date(log.created_at).toLocaleString('id-ID')}
                </Text>
              </Group>
            ))}
          </Stack>
        ) : (
          <Text c="dimmed" size="sm">
            Belum ada aktivitas
          </Text>
        )}
      </Card>
    </Stack>
  )
}
