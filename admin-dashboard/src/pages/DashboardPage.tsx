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
import { api } from '@/lib/api'
import { CombinedAnalyticsChart } from '@/components/charts/CombinedAnalyticsChart'
import { TopContributors } from '@/components/dashboard/TopContributors'
import { AktivitasPasalWidget } from '@/components/charts/AktivitasPasalWidget'

interface DashboardSummary {
  total_pasal_active: number
  total_undang_undang: number
  total_changes_today: number
  undang_undang_list: any[]
  pasal_counts: Record<string, number>
  admin_active_count: number
  all_pasal: any[]
  all_links: any[]
  audit_logs_analytics: any[]
  trashed_pasal: any[]
  recent_audit_logs: any[]
  new_pasal_this_week: number
}

export function DashboardPage() {
  const navigate = useNavigate()

  // Fetch all dashboard data in one query for better performance
  const { data: dashboardData, isLoading: loadingDashboard } = useQuery({
    queryKey: ['dashboard', 'stats'],
    queryFn: async () => {
      const result = await api.get<DashboardSummary>('/admin/dashboard/summary')

      return {
        pasalCount: result.total_pasal_active || 0,
        uuCount: result.total_undang_undang || 0,
        recentLogs: result.recent_audit_logs || [],
        totalChangesToday: result.total_changes_today || 0,
        undangUndangList: result.undang_undang_list || [],
        pasalCounts: result.pasal_counts || {},
        adminActiveCount: result.admin_active_count || 0,
        allPasal: result.all_pasal || [],
        allLinks: result.all_links || [],
        auditLogsAnalytics: result.audit_logs_analytics || [],
        trashedPasal: result.trashed_pasal || [],
        recentAuditLogs: result.recent_audit_logs || [],
        newPasalThisWeek: result.new_pasal_this_week || 0,
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
