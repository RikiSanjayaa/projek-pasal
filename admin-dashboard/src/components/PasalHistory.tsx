import { useState } from 'react'
import {
  Anchor,
  Badge,
  Box,
  Button,
  Card,
  Checkbox,
  Group,
  Loader,
  Modal,
  Select,
  SimpleGrid,
  Spoiler,
  Stack,
  Switch,
  Text,
  Textarea,
  TextInput,
  Timeline,
  Title,
} from '@mantine/core'
import { DateInput } from '@mantine/dates'
import { modals } from '@mantine/modals'
import { notifications } from '@mantine/notifications'
import { IconEdit, IconExternalLink, IconHistory, IconPlus, IconTrash } from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { DiffText } from '@/components/DiffText'
import { IconAction } from '@/components/IconAction'
import { LegalText } from '@/components/LegalText'
import { api } from '@/lib/api'
import type { PasalVersi, PasalVersiStatus, PasalWithUndangUndang } from '@/lib/database.types'
import { formatTanggal, VERSI_STATUS } from '@/lib/pasal-versi'
import { invalidatePasalData } from '@/lib/query-invalidation'

interface PasalHistoryProps {
  pasal: PasalWithUndangUndang
}

type VersiForm = {
  status: PasalVersiStatus
  sumber: string
  judul_sumber: string
  diundangkan: string | null
  berlaku_sejak: string | null
  naskah_resmi: string
  isi: string
  penjelasan: string
  /** Salin isi dan penjelasan versi ini ke pasal (rumusan berlaku). */
  terapkan: boolean
  /** Pasal belum punya riwayat: simpan rumusan sekarang sebagai versi asli lebih dulu. */
  simpan_asli: boolean
  sumber_asli: string
}

type Editing = { mode: 'create' } | { mode: 'edit'; versi: PasalVersi; isLatest: boolean }

const STATUS_OPTIONS = (Object.keys(VERSI_STATUS) as PasalVersiStatus[]).map((value) => ({
  value,
  label: VERSI_STATUS[value].label,
}))

/** "Undang-Undang Nomor 1 Tahun 2023 tentang ..." -> "UU 1/2023". */
function shortSource(namaLengkap: string | null | undefined, fallback: string): string {
  const match = namaLengkap?.match(/Nomor\s+(\d+)\s+Tahun\s+(\d{4})/i)
  return match ? `UU ${match[1]}/${match[2]}` : fallback
}

function emptyForm(pasal: PasalWithUndangUndang, hasHistory: boolean): VersiForm {
  return {
    status: 'diubah',
    sumber: '',
    judul_sumber: '',
    diundangkan: null,
    berlaku_sejak: null,
    naskah_resmi: '',
    // Mulai dari rumusan sekarang; admin tinggal mengubah bagian yang diganti.
    isi: pasal.isi,
    penjelasan: pasal.penjelasan ?? '',
    terapkan: true,
    simpan_asli: !hasHistory,
    sumber_asli: shortSource(pasal.undang_undang?.nama_lengkap, pasal.undang_undang?.kode ?? ''),
  }
}

function formFromVersi(versi: PasalVersi): VersiForm {
  return {
    status: versi.status,
    sumber: versi.sumber,
    judul_sumber: versi.judul_sumber ?? '',
    diundangkan: versi.diundangkan,
    berlaku_sejak: versi.berlaku_sejak,
    naskah_resmi: versi.naskah_resmi ?? '',
    isi: versi.isi,
    penjelasan: versi.penjelasan ?? '',
    terapkan: false,
    simpan_asli: false,
    sumber_asli: '',
  }
}

