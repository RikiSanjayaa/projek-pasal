import { useState } from 'react'
import {
  Title,
  Text,
  Stack,
  Card,
  Group,
  Select,
  Table,
  Badge,
  Pagination,
  Skeleton,
  TextInput,
  Code,
  Modal,
  ScrollArea,
  Box,
} from '@mantine/core'
import { DatePickerInput } from '@mantine/dates'
import { useDebouncedValue, useDisclosure } from '@mantine/hooks'
import { IconSearch } from '@tabler/icons-react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { AuditLog } from '@/lib/database.types'

const PAGE_SIZE = 20

// Helper to get hint about what was changed
function getChangeHint(log: AuditLog): string {
  const data = (log.new_data || log.old_data) as Record<string, unknown> | null
  if (!data || typeof data !== 'object') return '-'

  if (log.table_name === 'pasal') {
    const nomor = (data.nomor as string) || ''
    const judul = (data.judul as string) || ''
    return `Pasal ${nomor}${judul ? ` - ${judul}` : ''}`
  }

  if (log.table_name === 'undang_undang') {
    const kode = (data.kode as string) || ''
    const nama = (data.nama as string) || ''
    return `${kode}${nama ? ` - ${nama}` : ''}`
  }

  if (log.table_name === 'pasal_links') {
    return 'Link Pasal'
  }

  return '-'
}

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
  const skipKeys = ['id', 'created_at', 'updated_at', 'created_by', 'updated_by', 'search_vector']

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
  const [search, setSearch] = useState('')
  const [debouncedSearch] = useDebouncedValue(search, 300)
  const [filterAction, setFilterAction] = useState<string | null>(null)
  const [filterTable, setFilterTable] = useState<string | null>(null)
  const [dateRange, setDateRange] = useState<[Date | null, Date | null]>([null, null])
  const [detailModal, { open: openDetail, close: closeDetail }] = useDisclosure(false)
  const [selectedLog, setSelectedLog] = useState<AuditLog | null>(null)

  // Fetch audit logs
  const { data: logsData, isLoading } = useQuery({
    queryKey: ['audit_logs', page, debouncedSearch, filterAction, filterTable, dateRange],
    queryFn: async () => {
      let query = supabase
        .from('audit_logs')
        .select('*', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1)

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

  const handleViewDetail = (log: AuditLog) => {
    setSelectedLog(log)
    openDetail()
  }

  const totalPages = Math.ceil((logsData?.count || 0) / PAGE_SIZE)

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
        <Title order={2}>Audit Log</Title>
        <Text c="dimmed">Riwayat perubahan data oleh admin</Text>
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
        {isLoading ? (
          <Stack gap="sm">
            {[...Array(10)].map((_, i) => (
              <Skeleton key={i} height={40} />
            ))}
          </Stack>
        ) : (
          <>
            <Table striped highlightOnHover>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Waktu</Table.Th>
                  <Table.Th>Admin</Table.Th>
                  <Table.Th>Aksi</Table.Th>
                  <Table.Th>Tabel</Table.Th>
                  <Table.Th>Keterangan</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                {logsData?.data?.map((log) => (
                  <Table.Tr
                    key={log.id}
                    style={{ cursor: 'pointer' }}
                    onClick={() => handleViewDetail(log)}
                  >
                    <Table.Td>
                      <Text size="sm">{formatDate(log.created_at)}</Text>
                    </Table.Td>
                    <Table.Td>
                      <Text size="sm">{log.admin_email || '-'}</Text>
                    </Table.Td>
                    <Table.Td>
                      <Badge color={getActionColor(log.action)} variant="light">
                        {log.action}
                      </Badge>
                    </Table.Td>
                    <Table.Td>
                      <Badge variant="outline">{log.table_name}</Badge>
                    </Table.Td>
                    <Table.Td>
                      <Text size="sm" lineClamp={1}>
                        {getChangeHint(log)}
                      </Text>
                    </Table.Td>
                  </Table.Tr>
                ))}
              </Table.Tbody>
            </Table>

            {logsData?.data?.length === 0 && (
              <Text c="dimmed" ta="center" py="xl">
                Tidak ada data audit log
              </Text>
            )}

            {totalPages > 1 && (
              <Group justify="center" mt="md">
                <Pagination value={page} onChange={setPage} total={totalPages} />
              </Group>
            )}
          </>
        )}
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
              <Text>{getChangeHint(selectedLog)}</Text>
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
