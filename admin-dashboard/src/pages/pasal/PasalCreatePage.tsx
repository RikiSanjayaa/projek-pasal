import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Title,
  Text,
  Stack,
  Card,
  Group,
  Button,
  TextInput,
  Textarea,
  Select,
  TagsInput,
  Grid,
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { modals } from '@mantine/modals'
import { notifications } from '@mantine/notifications'
import { IconArrowLeft, IconWand } from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api, toQueryString, type PaginatedResponse } from '@/lib/api'
import { PasalQualityAlert } from '@/components/PasalQualityAlert'
import { PasalLinksSidebar } from '@/components/PasalLinksSidebar'
import type { Pasal, PasalInsert, PasalWithUndangUndang } from '@/lib/database.types'
import { getPasalQualityIssues, normalizePasalInput, normalizePasalNumber } from '@/lib/pasal-quality'
import { invalidatePasalData } from '@/lib/query-invalidation'

// Type for pending link (before pasal is created)
interface PendingLink {
  targetPasalId: string
  targetPasalLabel: string
  keterangan: string
}

export function PasalCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  // State for pending links (will be created after pasal is saved)
  const [pendingLinks, setPendingLinks] = useState<PendingLink[]>([])
  const [checkingQuality, setCheckingQuality] = useState(false)

  // Fetch undang-undang
  const { data: undangUndangList } = useQuery({
    queryKey: ['undang_undang', 'list'],
    queryFn: async () => {
      const response = await api.get<PaginatedResponse<{ id: string; kode: string; nama: string }>>(
        '/admin/undang-undang?is_active=1&per_page=200'
      )
      return response.data
    },
  })

  // Fetch all pasal for autocomplete (when adding links)
  const { data: allPasalList } = useQuery({
    queryKey: ['pasal', 'all_for_link'],
    queryFn: async () => {
      const response = await api.get<PaginatedResponse<PasalWithUndangUndang>>(
        '/admin/pasal?is_active=1&per_page=500'
      )
      return response.data
    },
  })

  const form = useForm<PasalInsert>({
    initialValues: {
      undang_undang_id: '',
      nomor: '',
      judul: '',
      isi: '',
      penjelasan: '',
      keywords: [],
    },
    validate: {
      undang_undang_id: (value: string) => (!value ? 'Pilih undang-undang' : null),
      nomor: (value: string) => (!value ? 'Nomor pasal wajib diisi' : null),
      isi: (value: string) => (!value ? 'Isi pasal wajib diisi' : null),
    },
  })

  const qualityIssues = useMemo(
    () => getPasalQualityIssues(form.values),
    [form.values]
  )

  const createMutation = useMutation({
    mutationFn: async (data: PasalInsert) => {
      // 1. Create pasal
      const result = await api.post<{ id: string }>('/admin/pasal', data)
      const newPasalId = result.id

      // 2. Create pending links if any
      if (pendingLinks.length > 0) {
        try {
          await Promise.all(
            pendingLinks.map((link) =>
              api.post(`/admin/pasal/${newPasalId}/links`, {
                target_pasal_id: link.targetPasalId,
                keterangan: link.keterangan || null,
              })
            )
          )
        } catch {
          notifications.show({
            title: 'Peringatan',
            message: 'Pasal berhasil dibuat, tetapi gagal membuat beberapa link pasal terkait.',
            color: 'yellow',
          })
        }
      }

      return result as { id: string }
    },
    onSuccess: async () => {
      await invalidatePasalData(queryClient)
      notifications.show({
        title: 'Berhasil',
        message: pendingLinks.length > 0
          ? `Pasal berhasil ditambahkan dengan ${pendingLinks.length} link terkait.`
          : 'Pasal berhasil ditambahkan.',
        color: 'green',
      })
      navigate('/pasal')
    },
    onError: (error: Error) => {
      notifications.show({
        title: 'Gagal',
        message: error.message,
        color: 'red',
      })
    },
  })

  const checkExistingDuplicate = async (values: PasalInsert) => {
    if (!values.undang_undang_id || !values.nomor) return false

    const response = await api.get<PaginatedResponse<Pasal>>(`/admin/pasal${toQueryString({
      undang_undang_id: values.undang_undang_id,
      search: values.nomor,
      with_trashed: 1,
      per_page: 30,
    })}`)

    const targetNomor = normalizePasalNumber(values.nomor).toLowerCase()
    return response.data.some((item) => normalizePasalNumber(item.nomor).toLowerCase() === targetNomor)
  }

  const handleSubmit = async (values: PasalInsert) => {
    const prepared = normalizePasalInput(values)
    form.setValues(prepared)
    setCheckingQuality(true)

    try {
      const hasExistingDuplicate = await checkExistingDuplicate(prepared)
      const issues = getPasalQualityIssues(prepared, { hasExistingDuplicate })
      const hasErrors = issues.some((issue) => issue.severity === 'error')
      const hasWarnings = issues.some((issue) => issue.severity === 'warning')

      if (hasErrors) {
        notifications.show({
          title: 'Data belum bisa disimpan',
          message: 'Perbaiki nomor duplikat atau field wajib terlebih dahulu.',
          color: 'red',
        })
        return
      }

      if (hasWarnings) {
        modals.openConfirmModal({
          title: 'Quality check pasal',
          children: <PasalQualityAlert issues={issues} compact />,
          labels: { confirm: 'Tetap Simpan', cancel: 'Perbaiki Dulu' },
          confirmProps: { color: 'orange' },
          onConfirm: () => createMutation.mutate(prepared),
        })
        return
      }

      createMutation.mutate(prepared)
    } finally {
      setCheckingQuality(false)
    }
  }

  const cleanFormText = () => {
    const prepared = normalizePasalInput(form.values)
    form.setValues(prepared)
    notifications.show({
      title: 'Teks dirapikan',
      message: 'Spasi, nomor pasal, dan typo OCR umum sudah dibersihkan.',
      color: 'blue',
    })
  }

  return (
    <Stack gap="lg">
      <Group>
        <Button
          variant="subtle"
          leftSection={<IconArrowLeft size={18} />}
          onClick={() => navigate('/pasal')}
        >
          Kembali
        </Button>
      </Group>

      <div>
        <Title order={2}>Tambah Pasal Baru</Title>
        <Text c="dimmed">Isi form di bawah untuk menambahkan pasal baru</Text>
      </div>

      <Grid>
        <Grid.Col span={{ base: 12, md: 8 }}>
          <Card padding="lg" radius="md" withBorder>
            <form onSubmit={form.onSubmit(handleSubmit)}>
              <Stack gap="md">
                <Select
                  label="Undang-Undang"
                  placeholder="Pilih undang-undang"
                  data={
                    undangUndangList?.map((uu) => ({
                      value: uu.id,
                      label: `${uu.kode} - ${uu.nama}`,
                    })) || []
                  }
                  required
                  {...form.getInputProps('undang_undang_id')}
                />

                <TextInput
                  label="Nomor Pasal"
                  placeholder='Contoh: 340, 27 ayat (3), dll'
                  required
                  {...form.getInputProps('nomor')}
                />

                <TextInput
                  label="Judul Pasal"
                  placeholder="Contoh: Pembunuhan Berencana (opsional)"
                  {...form.getInputProps('judul')}
                />

                <Textarea
                  label="Isi Pasal"
                  placeholder="Masukkan isi lengkap pasal..."
                  autosize
                  minRows={12}
                  maxRows={28}
                  resize="vertical"
                  required
                  {...form.getInputProps('isi')}
                />

                <Textarea
                  label="Penjelasan"
                  placeholder="Penjelasan atau tafsir pasal (opsional)"
                  autosize
                  minRows={8}
                  maxRows={20}
                  resize="vertical"
                  {...form.getInputProps('penjelasan')}
                />

                <TagsInput
                  label="Keywords"
                  placeholder="Ketik keyword dan tekan Enter"
                  description="Keywords untuk memudahkan pencarian"
                  {...form.getInputProps('keywords')}
                />

                <PasalQualityAlert issues={qualityIssues} />

                <Group justify="flex-end" mt="md">
                  <Button variant="light" leftSection={<IconWand size={16} />} onClick={cleanFormText}>
                    Rapikan Teks
                  </Button>
                  <Button variant="default" onClick={() => navigate('/pasal')}>
                    Batal
                  </Button>
                  <Button type="submit" loading={createMutation.isPending || checkingQuality}>
                    {pendingLinks.length > 0 ? `Simpan dengan ${pendingLinks.length} Link` : 'Simpan'}
                  </Button>
                </Group>
              </Stack>
            </form>
          </Card>
        </Grid.Col>

        <Grid.Col span={{ base: 12, md: 4 }}>
          <PasalLinksSidebar
            isCreateMode={true}
            pendingLinks={pendingLinks}
            onAddPendingLink={(link) => {
              // Check if already added
              if (pendingLinks.some((l) => l.targetPasalId === link.targetPasalId)) {
                notifications.show({
                  title: 'Peringatan',
                  message: 'Pasal ini sudah ditambahkan ke daftar link',
                  color: 'yellow',
                })
                return
              }
              setPendingLinks([...pendingLinks, link])
            }}
            onRemovePendingLink={(targetPasalId) => {
              setPendingLinks(pendingLinks.filter((l) => l.targetPasalId !== targetPasalId))
            }}
            allPasalList={allPasalList}
          />
        </Grid.Col>
      </Grid>
    </Stack>
  )
}
