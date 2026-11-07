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
import dayjs from 'dayjs'
import { DataTable, type Column } from '@/components/DataTable'
import { AuditLogHint } from '@/components/AuditLogHint'
import { api, toQueryString, type PaginatedResponse } from '@/lib/api'
import { useDataMapping } from '@/contexts/DataMappingContext'
import type { AuditLog } from '@/lib/database.types'

const PAGE_SIZE = 20

const ACTION_OPTIONS = [
  { value: 'CREATE', label: 'Tambah', color: 'green' },
  { value: 'UPDATE', label: 'Ubah', color: 'blue' },
  { value: 'DELETE', label: 'Hapus', color: 'red' },
  { value: 'RESTORE', label: 'Pulihkan', color: 'teal' },
  { value: 'IMPORT', label: 'Import', color: 'violet' },
  { value: 'LOGIN', label: 'Login', color: 'gray' },
  { value: 'LOGOUT', label: 'Logout', color: 'gray' },
]

const TABLE_OPTIONS = [
  { value: 'pasal', label: 'Pasal' },
  { value: 'undang_undang', label: 'Undang-Undang' },
  { value: 'pasal_links', label: 'Pasal terkait' },
  { value: 'mobile_users', label: 'Pengguna mobile' },
  { value: 'admin_users', label: 'Admin' },
]

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
  // Mantine Dates 8+ memakai string tanggal lokal 'YYYY-MM-DD'
  const [dateRange, setDateRange] = useState<[string | null, string | null]>([null, null])

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
      const start = startDateParam ? dayjs(startDateParam).format('YYYY-MM-DD') : null
      const end = endDateParam ? dayjs(endDateParam).format('YYYY-MM-DD') : null
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
      const startDate = dateRange[0] ? dayjs(dateRange[0]).startOf('day') : null
      const endDate = dateRange[1] ? dayjs(dateRange[1]).endOf('day') : null

      const response = await api.get<PaginatedResponse<AuditLog>>(
        `/admin/audit-logs${toQueryString({
          page,
          per_page: pageSize,
          search: debouncedSearch,
          action: filterAction,
          table_name: filterTable,
          start_date: startDate?.toISOString(),
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
      width: 110,
      render: (value) => {
        const action = ACTION_OPTIONS.find((option) => option.value === value)
        return (
          <Badge color={action?.color ?? 'gray'} variant="light">
            {action?.label ?? value}
          </Badge>
        )
      },
    },
    {
      key: 'table_name',
      title: 'Data',
      width: 150,
      render: (value) => (
        <Badge variant="outline" color="gray">
          {TABLE_OPTIONS.find((option) => option.value === value)?.label ?? value}
        </Badge>
      ),
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

      <Card padding="md">
        <Stack gap="md">
          <Group grow wrap="wrap">
            <TextInput
              placeholder="Cari email admin..."
              leftSection={<IconSearch size={16} />}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <Select
              placeholder="Semua aksi"
              data={ACTION_OPTIONS.map(({ value, label }) => ({ value, label }))}
              value={filterAction}
              onChange={setFilterAction}
              clearable
            />
            <Select
              placeholder="Semua data"
              data={TABLE_OPTIONS}
              value={filterTable}
              onChange={setFilterTable}
              clearable
            />
            <DatePickerInput
              weekendDays={[0]}
              type="range"
              valueFormat="D MMM YYYY"
              placeholder="Rentang tanggal"
              value={dateRange}
              onChange={setDateRange}
              clearable
            />
          </Group>

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
        </Stack>
      </Card>
    </Stack>
  )
}
