import { useEffect } from 'react'
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
import { notifications } from '@mantine/notifications'
import { IconArrowLeft } from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api, type PaginatedResponse } from '@/lib/api'
import { PasalLinksSidebar } from '@/components/PasalLinksSidebar'
import type { PasalUpdate, Pasal } from '@/lib/database.types'

export function PasalEditPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

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
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal'] })
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

  const handleSubmit = (values: PasalUpdate) => {
    updateMutation.mutate(values)
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
                  minRows={6}
                  required
                  {...form.getInputProps('isi')}
                />

                <Textarea
                  label="Penjelasan"
                  placeholder="Penjelasan atau tafsir pasal (opsional)"
                  minRows={3}
                  {...form.getInputProps('penjelasan')}
                />

                <TagsInput
                  label="Keywords"
                  placeholder="Ketik keyword dan tekan Enter"
                  description="Keywords untuk memudahkan pencarian"
                  {...form.getInputProps('keywords')}
                />

                <Group justify="flex-end" mt="md">
                  <Button variant="default" onClick={() => navigate(-1)}>
                    Batal
                  </Button>
                  <Button type="submit" loading={updateMutation.isPending}>
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
