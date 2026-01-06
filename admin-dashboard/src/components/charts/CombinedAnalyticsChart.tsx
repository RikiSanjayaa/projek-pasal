import { Card, Title, Select, Group, useMantineColorScheme, Skeleton } from '@mantine/core'
import {
  ComposedChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer
} from 'recharts'
import { useState, useMemo } from 'react'
import { subDays, startOfDay, format } from 'date-fns'
import { useNavigate } from 'react-router-dom'

interface CombinedAnalyticsChartProps {
  logs: any[]
  loading?: boolean
}

export function CombinedAnalyticsChart({ logs, loading }: CombinedAnalyticsChartProps) {
  const { colorScheme } = useMantineColorScheme()
  const isDark = colorScheme === 'dark'
  const navigate = useNavigate()

  const [range, setRange] = useState<string>('30')

  const data = useMemo(() => {
    const days = parseInt(range)
    const result: Record<string, { date: string, CREATE: number, UPDATE: number, DELETE: number, total: number, timestamp: number }> = {}

    // Init dates
    for (let i = days - 1; i >= 0; i--) {
      const d = startOfDay(subDays(new Date(), i))
      const label = format(d, 'MMM dd')
      result[label] = {
        date: label,
        CREATE: 0,
        UPDATE: 0,
        DELETE: 0,
        total: 0,
        timestamp: d.getTime()
      }
    }

    // Fill data
    const cutoff = startOfDay(subDays(new Date(), days))
    logs.forEach(log => {
      const d = new Date(log.created_at)
      if (d >= cutoff) {
        const label = format(d, 'MMM dd')
        if (result[label]) {
          const action = log.action as 'CREATE' | 'UPDATE' | 'DELETE'
          result[label][action] = (result[label][action] || 0) + 1
          result[label].total += 1
        }
      }
    })

    return Object.values(result)
  }, [logs, range])

  const chartColor = isDark ? '#C1C2C5' : '#1A1B1E'
  const gridColor = isDark ? '#373A40' : '#E9ECEF'

  if (loading) {
    return (
      <Card shadow="sm" padding="lg" radius="md" withBorder style={{ height: '100%' }}>
        <Group justify="space-between" mb="md">
          <Skeleton height={28} width={200} />
          <Skeleton height={36} width={150} />
        </Group>
        <Skeleton height={350} radius="md" />
      </Card>
    )
  }

  const handleClick = (data: any) => {
    if (data && data.activePayload && data.activePayload[0]) {
      const payload = data.activePayload[0].payload
      const dateStr = payload.date
      // construct basic search/filter url
      // This is a simplified version of what was in the previous files
      const currentYear = new Date().getFullYear()
      const clicked = new Date(`${dateStr} ${currentYear}`)
      if (!isNaN(clicked.getTime())) {
        const start = new Date(clicked)
        start.setHours(0, 0, 0, 0)
        const end = new Date(clicked)
        end.setHours(23, 59, 59, 999)
        navigate(`/audit-log?startDate=${start.toISOString()}&endDate=${end.toISOString()}`)
      }
    }
  }

  return (
    <Card
      shadow="sm"
      padding="lg"
      radius="md"
      withBorder
      style={{ height: '100%', display: 'flex', flexDirection: 'column' }}
    >
      <div style={{ marginBottom: 20 }}>
        <Group justify="space-between" align="center">
          <div>
            <Title order={4}>Ringkasan Analitik</Title>
            <Title order={6} c="dimmed" fw={400}>Aktivitas dan lini masa gabungan</Title>
          </div>
          <Select
            value={range}
            onChange={(v) => setRange(v || '30')}
            data={[
              { value: '7', label: '7 Hari Terakhir' },
              { value: '15', label: '15 Hari Terakhir' },
              { value: '30', label: '30 Hari Terakhir' },
              { value: '90', label: '3 Bulan Terakhir' },
            ]}
            w={150}
          />
        </Group>
      </div>

      <div style={{ flex: 1, minHeight: 400 }}>
        <ResponsiveContainer width="100%" height="100%">
          <ComposedChart data={data} onClick={handleClick}>
            <defs>
              <linearGradient id="colorTotal" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#8884d8" stopOpacity={0.8} />
                <stop offset="95%" stopColor="#8884d8" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke={gridColor} vertical={false} />
            <XAxis
              dataKey="date"
              stroke={chartColor}
              tick={{ fontSize: 12 }}
              tickLine={false}
              axisLine={false}
              dy={10}
            />
            <YAxis
              stroke={chartColor}
              tick={{ fontSize: 12 }}
              tickLine={false}
              axisLine={false}
              dx={-10}
            />
            <Tooltip
              cursor={{ fill: isDark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)' }}
              contentStyle={{
                backgroundColor: isDark ? '#25262B' : '#FFFFFF',
                borderColor: isDark ? '#373A40' : '#E9ECEF',
                borderRadius: 8,
                boxShadow: '0 4px 12px rgba(0,0,0,0.1)'
              }}
            />
            <Legend wrapperStyle={{ paddingTop: 20 }} />

            <Bar dataKey="CREATE" name="Dibuat" stackId="a" fill="#40C057" radius={[0, 0, 4, 4]} />
            <Bar dataKey="UPDATE" name="Diubah" stackId="a" fill="#228BE6" />
            <Bar dataKey="DELETE" name="Dihapus" stackId="a" fill="#FA5252" radius={[4, 4, 0, 0]} />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
    </Card>
  )
}
