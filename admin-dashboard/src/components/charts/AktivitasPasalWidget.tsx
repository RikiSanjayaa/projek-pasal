import { Card, Title, Tabs, Stack, Group, Text, Badge, Skeleton, useMantineColorScheme } from '@mantine/core'
import { IconAlertTriangle, IconHistory, IconLinkOff } from '@tabler/icons-react'
import { formatDistanceToNow } from 'date-fns'
import { id as idLocale } from 'date-fns/locale'
import { useNavigate } from 'react-router-dom'
import { AuditLogHint } from '@/components/AuditLogHint'
import { useDataMapping } from '@/contexts/DataMappingContext'
import { getOrphanedLinks } from '@/lib/chartUtils'

interface AktivitasPasalWidgetProps {
  pasal?: any[]
  recentLogs?: any[]
  trashedPasal?: any[]
  undangUndang?: any[]
  links?: any[]
  loading?: boolean
}

export function AktivitasPasalWidget({ recentLogs = [], trashedPasal = [], links = [], pasal = [], loading }: AktivitasPasalWidgetProps) {
  const navigate = useNavigate()
  const { colorScheme } = useMantineColorScheme()
  const isDark = colorScheme === 'dark'
  const { undangUndangData, pasalData } = useDataMapping()

  // Create a Map from active pasal only (filter out deleted/inactive pasal)
  const activePasal = pasal.length > 0 ? pasal : (pasalData || [])
  const pasalMap = new Map(activePasal.map((p: any) => [p.id, p]))

  // Get orphaned links
  const orphanedLinks = getOrphanedLinks(links, pasalMap)

  if (loading) {
    return (
      <Card shadow="sm" padding="lg" radius="md" withBorder>
        <Title order={4} mb="md">
          Insight Temporal
        </Title>
        <Stack gap="sm">
          <Skeleton height={200} />
        </Stack>
      </Card>
    )
  }

  return (
    <Card shadow="sm" padding="lg" radius="md" withBorder style={{ minHeight: '400px' }}>
      <Title order={4} mb="md">
        Aktivitas Pasal
      </Title>
      <Tabs defaultValue="activity">
        <Tabs.List>
          <Tabs.Tab value="activity" leftSection={<IconHistory size={14} />}>
            Aktivitas Terbaru ({recentLogs.length})
          </Tabs.Tab>
          <Tabs.Tab value="trash" leftSection={<IconAlertTriangle size={14} />}>
            Recycle Bin Pasal ({trashedPasal.length})
          </Tabs.Tab>
          <Tabs.Tab value="broken-links" leftSection={<IconLinkOff size={14} />}>
            link pasal rusak ({orphanedLinks.length})
          </Tabs.Tab>
        </Tabs.List>

        <Tabs.Panel value="activity" pt="md">
          {recentLogs.length > 0 ? (
            <Stack gap="sm">
              {recentLogs.map((log: any) => (
                <Group key={log.id}
                  justify="space-between"
                  p="sm"
                  style={{
                    borderBottom: `1px solid ${isDark ? 'var(--mantine-color-gray-7)' : 'var(--mantine-color-gray-2)'}`,
                    cursor: 'pointer',
                    transition: 'background-color 0.2s ease',
                  }}
                  onClick={() => navigate(`/audit-log/${log.id}`)}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = isDark ? 'var(--mantine-color-gray-8)' : 'var(--mantine-color-gray-0)'
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = 'transparent'
                  }}
                >
                  <div style={{ flex: 1 }}>
                    <Group gap="xs" mb={4}>
                      <Badge
                        color={
                          log.action === 'CREATE'
                            ? 'green'
                            : log.action === 'UPDATE'
                              ? 'blue'
                              : 'red'
                        }
                        variant="light"
                        size="sm"
                      >
                        {log.action}
                      </Badge>
                      <Text size="sm" fw={500}>
                        {log.admin_email}
                      </Text>
                    </Group>
                    <Text size="xs" c="dimmed" mt="xs">
                      {formatDistanceToNow(new Date(log.created_at), { locale: idLocale, addSuffix: true })}
                    </Text>
                  </div>
                  <AuditLogHint
                    log={log}
                    undangUndangData={undangUndangData}
                    pasalData={pasalData}
                    maxLength={50}
                  />
                </Group>
              ))}
            </Stack>
          ) : (
            <Text c="dimmed" size="sm">
              Tidak ada aktivitas terbaru
            </Text>
          )}
        </Tabs.Panel>

        <Tabs.Panel value="trash" pt="md">
          {trashedPasal.length > 0 ? (
            <Stack gap="sm">
              {trashedPasal.map((p: any) => (
                <Group key={p.id}
                  justify="space-between"
                  p="sm"
                  style={{
                    borderBottom: `1px solid ${isDark ? 'var(--mantine-color-gray-7)' : 'var(--mantine-color-gray-2)'}`,
                    cursor: 'pointer',
                    transition: 'background-color 0.2s ease',
                  }}
                  onClick={() => {
                    // Navigate to trash page with search filter
                    navigate(`/pasal/trash?search=${encodeURIComponent(p.nomor)}`)
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = isDark ? 'var(--mantine-color-gray-8)' : 'var(--mantine-color-gray-0)'
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = 'transparent'
                  }}
                >
                  <Badge
                    color="yellow"
                    variant="light"
                    size="sm"
                  >
                    Sampah
                  </Badge>
                  <div style={{ flex: 1 }}>
                    <Text size="sm" fw={500}>
                      Pasal {p.nomor} - {p.judul}
                    </Text>
                  </div>
                  <Text size="xs" c="dimmed">
                    Dihapus {formatDistanceToNow(new Date(p.deleted_at), { locale: idLocale, addSuffix: true })}
                  </Text>
                </Group>
              ))}
            </Stack>
          ) : (
            <Text c="dimmed" size="sm">
              Tidak ada pasal di sampah
            </Text>
          )}
        </Tabs.Panel>

        <Tabs.Panel value="broken-links" pt="md">
          {orphanedLinks.length > 0 ? (
            <Stack gap="sm">
              {orphanedLinks.map((brokenLink: any) => (
                <Group key={brokenLink.linkId}
                  justify="space-between"
                  p="sm"
                  style={{
                    borderBottom: `1px solid ${isDark ? 'var(--mantine-color-gray-7)' : 'var(--mantine-color-gray-2)'}`,
                    cursor: 'pointer',
                    transition: 'background-color 0.2s ease',
                  }}
                  onClick={() => navigate(`/pasal/${brokenLink.sourcePasalId}`)}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = isDark ? 'var(--mantine-color-gray-8)' : 'var(--mantine-color-gray-0)'
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = 'transparent'
                  }}
                >
                  <Badge
                    color="red"
                    variant="light"
                    size="sm"
                  >
                    Rusak
                  </Badge>
                  <div style={{ flex: 1 }}>
                    <Text size="sm" fw={500}>
                      Pasal {brokenLink.sourcePasal?.nomor} {brokenLink.sourcePasal?.judul && `- ${brokenLink.sourcePasal.judul}`}
                    </Text>
                    <Text size="xs" c="dimmed" mt="xs">
                      Merujuk ke pasal yang tidak ada: {brokenLink.targetPasalId}
                    </Text>
                  </div>
                </Group>
              ))}
            </Stack>
          ) : (
            <Text c="dimmed" size="sm">
              Tidak ada link pasal yang rusak
            </Text>
          )}
        </Tabs.Panel>
      </Tabs>
    </Card>
  )
}
