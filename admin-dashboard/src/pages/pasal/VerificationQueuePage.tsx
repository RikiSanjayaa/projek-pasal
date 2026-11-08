import { useMemo, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import {
  Alert,
  Anchor,
  Badge,
  Box,
  Button,
  Card,
  Checkbox,
  Divider,
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
  UnstyledButton,
} from '@mantine/core'
import { useDebouncedValue, useDisclosure } from '@mantine/hooks'
import { notifications } from '@mantine/notifications'
import { IconCircleCheck, IconEdit, IconExternalLink, IconSearch } from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { LegalText } from '@/components/LegalText'
import { isAmended, officialSourceFor, shouldShowRiwayatBadge, VERSI_STATUS } from '@/lib/pasal-versi'
import { api, toQueryString, type PaginatedResponse } from '@/lib/api'
import type { PasalWithUndangUndang } from '@/lib/database.types'
import { formatPasalLabel } from '@/lib/pasal-format'
import { invalidatePasalData } from '@/lib/query-invalidation'
import { verificationSummaryQuery } from '@/lib/verification'

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

  const { data: summary } = useQuery(verificationSummaryQuery)

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

      <Card padding="md">
        <Stack gap="md">
          <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="sm">
            {summary?.map((row) => {
              const percent = row.total ? Math.round((row.verified / row.total) * 100) : 0
              const active = filterUU === row.undang_undang_id
              return (
                <UnstyledButton
                  key={row.undang_undang_id}
                  p="sm"
                  aria-pressed={active}
                  onClick={() => setParam('uu', active ? null : row.undang_undang_id)}
                  style={{
                    borderRadius: 'var(--mantine-radius-md)',
                    border: `1px solid ${active ? 'var(--mantine-color-blue-filled)' : 'var(--mantine-color-default-border)'}`,
                    background: active ? 'var(--mantine-color-blue-light)' : undefined,
                  }}
                >
                  <Group justify="space-between" mb={6}>
                    <Badge variant="light">{row.kode}</Badge>
                    <Text size="sm" c="dimmed">
                      {row.verified} / {row.total} terverifikasi
                    </Text>
                  </Group>
                  <Progress value={percent} color={percent === 100 ? 'green' : 'yellow'} size="sm" />
                </UnstyledButton>
              )
            })}
          </SimpleGrid>

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

          <Divider />

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
        </Stack>
      </Card>

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
            <Card key={pasal.id} padding="md">
              <Stack gap="sm">
                <Group justify="space-between" align="flex-start" wrap="nowrap">
                  <Group gap="sm" align="flex-start" wrap="nowrap">
                    <Checkbox checked={selected.includes(pasal.id)} onChange={() => toggle(pasal.id)} mt={4} aria-label="Pilih pasal" />
                    <div>
                      <Group gap="xs">
                        <Badge variant="light">{pasal.undang_undang?.kode}</Badge>
                        <Text fw={600}>{formatPasalLabel(pasal.nomor)}</Text>
                        {pasal.versi_terakhir && isAmended(pasal) && shouldShowRiwayatBadge(pasal.versi_terakhir) && (
                          <Badge variant="outline" color={VERSI_STATUS[pasal.versi_terakhir.status].color} size="sm">
                            {VERSI_STATUS[pasal.versi_terakhir.status].label} {pasal.versi_terakhir.sumber}
                          </Badge>
                        )}
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

                <Spoiler maxHeight={220} showLabel="Lihat isi lengkap" hideLabel="Ringkas">
                  <Box p="sm" bg="var(--mantine-color-default-hover)" style={{ borderRadius: 'var(--mantine-radius-md)' }}>
                    <LegalText text={pasal.isi} size="sm" />
                  </Box>
                </Spoiler>

                {pasal.penjelasan && (
                  <Spoiler maxHeight={90} showLabel="Lihat penjelasan lengkap" hideLabel="Sembunyikan">
                    <Text size="xs" fw={700} c="dimmed" tt="uppercase" mb={4}>
                      Penjelasan
                    </Text>
                    <LegalText text={pasal.penjelasan} size="sm" />
                  </Spoiler>
                )}

                {(officialSourceFor(pasal) || pasal.undang_undang?.source_url) && (
                  <Group gap="md">
                    {officialSourceFor(pasal) && (
                      <Anchor href={officialSourceFor(pasal)!.href} target="_blank" rel="noreferrer" size="sm">
                        <Group gap={4}>
                          <IconExternalLink size={14} />
                          {officialSourceFor(pasal)!.label}
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
