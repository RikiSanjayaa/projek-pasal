import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
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
  LoadingOverlay,
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
import type { PasalUpdate, Pasal } from '@/lib/database.types'
import { getPasalQualityIssues, normalizePasalInput, normalizePasalNumber } from '@/lib/pasal-quality'
import { invalidatePasalData } from '@/lib/query-invalidation'

export function PasalEditPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [checkingQuality, setCheckingQuality] = useState(false)

  // Fetch pasal data
  const { data: pasal, isLoading: loadingPasal } = useQuery({
    queryKey: ['pasal', id],
    queryFn: async () => {
      return api.get<Pasal>(`/admin/pasal/${id}`)
    },
    enabled: !!id,
  })

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

  const form = useForm<PasalUpdate>({
    initialValues: {
      undang_undang_id: '',
      nomor: '',
      judul: '',
      isi: '',
      penjelasan: '',
      keywords: [],
    },
    validate: {
      undang_undang_id: (value) => (!value ? 'Pilih undang-undang' : null),
      nomor: (value) => (!value ? 'Nomor pasal wajib diisi' : null),
      isi: (value) => (!value ? 'Isi pasal wajib diisi' : null),
    },
  })

  const qualityIssues = useMemo(
    () => getPasalQualityIssues(form.values),
    [form.values]
  )

  // Update form when pasal data is loaded
  useEffect(() => {
    if (pasal) {
      form.setValues({
        undang_undang_id: pasal.undang_undang_id,
        nomor: pasal.nomor,
        judul: pasal.judul || '',
        isi: pasal.isi,
        penjelasan: pasal.penjelasan || '',
        keywords: pasal.keywords || [],
      })
    }
  }, [pasal])

  const updateMutation = useMutation({
    mutationFn: async (data: PasalUpdate) => {
      await api.put(`/admin/pasal/${id}`, data)
    },
    onSuccess: async () => {
      await invalidatePasalData(queryClient)
      notifications.show({
        title: 'Berhasil',
        message: 'Pasal berhasil diperbarui',
        color: 'green',
      })
      navigate(-1)
    },
    onError: (error: Error) => {
      notifications.show({
        title: 'Gagal',
        message: error.message,
        color: 'red',
      })
    },
  })

  const checkExistingDuplicate = async (values: PasalUpdate) => {
    if (!values.undang_undang_id || !values.nomor) return false

    const response = await api.get<PaginatedResponse<Pasal>>(`/admin/pasal${toQueryString({
      undang_undang_id: values.undang_undang_id,
      search: values.nomor,
      with_trashed: 1,
      per_page: 30,
    })}`)

    const targetNomor = normalizePasalNumber(values.nomor).toLowerCase()
    return response.data.some((item) => item.id !== id && normalizePasalNumber(item.nomor).toLowerCase() === targetNomor)
  }

  const handleSubmit = async (values: PasalUpdate) => {
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
          onConfirm: () => updateMutation.mutate(prepared),
        })
        return
      }

      updateMutation.mutate(prepared)
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
          onClick={() => navigate(-1)}
        >
          Kembali
        </Button>
      </Group>

      <div>
        <Title order={2}>Edit Pasal</Title>
        <Text c="dimmed">Perbarui data pasal</Text>
      </div>

      <Grid>
        <Grid.Col span={{ base: 12, md: 8 }}>
          <Card padding="lg" radius="md" withBorder pos="relative">
            <LoadingOverlay visible={loadingPasal} />

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
                  <Button variant="default" onClick={() => navigate(-1)}>
                    Batal
                  </Button>
                  <Button type="submit" loading={updateMutation.isPending || checkingQuality}>
                    Simpan Perubahan
                  </Button>
                </Group>
              </Stack>
            </form>
          </Card>
        </Grid.Col>

        <Grid.Col span={{ base: 12, md: 4 }}>
          <PasalLinksSidebar pasalId={id!} isEditMode={true} />
        </Grid.Col>
      </Grid>
    </Stack>
  )
}
