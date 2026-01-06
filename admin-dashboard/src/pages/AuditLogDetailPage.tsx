import { useParams, useNavigate } from 'react-router-dom'
import {
  Title,
  Text,
  Stack,
  Card,
  Group,
  Button,
  Badge,
  Code,
  Box,
  Loader,
} from '@mantine/core'
import { useQuery } from '@tanstack/react-query'
import { IconArrowLeft } from '@tabler/icons-react'
import { supabase } from '@/lib/supabase'
import { useDataMapping } from '@/contexts/DataMappingContext'
import { AuditLogHint } from '@/components/AuditLogHint'
import type { AuditLog } from '@/lib/database.types'

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

export function AuditLogDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

  const { undangUndangData, pasalData } = useDataMapping()

  if (!id) {
    return (
      <Stack gap="lg">
        <Group>
          <Button
            variant="subtle"
            leftSection={<IconArrowLeft size={18} />}
            onClick={() => navigate(-1)}
          >
            Kembali
          </Button>
        </Group>
        <Card shadow="sm" padding="lg" radius="md" withBorder>
          <Text ta="center" c="dimmed">ID audit log tidak valid</Text>
        </Card>
      </Stack>
    )
  }

  // Fetch audit log detail
  const { data: log, isLoading } = useQuery({
    queryKey: ['audit_log', 'detail', id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('audit_logs')
        .select('*')
        .eq('id', id)
        .single()

      if (error) throw error
      return data as AuditLog
    },
  })

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('id-ID', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  if (isLoading) {
    return (
      <Stack gap="lg" align="center" justify="center" h="50vh">
        <Loader size="lg" />
        <Text c="dimmed">Memuat detail audit log...</Text>
      </Stack>
    )
  }

  if (!log) {
    return (
      <Stack gap="lg">
        <Group>
          <Button
            variant="subtle"
            leftSection={<IconArrowLeft size={18} />}
            onClick={() => navigate(-1)}
          >
            Kembali
          </Button>
        </Group>
        <Card shadow="sm" padding="lg" radius="md" withBorder>
          <Text ta="center" c="dimmed">Audit log tidak ditemukan</Text>
        </Card>
      </Stack>
    )
  }

  return (
    <Stack gap="lg">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Group>
          <Button
            variant="subtle"
            leftSection={<IconArrowLeft size={18} />}
            onClick={() => navigate(-1)}
          >
            Kembali
          </Button>
        </Group>
      </div>
      <div>
        <Title order={2}>Detail Audit</Title>
        <Text c="dimmed">Perubahan data oleh admin</Text>
      </div>
      <Card shadow="sm" padding="lg" radius="md" withBorder>
        <Stack gap="md">
          <Group>
            <Text fw={500}>Admin:</Text>
            <Text>{log.admin_email}</Text>
          </Group>
          <Group>
            <Text fw={500}>Waktu:</Text>
            <Text>{formatDate(log.created_at)}</Text>
          </Group>
          <Group>
            <Text fw={500}>Aksi:</Text>
            <Badge
              color={
                log.action === 'CREATE' ? 'green' :
                  log.action === 'UPDATE' ? 'blue' :
                    log.action === 'DELETE' ? 'red' : 'gray'
              }
              variant="light"
            >
              {log.action === 'CREATE' ? 'TAMBAH' : log.action === 'UPDATE' ? 'UBAH' : 'HAPUS'}
            </Badge>
          </Group>
          <Group>
            <Text fw={500}>Tabel:</Text>
            <Badge variant="outline">{log.table_name}</Badge>
          </Group>
          <Group>
            <Text fw={500}>Keterangan:</Text>
            <Box>
              <AuditLogHint
                log={log}
                undangUndangData={undangUndangData}
                pasalData={pasalData}
                showFull={true}
              />
            </Box>
          </Group>
          <Group>
            <Text fw={500}>Record ID:</Text>
            <Code>{log.record_id}</Code>
          </Group>

          {/* Diff View */}
          <div>
            <Text fw={500} mb="xs">Perubahan:</Text>
            <div>
              <Stack gap="xs">
                {getDiff(
                  log.old_data as Record<string, unknown> | null,
                  log.new_data as Record<string, unknown> | null
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
            </div>
          </div>
        </Stack>
      </Card>
    </Stack>
  )
}