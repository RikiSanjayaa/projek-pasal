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
import { AuditTimelineChart } from '@/components/charts/AuditTimelineChart'
import { AdminActivityMetrics } from '@/components/charts/AdminActivityMetrics'
import { AktivitasPasalWidget } from '@/components/charts/AktivitasPasalWidget'

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
        pasalCountsResult,
        adminActiveResult,
        allPasalResult,
        allLinksResult,
        auditLogsForAnalyticsResult,
        trashedPasalResult,
        recentAuditLogsResult,
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

        // Recent audit logs (limited to 10 for display in old section)
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
          .is('deleted_at', null),

        // Active admin users count
        supabase
          .from('admin_users')
          .select('*', { count: 'exact', head: true })
          .eq('is_active', true),

        // All pasal for analytics (not just count)
        supabase
          .from('pasal')
          .select('id, nomor, judul, isi, penjelasan, keywords, created_at, updated_at, undang_undang_id')
          .eq('is_active', true)
          .is('deleted_at', null),

        // All pasal links for analytics
        supabase
          .from('pasal_links')
          .select('*')
          .eq('is_active', true),

        // Audit logs for analytics (last 90 days)
        supabase
          .from('audit_logs')
          .select('*')
          .gte('created_at', new Date(new Date().setDate(new Date().getDate() - 90)).toISOString())
          .order('created_at', { ascending: false }),

        // Trashed pasal (soft-deleted)
        supabase
          .from('pasal')
          .select('id, nomor, judul, deleted_at')
          .eq('is_active', false)
          .not('deleted_at', 'is', null)
          .order('deleted_at', { ascending: false })
          .limit(10),

        // Recent audit logs for temporal insights tab
        supabase
          .from('audit_logs')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(10),
      ])

      // Check for errors
      if (pasalResult.error) throw pasalResult.error
      if (uuResult.error) throw uuResult.error
      if (recentLogsResult.error) throw recentLogsResult.error
      if (totalChangesTodayResult.error) throw totalChangesTodayResult.error
      if (undangUndangListResult.error) throw undangUndangListResult.error
      if (pasalCountsResult.error) throw pasalCountsResult.error
      if (allPasalResult.error) throw allPasalResult.error
      if (allLinksResult.error) throw allLinksResult.error
      if (auditLogsForAnalyticsResult.error) throw auditLogsForAnalyticsResult.error
      if (trashedPasalResult.error) throw trashedPasalResult.error
      if (recentAuditLogsResult.error) throw recentAuditLogsResult.error

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
        pasalCounts: counts,
        adminActiveCount: adminActiveResult.count || 0,
        allPasal: allPasalResult.data || [],
        allLinks: allLinksResult.data || [],
        auditLogsAnalytics: auditLogsForAnalyticsResult.data || [],
        trashedPasal: trashedPasalResult.data || [],
        recentAuditLogs: recentAuditLogsResult.data || [],
      }
    },
    staleTime: 30 * 1000, // 30 seconds - reduced for better real-time feel
    refetchInterval: 60 * 1000, // Auto-refresh every 60 seconds
  })

  // Extract data from the combined query
  const pasalCount = dashboardData?.pasalCount
  const uuCount = dashboardData?.uuCount
  const totalChangesToday = dashboardData?.totalChangesToday
  const undangUndangList = dashboardData?.undangUndangList
  const pasalCounts = dashboardData?.pasalCounts
  const adminActiveCount = dashboardData?.adminActiveCount
  const auditLogsAnalytics = dashboardData?.auditLogsAnalytics || []

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
          value={adminActiveCount ?? 0}
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

      {/* Analytics Section */}
      <Stack gap="lg">
        {/* Activity Timeline */}
        <AuditTimelineChart logs={auditLogsAnalytics} loading={loadingDashboard} />
        {/* Admin Activity Metrics */}
        <AdminActivityMetrics logs={auditLogsAnalytics} loading={loadingDashboard} />
        {/* Temporal Insights */}
        <AktivitasPasalWidget
          pasal={dashboardData?.allPasal}
          recentLogs={dashboardData?.recentAuditLogs}
          trashedPasal={dashboardData?.trashedPasal}
          undangUndang={dashboardData?.undangUndangList}
          links={dashboardData?.allLinks}
          loading={loadingDashboard}
        />
      </Stack>
    </Stack>
  )
}