/** Riwayat rumusan pasal karena perubahan undang-undang, dari versi paling lama ke yang berlaku. */
export function PasalHistory({ pasal }: PasalHistoryProps) {
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState<Editing | null>(null)
  const [form, setForm] = useState<VersiForm | null>(null)
  // Versi yang ditampilkan sebagai teks biasa (tanpa tanda perubahan dari versi sebelumnya).
  const [plainIds, setPlainIds] = useState<Set<string>>(() => new Set())
  const togglePlain = (id: string) =>
    setPlainIds((current) => {
      const next = new Set(current)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })

  const { data: versions = [], isLoading } = useQuery({
    queryKey: ['pasal', 'riwayat', pasal.id],
    queryFn: () => api.get<PasalVersi[]>(`/admin/pasal/${pasal.id}/riwayat`),
  })

  const close = () => {
    setEditing(null)
    setForm(null)
  }

  const saveMutation = useMutation({
    mutationFn: async ({ target, values }: { target: Editing; values: VersiForm }) => {
      const body = {
        status: values.status,
        sumber: values.sumber.trim(),
        judul_sumber: values.judul_sumber.trim() || null,
        diundangkan: values.diundangkan || null,
        berlaku_sejak: values.berlaku_sejak || null,
        naskah_resmi: values.naskah_resmi.trim() || null,
        isi: values.isi,
        penjelasan: values.penjelasan.trim() || null,
        terapkan: values.terapkan,
      }
      if (target.mode === 'edit') {
        return api.put<PasalVersi>(`/admin/pasal-versi/${target.versi.id}`, body)
      }
      return api.post<PasalVersi>(`/admin/pasal/${pasal.id}/riwayat`, {
        ...body,
        simpan_asli: values.simpan_asli,
        sumber_asli: values.simpan_asli ? values.sumber_asli.trim() : null,
      })
    },
    onSuccess: async (_, { values }) => {
      await invalidatePasalData(queryClient)
      notifications.show({
        title: 'Riwayat disimpan',
        message: values.terapkan ? 'Rumusan pasal ikut diperbarui.' : 'Rumusan pasal tidak diubah.',
        color: 'green',
      })
      close()
    },
    onError: (error: Error) => notifications.show({ title: 'Gagal menyimpan riwayat', message: error.message, color: 'red' }),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/admin/pasal-versi/${id}`),
    onSuccess: async () => {
      await invalidatePasalData(queryClient)
      notifications.show({ title: 'Versi dihapus', message: 'Rumusan pasal yang berlaku tidak berubah.', color: 'green' })
    },
    onError: (error: Error) => notifications.show({ title: 'Gagal menghapus', message: error.message, color: 'red' }),
  })

  const openCreate = () => {
    setEditing({ mode: 'create' })
    setForm(emptyForm(pasal, versions.length > 0))
  }

  const openEdit = (versi: PasalVersi, isLatest: boolean) => {
    setEditing({ mode: 'edit', versi, isLatest })
    setForm(formFromVersi(versi))
  }

  const confirmDelete = (versi: PasalVersi) =>
    modals.openConfirmModal({
      title: 'Hapus versi riwayat?',
      children: (
        <Text size="sm">
          Versi {VERSI_STATUS[versi.status].label.toLowerCase()} dari {versi.sumber} dihapus dari riwayat. Isi pasal yang berlaku tidak
          berubah.
        </Text>
      ),
      labels: { confirm: 'Hapus', cancel: 'Batal' },
      confirmProps: { color: 'red' },
      onConfirm: () => deleteMutation.mutate(versi.id),
    })

  const set = <K extends keyof VersiForm>(key: K, value: VersiForm[K]) => setForm((current) => (current ? { ...current, [key]: value } : current))
  const canApply = editing?.mode === 'create' || (editing?.mode === 'edit' && editing.isLatest)

  return (
    <Card padding="lg">
      <Group justify="space-between" mb="md">
        <Group gap="xs">
          <IconHistory size={20} />
          <Title order={4}>Riwayat perubahan</Title>
        </Group>
        {pasal.is_active && (
          <Button size="xs" variant="light" leftSection={<IconPlus size={14} />} onClick={openCreate}>
            Tambah versi
          </Button>
        )}
      </Group>

      {isLoading ? (
        <Loader size="sm" />
      ) : versions.length === 0 ? (
        <Text size="sm" c="dimmed">
          Belum ada perubahan tercatat. Rumusan ini masih rumusan asli undang-undangnya.
        </Text>
      ) : (
        <Timeline active={versions.length - 1} bulletSize={20} lineWidth={2}>
          {versions.map((versi, index) => {
            const status = VERSI_STATUS[versi.status]
            const current = index === versions.length - 1
            const previous = index > 0 ? versions[index - 1] : null
            const showDiff = !!previous && !plainIds.has(versi.id)
            const diundangkan = formatTanggal(versi.diundangkan)
            const berlaku = formatTanggal(versi.berlaku_sejak)
            return (
              <Timeline.Item
                key={versi.id}
                title={
                  <Group justify="space-between" wrap="nowrap">
                    <Group gap="xs">
                      <Badge color={status.color} variant="light">
                        {status.label}
                      </Badge>
                      <Text fw={600}>{versi.sumber}</Text>
                      {current && (
                        <Badge color="green" variant="dot">
                          Berlaku
                        </Badge>
                      )}
                    </Group>
                    <Group gap={2} wrap="nowrap">
                      <IconAction label="Edit versi" icon={<IconEdit size={16} />} color="blue" onClick={() => openEdit(versi, current)} />
                      <IconAction
                        label="Hapus versi"
                        icon={<IconTrash size={16} />}
                        color="red"
                        loading={deleteMutation.isPending && deleteMutation.variables === versi.id}
                        onClick={() => confirmDelete(versi)}
                      />
                    </Group>
                  </Group>
                }
              >
                <Stack gap={6} mt={4}>
                  {versi.judul_sumber && (
                    <Text size="sm" c="dimmed">
                      {versi.judul_sumber}
                    </Text>
                  )}
                  {(diundangkan || berlaku) && (
                    <Text size="xs" c="dimmed">
                      {[diundangkan && `Diundangkan ${diundangkan}`, berlaku && `berlaku ${berlaku}`].filter(Boolean).join(', ')}
                    </Text>
                  )}
                  {versi.naskah_resmi && (
                    <Anchor href={versi.naskah_resmi} target="_blank" rel="noreferrer" size="sm">
                      <Group gap={4}>
                        <IconExternalLink size={14} />
                        Naskah resmi {versi.sumber}
                      </Group>
                    </Anchor>
                  )}
                  {previous && (
                    <Switch
                      size="xs"
                      checked={showDiff}
                      onChange={() => togglePlain(versi.id)}
                      label={`Tandai perubahan dari ${previous.sumber}`}
                    />
                  )}
                  <Spoiler
                    maxHeight={current && !previous ? 0 : 220}
                    showLabel={current && !previous ? 'Lihat rumusan' : 'Lihat rumusan lengkap'}
                    hideLabel="Sembunyikan"
                  >
                    <Box p="sm" bg="var(--mantine-color-default-hover)" style={{ borderRadius: 'var(--mantine-radius-md)' }}>
                      {showDiff && previous ? <DiffText before={previous.isi} after={versi.isi} /> : <LegalText text={versi.isi} size="sm" />}
                      {(versi.penjelasan || (showDiff && previous?.penjelasan)) && (
                        <Box mt="sm">
                          <Text size="xs" fw={700} c="dimmed" tt="uppercase" mb={4}>
                            Penjelasan
                          </Text>
                          {showDiff && previous ? (
                            <DiffText before={previous.penjelasan ?? ''} after={versi.penjelasan ?? ''} />
                          ) : (
                            <LegalText text={versi.penjelasan ?? ''} size="sm" />
                          )}
                        </Box>
                      )}
                    </Box>
                  </Spoiler>
                </Stack>
              </Timeline.Item>
            )
          })}
        </Timeline>
      )}

      <Modal
        opened={!!editing && !!form}
        onClose={close}
        title={editing?.mode === 'edit' ? 'Edit versi riwayat' : 'Tambah versi riwayat'}
        size="xl"
      >
        {form && editing && (
          <form
            onSubmit={(event) => {
              event.preventDefault()
              saveMutation.mutate({ target: editing, values: form })
            }}
          >
            <Stack>
              {editing.mode === 'create' && versions.length === 0 && (
                <Box p="sm" bg="var(--mantine-color-default-hover)" style={{ borderRadius: 'var(--mantine-radius-md)' }}>
                  <Checkbox
                    checked={form.simpan_asli}
                    onChange={(event) => set('simpan_asli', event.currentTarget.checked)}
                    label="Simpan rumusan sekarang sebagai versi asli dulu"
                    description="Pasal ini belum punya riwayat. Tanpa versi asli, rumusan lama hilang setelah isi pasal diganti."
                  />
                  {form.simpan_asli && (
                    <TextInput
                      mt="xs"
                      label="Sumber rumusan asli"
                      required
                      value={form.sumber_asli}
                      onChange={(event) => set('sumber_asli', event.currentTarget.value)}
                    />
                  )}
                </Box>
              )}

              <SimpleGrid cols={{ base: 1, sm: 2 }}>
                <Select
                  label="Status"
                  data={STATUS_OPTIONS}
                  value={form.status}
                  onChange={(value) => {
                    const status = (value ?? 'diubah') as PasalVersiStatus
                    setForm((current) =>
                      current ? { ...current, status, ...(status === 'dihapus' ? { isi: 'Dihapus.', penjelasan: '' } : {}) } : current
                    )
                  }}
                  allowDeselect={false}
                />
                <TextInput
                  label="Sumber"
                  placeholder="UU 1/2026"
                  required
                  value={form.sumber}
                  onChange={(event) => set('sumber', event.currentTarget.value)}
                />
              </SimpleGrid>
              <TextInput
                label="Judul undang-undang sumber"
                placeholder="Undang-Undang Nomor 1 Tahun 2026 tentang Penyesuaian Pidana"
                value={form.judul_sumber}
                onChange={(event) => set('judul_sumber', event.currentTarget.value)}
              />
              <SimpleGrid cols={{ base: 1, sm: 3 }}>
                <DateInput
                  label="Diundangkan"
                  valueFormat="D MMM YYYY"
                  clearable
                  value={form.diundangkan}
                  onChange={(value) => set('diundangkan', value)}
                />
                <DateInput
                  label="Berlaku sejak"
                  valueFormat="D MMM YYYY"
                  clearable
                  value={form.berlaku_sejak}
                  onChange={(value) => set('berlaku_sejak', value)}
                />
                <TextInput
                  label="Link naskah resmi"
                  placeholder="https://peraturan.bpk.go.id/..."
                  value={form.naskah_resmi}
                  onChange={(event) => set('naskah_resmi', event.currentTarget.value)}
                />
              </SimpleGrid>
              <Textarea
                label="Isi"
                required
                autosize
                minRows={4}
                maxRows={14}
                value={form.isi}
                onChange={(event) => set('isi', event.currentTarget.value)}
              />
              <Textarea
                label="Penjelasan"
                autosize
                minRows={2}
                maxRows={10}
                value={form.penjelasan}
                onChange={(event) => set('penjelasan', event.currentTarget.value)}
              />
              {canApply && (
                <Checkbox
                  checked={form.terapkan}
                  onChange={(event) => set('terapkan', event.currentTarget.checked)}
                  label="Jadikan rumusan berlaku"
                  description="Isi dan penjelasan pasal diganti dengan versi ini, lalu ikut tersinkron ke aplikasi mobile."
                />
              )}
              <Group justify="flex-end">
                <Button variant="default" onClick={close}>
                  Batal
                </Button>
                <Button type="submit" loading={saveMutation.isPending} disabled={!form.sumber.trim() || !form.isi.trim()}>
                  Simpan
                </Button>
              </Group>
            </Stack>
          </form>
        )}
      </Modal>
    </Card>
  )
}
