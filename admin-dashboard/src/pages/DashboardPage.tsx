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
import { useNavigate } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { AuditLogHint } from '@/components/AuditLogHint'
import { useDataMapping } from '@/contexts/DataMappingContext'

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
  const navigate = useNavigate()
  const { undangUndangData, pasalData } = useDataMapping()

  // Fetch all dashboard data in one query for better performance
  const { data: dashboardData, isLoading: loadingDashboard } = useQuery({
    queryKey: ['dashboard', 'stats'],
    queryFn: async () => {
      // Fetch all stats in parallel
      const [
        pasalResult,
        uuResult,
        recentLogsResult,
        totalChangesTodayResult,
        undangUndangListResult,
        pasalCountsResult
      ] = await Promise.all([
        // Total pasal count
        supabase
          .from('pasal')
          .select('*', { count: 'exact', head: true })
          .eq('is_active', true),

        // Total undang-undang count
        supabase
          .from('undang_undang')
          .select('*', { count: 'exact', head: true })
          .eq('is_active', true),

        // Recent audit logs (limited to 10 for display)
        supabase
          .from('audit_logs')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(10),

        // Total changes today count (unlimited for stats)
        supabase
          .from('audit_logs')
          .select('*', { count: 'exact', head: true })
          .gte('created_at', new Date(new Date().setHours(0, 0, 0, 0)).toISOString()),

        // Undang-undang list for cards
        supabase
          .from('undang_undang')
          .select('*')
          .eq('is_active', true)
          .order('kode'),

        // Pasal counts per undang-undang
        supabase
          .from('pasal')
          .select('undang_undang_id')
          .eq('is_active', true)
          .is('deleted_at', null)
      ])

      // Check for errors
      if (pasalResult.error) throw pasalResult.error
      if (uuResult.error) throw uuResult.error
      if (recentLogsResult.error) throw recentLogsResult.error
      if (totalChangesTodayResult.error) throw totalChangesTodayResult.error
      if (undangUndangListResult.error) throw undangUndangListResult.error
      if (pasalCountsResult.error) throw pasalCountsResult.error

      // Count pasal per undang_undang_id
      const counts: Record<string, number> = {}
      pasalCountsResult.data.forEach((pasal: any) => {
        counts[pasal.undang_undang_id] = (counts[pasal.undang_undang_id] || 0) + 1
      })

      return {
        pasalCount: pasalResult.count || 0,
        uuCount: uuResult.count || 0,
        recentLogs: recentLogsResult.data || [],
        totalChangesToday: totalChangesTodayResult.count || 0,
        undangUndangList: undangUndangListResult.data || [],
        pasalCounts: counts
      }
    },
    staleTime: 5 * 1000, // 5 seconds - real-time updates for dashboard
    refetchInterval: 10 * 1000, // Auto-refresh every 10 seconds
  })

  // Extract data from the combined query
  const pasalCount = dashboardData?.pasalCount
  const uuCount = dashboardData?.uuCount
  const recentLogs = dashboardData?.recentLogs
  const totalChangesToday = dashboardData?.totalChangesToday
  const undangUndangList = dashboardData?.undangUndangList
  const pasalCounts = dashboardData?.pasalCounts

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
          loading={loadingDashboard}
        />
        <StatsCard
          title="Undang-Undang"
          value={uuCount || 0}
          icon={<IconBook size={24} />}
          color="green"
          loading={loadingDashboard}
        />
        <StatsCard
          title="Perubahan Hari Ini"
          value={totalChangesToday || 0}
          icon={<IconHistory size={24} />}
          color="orange"
          loading={loadingDashboard}
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
        {loadingDashboard ? (
          <Stack gap="sm">
            <Skeleton height={40} />
            <Skeleton height={40} />
            <Skeleton height={40} />
            <Skeleton height={40} />
          </Stack>
        ) : (
          <SimpleGrid cols={{ base: 1, sm: 2, lg: 4 }} spacing="md">
            {undangUndangList?.map((uu: any) => (
              <Card
                key={uu.id}
                padding="md"
                radius="md"
                withBorder
                style={{
                  cursor: 'pointer',
                  transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                }}
                onClick={() => navigate(`/pasal?uu=${uu.id}`)}
                onMouseEnter={(e) => {
                  e.currentTarget.style.borderColor = 'rgba(59, 130, 246, 0.5)'
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.borderColor = ''
                }}
              >
                <Group justify="space-between" mb={12}>
                  <Text size="sm" fw={1000}>
                    {uu.nama}
                  </Text>
                  <Badge color="blue" variant="light">
                    {uu.kode}
                  </Badge>
                </Group>
                <Text size="sm" fw={500}>
                  {uu.nama_lengkap}
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
        {loadingDashboard ? (
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
                    {log.admin_email}
                  </Text>
                  <Badge
                    variant="outline"
                  >
                    {log.table_name.replace('_', ' ')}
                  </Badge>
                  <AuditLogHint
                    log={log}
                    undangUndangData={undangUndangData}
                    pasalData={pasalData}
                    maxLength={80}
                  />
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
