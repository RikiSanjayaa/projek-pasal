import { useState, useEffect, useRef } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
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
import { api, toQueryString, type PaginatedResponse } from '@/lib/api'
import { useDataMapping } from '@/contexts/DataMappingContext'
import type { AuditLog } from '@/lib/database.types'

const PAGE_SIZE = 20

export function AuditLogPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { undangUndangData, pasalData } = useDataMapping()

  // Derive page directly from URL
  const page = parseInt(searchParams.get('page') || '1', 10)
  const setPage = (newPage: number) => {
    const params = new URLSearchParams(searchParams)
    if (newPage > 1) {
      params.set('page', newPage.toString())
    } else {
      params.delete('page')
    }
    setSearchParams(params)
  }

  const [pageSize, setPageSize] = useState(PAGE_SIZE)
  const [search, setSearch] = useState('')
  const [debouncedSearch] = useDebouncedValue(search, 300)
  const [filterAction, setFilterAction] = useState<string | null>(null)
  const [filterTable, setFilterTable] = useState<string | null>(null)
  const [dateRange, setDateRange] = useState<[Date | null, Date | null]>([null, null])

  // Refs for tracking previous filter values
  const prevDebouncedSearch = useRef(debouncedSearch)
  const prevFilterAction = useRef(filterAction)
  const prevFilterTable = useRef(filterTable)
  const prevDateRangeStr = useRef(JSON.stringify(dateRange))

  // Initialize date range from URL params on mount
  useEffect(() => {
    const startDateParam = searchParams.get('startDate')
    const endDateParam = searchParams.get('endDate')

    if (startDateParam || endDateParam) {
      const start = startDateParam ? new Date(startDateParam) : null
      const end = endDateParam ? new Date(endDateParam) : null
      setDateRange([start, end])
    }
  }, [searchParams])

  // Reset page when filters change
  useEffect(() => {
    const currentDateRangeStr = JSON.stringify(dateRange)

    const searchChanged = debouncedSearch !== prevDebouncedSearch.current
    const actionChanged = filterAction !== prevFilterAction.current
    const tableChanged = filterTable !== prevFilterTable.current
    const dateChanged = currentDateRangeStr !== prevDateRangeStr.current

    if (searchChanged || actionChanged || tableChanged || dateChanged) {
      prevDebouncedSearch.current = debouncedSearch
      prevFilterAction.current = filterAction
      prevFilterTable.current = filterTable
      prevDateRangeStr.current = currentDateRangeStr

      if (page > 1) {
        const params = new URLSearchParams(searchParams)
        params.delete('page')
        setSearchParams(params, { replace: true })
      }
    }
  }, [debouncedSearch, filterAction, filterTable, dateRange, page, searchParams, setSearchParams])

  const handleRefresh = () => {
    // Invalidate all audit-related queries
    queryClient.invalidateQueries({ queryKey: ['audit_logs'] })
    queryClient.invalidateQueries({ queryKey: ['data_mapping'] })
  }

  // Fetch audit logs
  const { data: logsData, isLoading } = useQuery({
    queryKey: ['audit_logs', page, pageSize, debouncedSearch, filterAction, filterTable, dateRange],
    queryFn: async () => {
      const endDate = dateRange[1] ? new Date(dateRange[1]) : null
      if (endDate) endDate.setHours(23, 59, 59, 999)

      const response = await api.get<PaginatedResponse<AuditLog>>(
        `/admin/audit-logs${toQueryString({
          page,
          per_page: pageSize,
          search: debouncedSearch,
          action: filterAction,
          table_name: filterTable,
          start_date: dateRange[0]?.toISOString(),
          end_date: endDate?.toISOString(),
        })}`
      )
      return { data: response.data, count: response.total }
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
              { value: 'RESTORE', label: 'RESTORE' },
              { value: 'IMPORT', label: 'IMPORT' },
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
              { value: 'mobile_users', label: 'Mobile Users' },
              { value: 'admin_users', label: 'Admin Users' },
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
