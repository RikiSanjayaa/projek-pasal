import {
  Title,
  Text,
  Grid,
  Group,
  Stack,
  Button,
} from '@mantine/core'
import {
  IconScale,
  IconBook,
  IconHistory,
} from '@tabler/icons-react'
import { useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { CombinedAnalyticsChart } from '@/components/charts/CombinedAnalyticsChart'
import { TopContributors } from '@/components/dashboard/TopContributors'
import { AktivitasPasalWidget } from '@/components/charts/AktivitasPasalWidget'
import { subDays } from 'date-fns'


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
        newPasalThisWeekResult,
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

        // New Pasal This Week
        supabase
          .from('pasal')
          .select('*', { count: 'exact', head: true })
          .gte('created_at', subDays(new Date(), 7).toISOString())
          .eq('is_active', true),
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
      if (newPasalThisWeekResult.error) throw newPasalThisWeekResult.error

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
        newPasalThisWeek: newPasalThisWeekResult.count || 0,
      }
    },
    staleTime: 30 * 1000,
    refetchInterval: 60 * 1000,
  })

  // Extract data from the combined query
  const pasalCount = dashboardData?.pasalCount
  const uuCount = dashboardData?.uuCount
  const totalChangesToday = dashboardData?.totalChangesToday
  const auditLogsAnalytics = dashboardData?.auditLogsAnalytics || []

  // Get recent contributor name

  return (
    <Stack gap="xl" mb="xl">
      <Group justify="space-between" align="end">
        <div>
          <Title order={2}>Dashboard</Title>
          <Text c="dimmed">Selamat datang di Dashboard Admin CariPasal</Text>
        </div>

        {/* Stats Badges - Compact & Clickable */}
        <Group gap="md">
          <Button
            variant="light"
            color="blue"
            size="md"
            radius="xl"
            leftSection={<IconScale size={20} />}
            onClick={() => navigate('/pasal')}
          >
            {loadingDashboard ? '...' : `${pasalCount || 0} Pasal`}
          </Button>

          <Button
            variant="light"
            color="green"
            size="md"
            radius="xl"
            leftSection={<IconBook size={20} />}
            onClick={() => navigate('/undang-undang')}
          >
            {loadingDashboard ? '...' : `${uuCount || 0} Sumber Undang-Undang`}
          </Button>

          <Button
            variant="light"
            color="orange"
            size="md"
            radius="xl"
            leftSection={<IconHistory size={20} />}
            onClick={() => navigate('/audit-log')}
          >
            {loadingDashboard ? '...' : `${totalChangesToday || 0} Perubahan Hari Ini`}
          </Button>
        </Group>
      </Group>

      {/* Main Analytics Section */}
      <Grid gutter="lg">
        <Grid.Col span={{ base: 12, lg: 8 }}>
          <CombinedAnalyticsChart logs={auditLogsAnalytics} loading={loadingDashboard} />
        </Grid.Col>
        <Grid.Col span={{ base: 12, lg: 4 }}>
          <TopContributors logs={auditLogsAnalytics} loading={loadingDashboard} />
        </Grid.Col>
      </Grid>

      {/* Detailed Insights & Activity */}
      <AktivitasPasalWidget
        pasal={dashboardData?.allPasal}
        recentLogs={dashboardData?.recentAuditLogs}
        trashedPasal={dashboardData?.trashedPasal}
        undangUndang={dashboardData?.undangUndangList}
        links={dashboardData?.allLinks}
        loading={loadingDashboard}
      />
    </Stack>
  )
}
