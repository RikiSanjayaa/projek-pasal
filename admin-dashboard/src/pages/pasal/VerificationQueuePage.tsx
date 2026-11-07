import { useMemo, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import {
  Alert,
  Anchor,
  Badge,
  Button,
  Card,
  Checkbox,
  Group,
  Loader,
  Modal,
  Pagination,
  Progress,
  Select,
  SimpleGrid,
  Spoiler,
  Stack,
  Text,
  TextInput,
  Title,
} from '@mantine/core'
import { useDebouncedValue, useDisclosure } from '@mantine/hooks'
import { notifications } from '@mantine/notifications'
import { IconCircleCheck, IconEdit, IconExternalLink, IconSearch } from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { api, toQueryString, type PaginatedResponse } from '@/lib/api'
import type { PasalWithUndangUndang, VerificationSummaryRow } from '@/lib/database.types'
import { formatPasalLabel } from '@/lib/pasal-format'
import { invalidatePasalData } from '@/lib/query-invalidation'

const PAGE_SIZE = 10

export function VerificationQueuePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [searchParams, setSearchParams] = useSearchParams()
  const filterUU = searchParams.get('uu')
  const page = Number(searchParams.get('page') || '1')
  const [search, setSearch] = useState('')
  const [debouncedSearch] = useDebouncedValue(search, 300)
  const [selected, setSelected] = useState<string[]>([])
  const [confirmOpened, { open: openConfirm, close: closeConfirm }] = useDisclosure(false)

  const setParam = (key: string, value: string | null) => {
    const params = new URLSearchParams(searchParams)
    if (value) params.set(key, value)
    else params.delete(key)
    if (key !== 'page') params.delete('page')
    setSearchParams(params)
    setSelected([])
  }

  const { data: summary } = useQuery({
    queryKey: ['pasal', 'verification-summary'],
    queryFn: async () => (await api.get<{ data: VerificationSummaryRow[] }>('/admin/pasal-verification-summary')).data,
  })

  const { data: queue, isLoading } = useQuery({
    queryKey: ['pasal', 'verification-queue', filterUU, debouncedSearch, page],
    queryFn: () =>
      api.get<PaginatedResponse<PasalWithUndangUndang>>(
        `/admin/pasal${toQueryString({
          verification_status: 'perlu_verifikasi',
          is_active: 1,
          undang_undang_id: filterUU,
          search: debouncedSearch.trim(),
          page,
          per_page: PAGE_SIZE,
        })}`
      ),
  })

  const items = useMemo(() => queue?.data ?? [], [queue])
  const allSelected = items.length > 0 && items.every((item) => selected.includes(item.id))

  const verifyMutation = useMutation({
    mutationFn: (ids: string[]) => api.post<{ verified: number }>('/admin/pasal/bulk-verify', { ids }),
    onSuccess: async (result) => {
      setSelected([])
      closeConfirm()
      await invalidatePasalData(queryClient)
      notifications.show({ title: 'Terverifikasi', message: `${result.verified} pasal ditandai sesuai naskah resmi.`, color: 'green' })
    },
    onError: (error: Error) => notifications.show({ title: 'Gagal memverifikasi', message: error.message, color: 'red' }),
  })

  const toggle = (id: string) =>
    setSelected((current) => (current.includes(id) ? current.filter((value) => value !== id) : [...current, id]))

  return (
    <Stack gap="lg">
      <div>
        <Title order={2}>Verifikasi Pasal</Title>
        <Text c="dimmed">
          Cocokkan teks hasil import dengan naskah resmi. Pasal yang belum diverifikasi tetap tampil di mobile dengan label peringatan.
        </Text>
      </div>

      <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }}>
        {summary?.map((row) => {
          const percent = row.total ? Math.round((row.verified / row.total) * 100) : 0
          return (
            <Card
              key={row.undang_undang_id}
              withBorder
              padding="md"
              radius="md"
              style={{ cursor: 'pointer', borderColor: filterUU === row.undang_undang_id ? 'var(--mantine-color-blue-filled)' : undefined }}
              onClick={() => setParam('uu', filterUU === row.undang_undang_id ? null : row.undang_undang_id)}
            >
              <Group justify="space-between" mb="xs">
                <Badge variant="light">{row.kode}</Badge>
                <Text size="sm" c="dimmed">
                  {row.verified} / {row.total} terverifikasi
                </Text>
              </Group>
              <Progress value={percent} color={percent === 100 ? 'green' : 'yellow'} />
              <Text size="xs" c="dimmed" mt={6}>
                {row.total - row.verified} pasal menunggu
              </Text>
            </Card>
          )
        })}
      </SimpleGrid>

      <Card withBorder padding="md" radius="md">
        <Group wrap="wrap" align="flex-end">
          <TextInput
            placeholder="Cari nomor atau isi pasal..."
            leftSection={<IconSearch size={16} />}
            value={search}
            onChange={(event) => {
              setSearch(event.target.value)
              setParam('page', null)
            }}
            style={{ flex: 1 }}
          />
          <Select
            placeholder="Semua undang-undang"
            data={summary?.map((row) => ({ value: row.undang_undang_id, label: `${row.kode} - ${row.nama}` })) ?? []}
            value={filterUU}
            onChange={(value) => setParam('uu', value)}
            clearable
            w={{ base: '100%', sm: 280 }}
          />
        </Group>
      </Card>

      <Group justify="space-between">
        <Checkbox
          label={`Pilih semua di halaman ini (${items.length})`}
          checked={allSelected}
          indeterminate={!allSelected && selected.length > 0}
          onChange={() => setSelected(allSelected ? [] : items.map((item) => item.id))}
          disabled={items.length === 0}
        />
        <Group gap="xs">
          <Text size="sm" c="dimmed">
            {queue?.total ?? 0} pasal menunggu verifikasi
          </Text>
          <Button color="green" leftSection={<IconCircleCheck size={16} />} disabled={selected.length === 0} onClick={openConfirm}>
            Verifikasi {selected.length > 0 ? `${selected.length} terpilih` : 'terpilih'}
          </Button>
        </Group>
      </Group>

      {isLoading ? (
        <Group justify="center" p="xl">
          <Loader />
        </Group>
      ) : items.length === 0 ? (
        <Alert color="green" variant="light" icon={<IconCircleCheck size={18} />} title="Antrean kosong">
          Semua pasal {filterUU ? 'pada undang-undang ini ' : ''}sudah diverifikasi.
        </Alert>
      ) : (
        <Stack gap="md">
          {items.map((pasal) => (
            <Card key={pasal.id} withBorder padding="md" radius="md">
              <Stack gap="sm">
                <Group justify="space-between" align="flex-start" wrap="nowrap">
                  <Group gap="sm" align="flex-start" wrap="nowrap">
                    <Checkbox checked={selected.includes(pasal.id)} onChange={() => toggle(pasal.id)} mt={4} aria-label="Pilih pasal" />
                    <div>
                      <Group gap="xs">
                        <Badge variant="light">{pasal.undang_undang?.kode}</Badge>
                        <Text fw={600}>{formatPasalLabel(pasal.nomor)}</Text>
                      </Group>
                      {pasal.judul && (
                        <Text size="sm" c="dimmed">
                          {pasal.judul}
                        </Text>
                      )}
                    </div>
                  </Group>
                  <Group gap="xs" wrap="nowrap">
                    <Button size="xs" variant="default" leftSection={<IconEdit size={14} />} onClick={() => navigate(`/pasal/${pasal.id}/edit`)}>
                      Koreksi
                    </Button>
                    <Button
                      size="xs"
                      color="green"
                      leftSection={<IconCircleCheck size={14} />}
                      loading={verifyMutation.isPending && verifyMutation.variables?.includes(pasal.id)}
                      onClick={() => verifyMutation.mutate([pasal.id])}
                    >
                      Verifikasi
                    </Button>
                  </Group>
                </Group>

                <Card withBorder padding="sm" bg="var(--mantine-color-default-hover)">
                  <Text size="sm" style={{ whiteSpace: 'pre-wrap' }}>
                    {pasal.isi}
                  </Text>
                </Card>

                {pasal.penjelasan && (
                  <Spoiler maxHeight={60} showLabel="Lihat penjelasan lengkap" hideLabel="Sembunyikan">
                    <Text size="sm" c="dimmed" style={{ whiteSpace: 'pre-wrap' }}>
                      <Text span fw={500}>
                        Penjelasan:{' '}
                      </Text>
                      {pasal.penjelasan}
                    </Text>
                  </Spoiler>
                )}

                {(pasal.undang_undang?.official_url || pasal.undang_undang?.source_url) && (
                  <Group gap="md">
                    {pasal.undang_undang?.official_url && (
                      <Anchor href={pasal.undang_undang.official_url} target="_blank" rel="noreferrer" size="sm">
                        <Group gap={4}>
                          <IconExternalLink size={14} />
                          Naskah resmi
                        </Group>
                      </Anchor>
                    )}
                    {pasal.undang_undang?.source_url && (
                      <Anchor href={pasal.undang_undang.source_url} target="_blank" rel="noreferrer" size="sm" c="dimmed">
                        <Group gap={4}>
                          <IconExternalLink size={14} />
                          Sumber teks
                        </Group>
                      </Anchor>
                    )}
                  </Group>
                )}
              </Stack>
            </Card>
          ))}
        </Stack>
      )}

      {(queue?.total ?? 0) > PAGE_SIZE && (
        <Group justify="center">
          <Pagination total={Math.ceil((queue?.total ?? 0) / PAGE_SIZE)} value={page} onChange={(value) => setParam('page', String(value))} />
        </Group>
      )}

      <Modal opened={confirmOpened} onClose={closeConfirm} title="Verifikasi pasal terpilih" centered>
        <Stack>
          <Text size="sm">
            Anda akan menandai {selected.length} pasal sebagai sesuai naskah resmi. Pastikan setiap pasal sudah Anda cocokkan dengan naskah resmi.
          </Text>
          <Group justify="flex-end">
            <Button variant="default" onClick={closeConfirm}>
              Batal
            </Button>
            <Button color="green" loading={verifyMutation.isPending} onClick={() => verifyMutation.mutate(selected)}>
              Verifikasi {selected.length} pasal
            </Button>
          </Group>
        </Stack>
      </Modal>
    </Stack>
  )
}
