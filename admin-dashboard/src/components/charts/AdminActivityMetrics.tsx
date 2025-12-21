import { Card, Title, Stack, Table, Badge, Skeleton, useMantineColorScheme, Group, Select } from '@mantine/core'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { aggregateAdminContributions, aggregateAdminActivityByTime } from '@/lib/chartUtils'
import { subDays } from 'date-fns'

interface AdminActivityMetricsProps {
  logs: any[]
  loading?: boolean
}

export function AdminActivityMetrics({ logs, loading }: AdminActivityMetricsProps) {
  const { colorScheme } = useMantineColorScheme()
  const isDark = colorScheme === 'dark'

  // default to 7 days
  const [selectedRange, setSelectedRange] = useState<string | null>('7')
  const navigate = useNavigate()

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
        startDate = subDays(endDate, 7)
    }

    return [startDate, endDate]
  }

  const [startDate, endDate] = getDateRange(selectedRange)

  // Filter logs based on date range
  const filteredLogs = logs.filter(log => {
    const logDate = new Date(log.created_at)
    return logDate >= startDate && logDate <= endDate
  })

  const contributions = aggregateAdminContributions(filteredLogs)
  const activityByTime = aggregateAdminActivityByTime(filteredLogs, parseInt(selectedRange || '7'))

  const chartColor = isDark ? '#ffffff' : '#000000'
  const gridColor = isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)'

  if (loading) {
    return (
      <Card shadow="sm" padding="lg" radius="md" withBorder>
        <Title order={4} mb="md">
          Produktivitas Admin
        </Title>
        <Stack gap="sm">
          <Skeleton height={300} />
        </Stack>
      </Card>
    )
  }

  const rows = contributions.slice(0, 10).map((contrib) => (
    <Table.Tr key={contrib.email}>
      <Table.Td>{contrib.email}</Table.Td>
      <Table.Td>
        <Badge color="green" variant="light">
          {contrib.creates} dibuat
        </Badge>
      </Table.Td>
      <Table.Td>
        <Badge color="blue" variant="light">
          {contrib.updates} diubah
        </Badge>
      </Table.Td>
      <Table.Td>
        <Badge color="red" variant="light">
          {contrib.deletes} dihapus
        </Badge>
      </Table.Td>
      <Table.Td fw={700}>{contrib.total}</Table.Td>
    </Table.Tr>
  ))

  return (
    <Card shadow="sm" padding="lg" radius="md" withBorder>
      <Stack gap="lg">
        {/* Activity Trend */}
        <div>
          <Group justify="space-between">

            <Title order={4} mb="md">
              Tren Aktivitas Admin
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
          <ResponsiveContainer width="100%" height={250}>
            <LineChart data={activityByTime} margin={{ top: 5, right: 30, left: 0, bottom: 5 }}>
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
              <Line
                type="monotone"
                dataKey="count"
                stroke="#3b82f6"
                name="Jumlah Perubahan"
                // clicking a data point navigates to Audit Log page filtered by that date
                dot={{
                  onClick: (e: any) => {
                    const dateStr = e?.payload?.date || e?.date
                    if (!dateStr) return
                    const clicked = new Date(dateStr)
                    const start = new Date(clicked)
                    start.setHours(0, 0, 0, 0)
                    const end = new Date(clicked)
                    end.setHours(23, 59, 59, 999)
                    navigate(`/audit-log?startDate=${start.toISOString()}&endDate=${end.toISOString()}&search=${dateStr}`)
                  },
                }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Top Contributors */}
        <div>
          <Title order={4} mb="md">
            Top 10 Kontributor
          </Title>
          <div style={{ overflowX: 'auto' }}>
            <Table striped highlightOnHover>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Admin</Table.Th>
                  <Table.Th>Dibuat</Table.Th>
                  <Table.Th>Diubah</Table.Th>
                  <Table.Th>Dihapus</Table.Th>
                  <Table.Th>Total</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>{rows}</Table.Tbody>
            </Table>
          </div>
        </div>
      </Stack>
    </Card>
  )
}
