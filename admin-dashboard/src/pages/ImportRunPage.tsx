import { useState } from 'react'
import {
  Alert,
  Anchor,
  Badge,
  Box,
  Button,
  Card,
  Checkbox,
  Collapse,
  Group,
  List,
  Loader,
  Modal,
  Pagination,
  Paper,
  SegmentedControl,
  Stack,
  Text,
  Title,
} from '@mantine/core'
import { notifications } from '@mantine/notifications'
import { IconAlertTriangle, IconChevronDown, IconChevronRight, IconExternalLink } from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useParams } from 'react-router-dom'
import { ImportItemDetail } from '@/components/import-run/ImportItemDetail'
import { ImportStatusBadge } from '@/components/import-run/ImportStatusBadge'
import type { ImportItem, ImportItemCategory } from '@/lib/database.types'
import {
  applyImportRun,
  discardImportRun,
  IMPORT_CATEGORIES,
  importItemsQuery,
  importRunQuery,
  importSourcesQuery,
  setImportSelection,
} from '@/lib/import-runs'
import { invalidateAdminData } from '@/lib/query-invalidation'

const fmt = (iso: string | null) => (iso ? new Date(iso).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' }) : '-')

function ItemRow({ runId, item, editable, selectable, onToggle, toggling }: {
  runId: string
  item: ImportItem
  editable: boolean
  selectable: boolean
  onToggle: (item: ImportItem, selected: boolean) => void
  toggling: boolean
}) {
  const [open, setOpen] = useState(false)
  const flagged = item.review?.perlu_review
  return (
    <Paper withBorder p="sm" data-run={runId}>
      <Group justify="space-between" wrap="nowrap" align="flex-start">
        <Group gap="sm" wrap="nowrap" align="flex-start">
          {selectable && (
            <Checkbox
              checked={item.selected}
              disabled={!editable || toggling}
              onChange={(e) => onToggle(item, e.currentTarget.checked)}
              aria-label={`Pilih pasal ${item.nomor}`}
              mt={2}
            />
          )}
          <Stack gap={4}>
            <Group gap="xs">
              <Text fw={600}>Pasal {item.nomor}</Text>
              {item.applied_at && <Badge color="green" variant="light">Sudah diterapkan</Badge>}
              {flagged && (
                <Badge color="orange" variant="light" leftSection={<IconAlertTriangle size={12} />} title={item.review?.catatan ?? undefined}>
                  Perlu cek PDF
                </Badge>
              )}
            </Group>
            {flagged && item.review?.catatan && <Text size="xs" c="orange">{item.review.catatan}</Text>}
            {item.notes.map((n, i) => (
              <Text key={i} size="xs" c="dimmed">{n}</Text>
            ))}
          </Stack>
        </Group>
        <Button variant="subtle" size="compact-sm" onClick={() => setOpen((o) => !o)} leftSection={open ? <IconChevronDown size={14} /> : <IconChevronRight size={14} />}>
          {open ? 'Tutup' : 'Lihat perubahan'}
        </Button>
      </Group>
      <Collapse expanded={open}>
        <Box mt="sm" pt="sm" style={{ borderTop: '1px solid var(--mantine-color-default-border)' }}>
          {open && <ImportItemDetail item={item} />}
        </Box>
      </Collapse>
    </Paper>
  )
}

export function ImportRunPage() {
  const { id = '' } = useParams()
  const queryClient = useQueryClient()
  // Null = belum dipilih admin: tampilkan kategori pertama yang berisi item.
  const [chosenCategory, setCategory] = useState<ImportItemCategory | null>(null)
  const [page, setPage] = useState(1)
  const [applyOpen, setApplyOpen] = useState(false)
  const [discardOpen, setDiscardOpen] = useState(false)
  const [confirmLarge, setConfirmLarge] = useState(false)

  const { data: run, isLoading, error } = useQuery(importRunQuery(id))
  const { data: sources } = useQuery(importSourcesQuery(false))
  const category: ImportItemCategory =
    chosenCategory ?? IMPORT_CATEGORIES.find((c) => (run?.summary?.counts?.[c.value] ?? 0) > 0)?.value ?? 'baru'
  const source = sources?.sources.find((s) => s.slug === run?.slug)
  const itemsEnabled = !!run && run.status !== 'queued' && run.status !== 'running' && run.status !== 'failed' && run.status !== 'needs_config'
  const { data: items, isFetching } = useQuery({ ...importItemsQuery(id, category, page), enabled: itemsEnabled })

  const refresh = () => queryClient.invalidateQueries({ queryKey: ['import'] })

  const select = useMutation({
    mutationFn: (body: Parameters<typeof setImportSelection>[1]) => setImportSelection(id, body),
    onSuccess: refresh,
    onError: (e: Error) => notifications.show({ title: 'Gagal mengubah pilihan', message: e.message, color: 'red' }),
  })

  const apply = useMutation({
    mutationFn: () => applyImportRun(id, confirmLarge),
    onSuccess: async (r) => {
      setApplyOpen(false)
      await Promise.all([refresh(), invalidateAdminData(queryClient)])
      const applied = r.summary?.applied
      notifications.show({
        title: 'Perubahan diterapkan',
        message: applied
          ? `${applied.diterapkan} pasal diterapkan${applied.dilewati ? `, ${applied.dilewati} dilewati karena sudah diedit lagi` : ''}. Pasal yang berubah ditandai perlu verifikasi.`
          : 'Pasal yang berubah ditandai perlu verifikasi.',
        color: 'green',
      })
    },
    onError: (e: Error) => notifications.show({ title: 'Gagal menerapkan', message: e.message, color: 'red' }),
  })

  const discard = useMutation({
    mutationFn: () => discardImportRun(id),
    onSuccess: async () => {
      setDiscardOpen(false)
      await refresh()
      notifications.show({ title: 'Draf dibuang', message: 'Tidak ada data yang diubah.', color: 'gray' })
    },
    onError: (e: Error) => notifications.show({ title: 'Gagal membuang draf', message: e.message, color: 'red' }),
  })

  if (isLoading) return <Loader />
  if (error || !run) return <Alert color="red" title="Gagal memuat run">{(error as Error | null)?.message ?? 'Run tidak ditemukan.'}</Alert>

  const editable = run.status === 'ready'
  const summary = run.summary
  const meta = IMPORT_CATEGORIES.find((c) => c.value === category)!
  const counts = summary?.counts
  const selectedTotal = summary?.selected ?? 0

  return (
    <Stack gap="md" pb={editable ? 90 : 0}>
      <Anchor component={Link} to="/sumber-data" size="sm">← Sumber Data</Anchor>
      <Card withBorder>
        <Group justify="space-between" align="flex-start">
          <Stack gap={4}>
            <Group gap="sm">
              <Title order={3}>{source ? `${source.kode} · ${source.label}` : run.slug}</Title>
              <ImportStatusBadge status={run.status} />
            </Group>
            <Text size="sm" c="dimmed">
              Diminta {fmt(run.created_at)} oleh {run.requested_by?.nama ?? '-'}
              {run.finished_at ? ` · selesai ${fmt(run.finished_at)}` : ''}
              {run.applied_at ? ` · diterapkan ${fmt(run.applied_at)} oleh ${run.applied_by?.nama ?? '-'}` : ''}
            </Text>
            {run.source_url && (
              <Anchor href={run.source_url} target="_blank" rel="noreferrer" size="sm">
                <Group gap={4}>Sumber <IconExternalLink size={14} /></Group>
              </Anchor>
            )}
          </Stack>
        </Group>
      </Card>

      {(run.status === 'queued' || run.status === 'running') && (
        <Alert color="blue" icon={<Loader size={16} />} title="Sedang diproses">
          Mengunduh dan membandingkan sumber. Halaman ini diperbarui otomatis.
        </Alert>
      )}
      {run.status === 'failed' && <Alert color="red" title="Pemeriksaan gagal">{run.error ?? 'Terjadi kesalahan.'}</Alert>}
      {run.status === 'needs_config' && (
        <Alert color="yellow" title="Perlu konfigurasi">
          Sumber memuat versi undang-undang yang belum ada di konfigurasi: <b>{run.unknown_versions.join(', ')}</b>. Tambahkan ke konfigurasi impor, lalu periksa ulang.
          {run.error && <Text size="sm" mt="xs">{run.error}</Text>}
        </Alert>
      )}
      {run.status === 'needs_config' ? null : run.unknown_versions.length > 0 && (
        <Alert color="yellow" title="Versi tidak dikenal">{run.unknown_versions.join(', ')}</Alert>
      )}
      {run.warnings.length > 0 && (
        <Alert color="orange" icon={<IconAlertTriangle />} title={`${run.warnings.length} peringatan`}>
          <List size="sm" spacing={2}>
            {run.warnings.map((w, i) => (
              <List.Item key={i}>Pasal {w.nomor}: {w.message}</List.Item>
            ))}
          </List>
        </Alert>
      )}
      {run.status === 'applied' && <Alert color="green" title="Draf sudah diterapkan">Perubahan yang dipilih sudah masuk ke database.</Alert>}
      {run.status === 'discarded' && <Alert color="gray" title="Draf dibuang">Tidak ada data yang diubah.</Alert>}

      {summary && itemsEnabled && (
        <>
          {summary.large_change && editable && (
            <Alert color="orange" icon={<IconAlertTriangle />} title="Perubahan besar">
              Run ini mengubah banyak pasal sekaligus. Periksa hasilnya dengan teliti sebelum menerapkan.
            </Alert>
          )}
          {summary.pdf_flagged > 0 && (
            <Alert color="orange" variant="light">
              {summary.pdf_flagged} pasal ditandai perlu dicek karena cakupan PDF resmi rendah.
            </Alert>
          )}
          <SegmentedControl
            fullWidth
            value={category}
            onChange={(v) => { setCategory(v as ImportItemCategory); setPage(1) }}
            data={IMPORT_CATEGORIES.map((c) => ({ value: c.value, label: `${c.label} (${counts?.[c.value] ?? 0})` }))}
            style={{ overflowX: 'auto' }}
          />
          <Group justify="space-between">
            <Text size="sm" c="dimmed" maw={640}>{meta.hint}</Text>
            {meta.selectable && editable && (
              <Group gap="xs">
                <Button size="compact-sm" variant="light" loading={select.isPending} onClick={() => select.mutate({ category, selected: true })}>Pilih semua</Button>
                <Button size="compact-sm" variant="default" loading={select.isPending} onClick={() => select.mutate({ category, selected: false })}>Kosongkan</Button>
              </Group>
            )}
          </Group>

          <Stack gap="xs" opacity={isFetching ? 0.7 : 1}>
            {items?.data.length === 0 && <Text c="dimmed" ta="center" py="lg">Tidak ada item di kategori ini.</Text>}
            {items?.data.map((item) => (
              <ItemRow
                key={item.id}
                runId={id}
                item={item}
                editable={editable}
                selectable={meta.selectable}
                toggling={select.isPending}
                onToggle={(it, selected) => select.mutate({ ids: [it.id], selected })}
              />
            ))}
          </Stack>
          {items && items.last_page > 1 && <Pagination value={page} onChange={setPage} total={items.last_page} />}
        </>
      )}

      {editable && (
        <Paper
          withBorder
          shadow="md"
          p="md"
          style={{ position: 'sticky', bottom: 0, zIndex: 10 }}
        >
          <Group justify="space-between">
            <Text fw={600}>{selectedTotal} item dipilih</Text>
            <Group>
              <Button color="red" variant="light" onClick={() => setDiscardOpen(true)}>Buang draft</Button>
              <Button disabled={selectedTotal === 0} onClick={() => { setConfirmLarge(false); setApplyOpen(true) }}>Terapkan</Button>
            </Group>
          </Group>
        </Paper>
      )}

      <Modal opened={applyOpen} onClose={() => setApplyOpen(false)} title="Terapkan perubahan?">
        <Stack>
          <Text size="sm">
            {selectedTotal} item terpilih akan diterapkan ke database. Pasal baru dan yang teksnya berubah ditandai perlu verifikasi. Pasal yang hilang dari sumber tidak dihapus.
          </Text>
          {counts && counts.konflik > 0 && (
            <Alert color="orange" variant="light">Item konflik yang dipilih akan menimpa edit admin.</Alert>
          )}
          {summary?.large_change && (
            <Checkbox
              checked={confirmLarge}
              onChange={(e) => setConfirmLarge(e.currentTarget.checked)}
              label="Saya sudah memeriksa perubahan besar ini"
            />
          )}
          <Group justify="flex-end">
            <Button variant="default" onClick={() => setApplyOpen(false)}>Batal</Button>
            <Button loading={apply.isPending} disabled={!!summary?.large_change && !confirmLarge} onClick={() => apply.mutate()}>Terapkan</Button>
          </Group>
        </Stack>
      </Modal>

      <Modal opened={discardOpen} onClose={() => setDiscardOpen(false)} title="Buang draft?">
        <Stack>
          <Text size="sm">Draf ini akan dibuang. Tidak ada data yang berubah, dan Anda bisa memeriksa pembaruan lagi nanti.</Text>
          <Group justify="flex-end">
            <Button variant="default" onClick={() => setDiscardOpen(false)}>Batal</Button>
            <Button color="red" loading={discard.isPending} onClick={() => discard.mutate()}>Buang draft</Button>
          </Group>
        </Stack>
      </Modal>
    </Stack>
  )
}
