import { useState } from 'react'
import {
  Title,
  Text,
  Stack,
  Card,
  Group,
  Select,
  TextInput,
  Modal,
  ScrollArea,
  Box,
  Button,
  Badge,
  Code,
} from '@mantine/core'
import { DatePickerInput } from '@mantine/dates'
import { useDebouncedValue, useDisclosure } from '@mantine/hooks'
import { IconSearch, IconRefresh } from '@tabler/icons-react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { DataTable, type Column } from '@/components/DataTable'
import { AuditLogHint } from '@/components/AuditLogHint'
import { supabase } from '@/lib/supabase'
import { useDataMapping } from '@/contexts/DataMappingContext'
import type { AuditLog } from '@/lib/database.types'

const PAGE_SIZE = 20

// Helper to compare objects and find differences
function getDiff(oldData: Record<string, unknown> | null, newData: Record<string, unknown> | null) {
  const allKeys = new Set([
    ...Object.keys(oldData || {}),
    ...Object.keys(newData || {}),
  ])

  const diff: {
    key: string
    oldValue: unknown
    newValue: unknown
    type: 'added' | 'removed' | 'changed' | 'unchanged'
  }[] = []

  // Keys to skip in diff display
  const skipKeys = ['id', 'created_at', 'updated_at', 'created_by', 'updated_by', 'search_vector', 'undang_undang_id']

  allKeys.forEach((key) => {
    if (skipKeys.includes(key)) return

    const oldValue = oldData?.[key]
    const newValue = newData?.[key]

    if (oldValue === undefined && newValue !== undefined) {
      diff.push({ key, oldValue, newValue, type: 'added' })
    } else if (oldValue !== undefined && newValue === undefined) {
      diff.push({ key, oldValue, newValue, type: 'removed' })
    } else if (JSON.stringify(oldValue) !== JSON.stringify(newValue)) {
      diff.push({ key, oldValue, newValue, type: 'changed' })
    } else {
      diff.push({ key, oldValue, newValue, type: 'unchanged' })
    }
  })

  return diff
}

export function AuditLogPage() {
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(PAGE_SIZE)
  const [search, setSearch] = useState('')
  const [debouncedSearch] = useDebouncedValue(search, 300)
  const [filterAction, setFilterAction] = useState<string | null>(null)
  const [filterTable, setFilterTable] = useState<string | null>(null)
  const [dateRange, setDateRange] = useState<[Date | null, Date | null]>([null, null])
  const [detailModal, { open: openDetail, close: closeDetail }] = useDisclosure(false)
  const [selectedLog, setSelectedLog] = useState<AuditLog | null>(null)

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

  const handleViewDetail = (log: AuditLog) => {
    setSelectedLog(log)
    openDetail()
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('id-ID', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

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
          onRowClick={handleViewDetail}
          emptyText="Tidak ada data audit log"
        />
      </Card>

      {/* Detail Modal */}
      <Modal
        opened={detailModal}
        onClose={closeDetail}
        title={`Detail Perubahan - ${selectedLog?.action}`}
        size="lg"
      >
        {selectedLog && (
          <Stack gap="md">
            <Group>
              <Text fw={500}>Admin:</Text>
              <Text>{selectedLog.admin_email}</Text>
            </Group>
            <Group>
              <Text fw={500}>Waktu:</Text>
              <Text>{formatDate(selectedLog.created_at)}</Text>
            </Group>
            <Group>
              <Text fw={500}>Tabel:</Text>
              <Badge variant="outline">{selectedLog.table_name}</Badge>
            </Group>
            <Group>
              <Text fw={500}>Keterangan:</Text>
              <Box>
                <AuditLogHint
                  log={selectedLog}
                  undangUndangData={undangUndangData}
                  pasalData={pasalData}
                  showFull={true}
                />
              </Box>
            </Group>
            <Group>
              <Text fw={500}>Record ID:</Text>
              <Code>{selectedLog.record_id}</Code>
            </Group>

            {/* Diff View */}
            <div>
              <Text fw={500} mb="xs">Perubahan:</Text>
              <ScrollArea h={300}>
                <Stack gap="xs">
                  {getDiff(
                    selectedLog.old_data as Record<string, unknown> | null,
                    selectedLog.new_data as Record<string, unknown> | null
                  ).map(({ key, oldValue, newValue, type }) => (
                    <Box key={key}>
                      <Text size="sm" fw={500} c="dimmed" mb={4}>
                        {key}
                      </Text>
                      {type === 'unchanged' ? (
                        <Code block style={{ whiteSpace: 'pre-wrap' }}>
                          {typeof newValue === 'object'
                            ? JSON.stringify(newValue, null, 2)
                            : String(newValue ?? '')}
                        </Code>
                      ) : (
                        <Stack gap={4}>
                          {(type === 'removed' || type === 'changed') && oldValue !== undefined && (
                            <Box
                              p="xs"
                              style={{
                                backgroundColor: 'var(--mantine-color-red-light)',
                                borderRadius: 'var(--mantine-radius-sm)',
                                borderLeft: '3px solid var(--mantine-color-red-filled)',
                              }}
                            >
                              <Text size="xs" c="red" fw={500} mb={2}>
                                - Dihapus
                              </Text>
                              <Code
                                block
                                style={{
                                  whiteSpace: 'pre-wrap',
                                  backgroundColor: 'transparent',
                                }}
                              >
                                {typeof oldValue === 'object'
                                  ? JSON.stringify(oldValue, null, 2)
                                  : String(oldValue ?? '')}
                              </Code>
                            </Box>
                          )}
                          {(type === 'added' || type === 'changed') && newValue !== undefined && (
                            <Box
                              p="xs"
                              style={{
                                backgroundColor: 'var(--mantine-color-green-light)',
                                borderRadius: 'var(--mantine-radius-sm)',
                                borderLeft: '3px solid var(--mantine-color-green-filled)',
                              }}
                            >
                              <Text size="xs" c="green" fw={500} mb={2}>
                                + Ditambahkan
                              </Text>
                              <Code
                                block
                                style={{
                                  whiteSpace: 'pre-wrap',
                                  backgroundColor: 'transparent',
                                }}
                              >
                                {typeof newValue === 'object'
                                  ? JSON.stringify(newValue, null, 2)
                                  : String(newValue ?? '')}
                              </Code>
                            </Box>
                          )}
                        </Stack>
                      )}
                    </Box>
                  ))}
                </Stack>
              </ScrollArea>
            </div>
          </Stack>
        )}
      </Modal>
    </Stack>
  )
}
