import { Card, Title, Skeleton, Stack, useMantineColorScheme, Group, Select } from '@mantine/core'
import {
  ComposedChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { aggregateAuditByDate } from '@/lib/chartUtils'
import { subDays } from 'date-fns'

interface AuditTimelineChartProps {
  logs: any[]
  loading?: boolean
}

export function AuditTimelineChart({ logs, loading }: AuditTimelineChartProps) {
  const { colorScheme } = useMantineColorScheme()
  const navigate = useNavigate()
  const isDark = colorScheme === 'dark'

  // default to 30 days
  const [selectedRange, setSelectedRange] = useState<string | null>('30')

  // Calculate date range based on selection
  const getDateRange = (range: string | null): [Date, Date] => {
    const endDate = new Date()
    let startDate: Date

    switch (range) {
      case '7':
        startDate = subDays(endDate, 7)
        break
      case '15':
        startDate = subDays(endDate, 15)
        break
      case '30':
        startDate = subDays(endDate, 30)
        break
      default:
        startDate = subDays(endDate, 30)
    }

    return [startDate, endDate]
  }

  const [startDate, endDate] = getDateRange(selectedRange)

  // Filter logs based on date range
  const filteredLogs = logs.filter(log => {
    const logDate = new Date(log.created_at)
    return logDate >= startDate && logDate <= endDate
  })

  const data = aggregateAuditByDate(filteredLogs, parseInt(selectedRange || '30'))

  const chartColor = isDark ? '#ffffff' : '#000000'
  const gridColor = isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)'

  const handleBarClick = (payload: any) => {
    const dateStr = payload.payload?.date
    if (!dateStr) return

    // Parse 'MMM dd' format (e.g. 'Dec 21') with current year
    const currentYear = new Date().getFullYear()
    const clicked = new Date(`${dateStr} ${currentYear}`)

    if (isNaN(clicked.getTime())) return

    // Build full-day start/end for clicked date
    const start = new Date(clicked)
    start.setHours(0, 0, 0, 0)
    const end = new Date(clicked)
    end.setHours(23, 59, 59, 999)

    // Navigate to audit log page with date range filter for the clicked date
    navigate(`/audit-log?startDate=${start.toISOString()}&endDate=${end.toISOString()}&search=${dateStr}`)
  }

  if (loading) {
    return (
      <Card shadow="sm" padding="lg" radius="md" withBorder>
        <Title order={4} mb="md">
          Aktivitas Perubahan (30 Hari)
        </Title>
        <Stack gap="sm">
          <Skeleton height={300} />
        </Stack>
      </Card>
    )
  }

  return (
    <Card shadow="sm" padding="lg" radius="md" withBorder>
      <Stack gap="md">
        <div>
          <Group justify="space-between" mb="md">
            <Title order={4}>
              Aktivitas Perubahan
            </Title>

            <Group>
              <Select
                placeholder="Pilih rentang waktu"
                value={selectedRange}
                onChange={setSelectedRange}
                data={[
                  { value: '7', label: '7 Hari Terakhir' },
                  { value: '15', label: '15 Hari Terakhir' },
                  { value: '30', label: '30 Hari Terakhir' },
                ]}
                clearable
                size="sm"
                style={{ maxWidth: '200px' }}
              />
            </Group>
          </Group>
        </div>

        <ResponsiveContainer width="100%" height={300}>
          <ComposedChart data={data} margin={{ top: 5, right: 30, left: 0, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke={gridColor} />
            <XAxis dataKey="date" stroke={chartColor} />
            <YAxis stroke={chartColor} />
            <Tooltip
              contentStyle={{
                backgroundColor: isDark ? '#2c2e31' : '#ffffff',
                border: `1px solid ${isDark ? '#3b3d42' : '#e9ecef'}`,
                borderRadius: '4px',
              }}
              labelStyle={{ color: chartColor }}
            />
            <Legend wrapperStyle={{ color: chartColor }} />
            <Bar
              dataKey="CREATE"
              fill="#51cf66"
              name="Dibuat"
              onClick={handleBarClick}
              style={{ cursor: 'pointer' }}
            />
            <Bar
              dataKey="UPDATE"
              fill="#4dabf7"
              name="Diubah"
              onClick={handleBarClick}
              style={{ cursor: 'pointer' }}
            />
            <Bar
              dataKey="DELETE"
              fill="#ff8787"
              name="Dihapus"
              onClick={handleBarClick}
              style={{ cursor: 'pointer' }}
            />
          </ComposedChart>
        </ResponsiveContainer>
      </Stack>
    </Card>
  )
}
