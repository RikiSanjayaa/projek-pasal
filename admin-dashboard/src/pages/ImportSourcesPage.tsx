import { Alert, Anchor, Badge, Button, Card, Group, Loader, Stack, Text, Title } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import { IconCloudDownload, IconExternalLink, IconInfoCircle } from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useNavigate } from 'react-router-dom'
import { ImportStatusBadge } from '@/components/import-run/ImportStatusBadge'
import { IMPORT_CATEGORIES, importSourcesQuery, startImportRun } from '@/lib/import-runs'
import type { ImportRun } from '@/lib/database.types'

const fmt = (iso: string | null) => (iso ? new Date(iso).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' }) : '-')

function CountsLine({ run }: { run: ImportRun }) {
  if (!run.summary) return null
  const parts = IMPORT_CATEGORIES.filter((c) => run.summary!.counts[c.value] > 0)
  if (parts.length === 0) return <Text size="sm" c="dimmed">Tidak ada perbedaan.</Text>
  return (
    <Group gap={6}>
      {parts.map((c) => (
        <Badge key={c.value} variant="outline" color="gray">{c.label}: {run.summary!.counts[c.value]}</Badge>
      ))}
    </Group>
  )
}

export function ImportSourcesPage() {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const { data, isLoading, error } = useQuery(importSourcesQuery(true))

  const start = useMutation({
    mutationFn: startImportRun,
    onSuccess: (run) => {
      queryClient.invalidateQueries({ queryKey: ['import'] })
      navigate(`/sumber-data/runs/${run.id}`)
    },
    onError: (e: Error) => {
      notifications.show({ title: 'Tidak dapat memeriksa pembaruan', message: e.message, color: 'red' })
      queryClient.invalidateQueries({ queryKey: ['import'] })
    },
  })

  const enabled = data?.enabled ?? false

  return (
    <Stack gap="md">
      <div>
        <Title order={2}>Sumber Data</Title>
        <Text c="dimmed" size="sm">
          Periksa pembaruan undang-undang dari datahukum.com. Hasil berupa draf yang harus Anda tinjau; tidak ada data yang berubah sebelum Anda menekan Terapkan.
        </Text>
      </div>

      {data && !enabled && (
        <Alert color="yellow" icon={<IconInfoCircle />} title="Pengambilan data dinonaktifkan">
          Pengambilan data dari datahukum.com dimatikan di lingkungan ini sampai pihak datahukum.com memberi izin. Tombol Periksa pembaruan tidak tersedia.
        </Alert>
      )}
      {error && <Alert color="red" title="Gagal memuat sumber data">{(error as Error).message}</Alert>}
      {isLoading && <Loader />}

      {data?.sources.map((s) => {
        const active = s.active_run
        const last = s.last_run
        const blocked = !!active
        return (
          <Card key={s.slug} withBorder padding="md">
            <Group justify="space-between" align="flex-start" wrap="nowrap">
              <Stack gap={4}>
                <Group gap="xs">
                  <Title order={4}>{s.kode}</Title>
                  <Text c="dimmed" size="sm">{s.label}</Text>
                </Group>
                <Text size="sm">{s.nama}</Text>
                <Anchor href={s.datahukum_url} target="_blank" rel="noreferrer" size="sm">
                  <Group gap={4}>datahukum.com <IconExternalLink size={14} /></Group>
                </Anchor>
              </Stack>
              <Button
                leftSection={<IconCloudDownload size={16} />}
                disabled={!enabled || blocked}
                loading={start.isPending && start.variables === s.slug}
                onClick={() => start.mutate(s.slug)}
              >
                Periksa pembaruan
              </Button>
            </Group>

            {active && (
              <Group mt="md" gap="sm">
                <ImportStatusBadge status={active.status} />
                <Text size="sm">
                  {active.status === 'ready' ? 'Ada draf yang belum diterapkan.' : 'Sedang memeriksa sumber…'} Dimulai {fmt(active.created_at)}.
                </Text>
                <Anchor component={Link} to={`/sumber-data/runs/${active.id}`} size="sm">
                  {active.status === 'ready' ? 'Tinjau draf' : 'Buka'}
                </Anchor>
              </Group>
            )}

            {last && (
              <Stack gap={6} mt="md">
                <Group gap="sm">
                  <Text size="sm" fw={600}>Pemeriksaan terakhir</Text>
                  <ImportStatusBadge status={last.status} />
                  <Text size="sm" c="dimmed">{fmt(last.applied_at ?? last.finished_at ?? last.created_at)}</Text>
                  <Anchor component={Link} to={`/sumber-data/runs/${last.id}`} size="sm">Lihat</Anchor>
                </Group>
                <CountsLine run={last} />
                {last.status === 'failed' && last.error && <Text size="sm" c="red">{last.error}</Text>}
              </Stack>
            )}
            {!last && !active && <Text size="sm" c="dimmed" mt="md">Belum pernah diperiksa.</Text>}
          </Card>
        )
      })}
    </Stack>
  )
}
