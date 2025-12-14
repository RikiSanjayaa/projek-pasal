import { useState } from 'react'
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
import { notifications } from '@mantine/notifications'
import { IconArrowLeft } from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { PasalLinksSidebar } from '@/components/PasalLinksSidebar'
import { useAuth } from '@/contexts/AuthContext'
import type { PasalInsert } from '@/lib/database.types'

// Type for pending link (before pasal is created)
interface PendingLink {
  targetPasalId: string
  targetPasalLabel: string
  keterangan: string
}

export function PasalCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { user } = useAuth()

  // State for pending links (will be created after pasal is saved)
  const [pendingLinks, setPendingLinks] = useState<PendingLink[]>([])

  // Fetch undang-undang
  const { data: undangUndangList } = useQuery({
    queryKey: ['undang_undang', 'list'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('undang_undang')
        .select('id, kode, nama')
        .eq('is_active', true)
        .order('kode')

      if (error) throw error
      return data as { id: string; kode: string; nama: string }[]
    },
  })

  // Fetch all pasal for autocomplete (when adding links)
  const { data: allPasalList } = useQuery({
    queryKey: ['pasal', 'all_for_link'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('pasal')
        .select('id, nomor, judul, undang_undang(kode)')
        .eq('is_active', true)
        .order('nomor')
        .limit(500)

      if (error) throw error
      return data as { id: string; nomor: string; judul: string | null; undang_undang: { kode: string } }[]
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

  const createMutation = useMutation({
    mutationFn: async (data: PasalInsert) => {
      // 1. Create pasal
      const { data: result, error } = await supabase
        .from('pasal')
        .insert({
          ...data,
          created_by: user?.id,
          updated_by: user?.id,
        } as never)
        .select('id')
        .single()

      if (error) throw error
      if (!result) {
        throw new Error('Gagal membuat pasal. Pastikan Anda terdaftar sebagai admin.')
      }

      const newPasalId = (result as { id: string }).id

      // 2. Create pending links if any
      if (pendingLinks.length > 0) {
        const linksToInsert = pendingLinks.map((link) => ({
          source_pasal_id: newPasalId,
          target_pasal_id: link.targetPasalId,
          keterangan: link.keterangan || null,
          created_by: user?.id,
        }))

        const { error: linkError } = await supabase
          .from('pasal_links')
          .insert(linksToInsert as never)

        if (linkError) {
          console.error('Error creating links:', linkError)
          // Don't throw - pasal already created, just notify about link failure
          notifications.show({
            title: 'Peringatan',
            message: 'Pasal berhasil dibuat, tetapi gagal membuat beberapa link pasal terkait.',
            color: 'yellow',
          })
        }
      }

      return result as { id: string }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal'] })
      queryClient.invalidateQueries({ queryKey: ['pasal_links'] })
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

  const handleSubmit = (values: PasalInsert) => {
    createMutation.mutate(values)
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
          <Card shadow="sm" padding="lg" radius="md" withBorder>
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
                  <Button variant="default" onClick={() => navigate('/pasal')}>
                    Batal
                  </Button>
                  <Button type="submit" loading={createMutation.isPending}>
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
