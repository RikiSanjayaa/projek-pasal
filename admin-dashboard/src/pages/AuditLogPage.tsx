import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Title,
  Text,
  Stack,
  Card,
  Group,
  Select,
  TextInput,
  Button,
  Badge,
} from '@mantine/core'
import { DatePickerInput } from '@mantine/dates'
import { useDebouncedValue } from '@mantine/hooks'
import { IconSearch, IconRefresh } from '@tabler/icons-react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { DataTable, type Column } from '@/components/DataTable'
import { AuditLogHint } from '@/components/AuditLogHint'
import { supabase } from '@/lib/supabase'
import { useDataMapping } from '@/contexts/DataMappingContext'
import type { AuditLog } from '@/lib/database.types'

const PAGE_SIZE = 20

export function AuditLogPage() {
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(PAGE_SIZE)
  const [search, setSearch] = useState('')
  const [debouncedSearch] = useDebouncedValue(search, 300)
  const [filterAction, setFilterAction] = useState<string | null>(null)
  const [filterTable, setFilterTable] = useState<string | null>(null)
  const [dateRange, setDateRange] = useState<[Date | null, Date | null]>([null, null])

  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { undangUndangData, pasalData } = useDataMapping()

  const handleRefresh = () => {
    // Invalidate all audit-related queries
    queryClient.invalidateQueries({ queryKey: ['audit_logs'] })
    queryClient.invalidateQueries({ queryKey: ['data_mapping'] })
  }

  // Fetch audit logs
  const { data: logsData, isLoading } = useQuery({
    queryKey: ['audit_logs', page, pageSize, debouncedSearch, filterAction, filterTable, dateRange],
    queryFn: async () => {
      let query = supabase
        .from('audit_logs')
        .select('*', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range((page - 1) * pageSize, page * pageSize - 1)

      if (debouncedSearch) {
        query = query.or(`admin_email.ilike.%${debouncedSearch}%,record_id.eq.${debouncedSearch}`)
      }

      if (filterAction) {
        query = query.eq('action', filterAction)
      }

      if (filterTable) {
        query = query.eq('table_name', filterTable)
      }

      if (dateRange[0]) {
        query = query.gte('created_at', dateRange[0].toISOString())
      }

      if (dateRange[1]) {
        const endDate = new Date(dateRange[1])
        endDate.setHours(23, 59, 59, 999)
        query = query.lte('created_at', endDate.toISOString())
      }

      const { data, error, count } = await query

      if (error) throw error
      return { data: data as AuditLog[], count: count || 0 }
    },
  })

  // Define table columns for audit logs
  const auditLogColumns: Column<AuditLog>[] = [
    {
      key: 'created_at',
      title: 'Waktu',
      width: 160,
      render: (value) => (
        <Text size="sm">
          {new Date(value as string).toLocaleString('id-ID', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
          })}
        </Text>
      ),
    },
    {
      key: 'admin_email',
      title: 'Admin',
      width: 200,
      render: (value) => <Text size="sm">{value || '-'}</Text>,
    },
    {
      key: 'action',
      title: 'Aksi',
      width: 100,
      render: (value) => {
        const getActionColor = (action: string) => {
          switch (action) {
            case 'CREATE':
              return 'green'
            case 'UPDATE':
              return 'blue'
            case 'DELETE':
              return 'red'
            default:
              return 'gray'
          }
        }
        return (
          <Badge color={getActionColor(value as string)} variant="light">
            {value}
          </Badge>
        )
      },
    },
    {
      key: 'table_name',
      title: 'Tabel',
      width: 120,
      render: (value) => <Badge variant="outline">{value}</Badge>,
    },
    {
      key: 'change_hint',
      title: 'Keterangan',
      render: (_, record) => (
        <AuditLogHint
          log={record}
          undangUndangData={undangUndangData}
          pasalData={pasalData}
          maxLength={50}
        />
      ),
    },
  ]

  return (
    <Stack gap="lg">
      <div>
        <Group justify="space-between" align="center">
          <div>
            <Title order={2}>Audit Log</Title>
            <Text c="dimmed">Riwayat perubahan data oleh admin</Text>
          </div>
          <Button
            leftSection={<IconRefresh size={16} />}
            variant="light"
            onClick={handleRefresh}
          >
            Refresh
          </Button>
        </Group>
      </div>

      {/* Filters */}
      <Card shadow="sm" padding="md" radius="md" withBorder>
        <Group grow wrap="wrap">
          <TextInput
            placeholder="Cari email admin..."
            leftSection={<IconSearch size={16} />}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <Select
            placeholder="Filter Aksi"
            data={[
              { value: 'CREATE', label: 'CREATE' },
              { value: 'UPDATE', label: 'UPDATE' },
              { value: 'DELETE', label: 'DELETE' },
            ]}
            value={filterAction}
            onChange={setFilterAction}
            clearable
          />
          <Select
            placeholder="Filter Tabel"
            data={[
              { value: 'pasal', label: 'Pasal' },
              { value: 'undang_undang', label: 'Undang-Undang' },
              { value: 'pasal_links', label: 'Pasal Links' },
            ]}
            value={filterTable}
            onChange={setFilterTable}
            clearable
          />
          <DatePickerInput
            weekendDays={[0]}
            type="range"
            placeholder="Filter Tanggal"
            value={dateRange}
            onChange={setDateRange}
            clearable
          />
        </Group>
      </Card>

      {/* Table */}
      <Card shadow="sm" padding="md" radius="md" withBorder>
        <DataTable
          columns={auditLogColumns}
          data={logsData?.data || []}
          loading={isLoading}
          current={page}
          pageSize={pageSize}
          total={logsData?.count || 0}
          onPageChange={setPage}
          onPageSizeChange={(newPageSize) => {
            setPageSize(newPageSize)
            setPage(1) // Reset to first page when changing page size
          }}
          onRowClick={(log) => navigate(`/audit-log/${log.id}`)}
          emptyText="Tidak ada data audit log"
        />
      </Card>
    </Stack>
  )
}
