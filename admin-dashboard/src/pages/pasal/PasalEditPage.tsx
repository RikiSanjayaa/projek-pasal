import { useEffect, useState } from 'react'
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
  Divider,
  Autocomplete,
  Badge,
  ActionIcon,
  Tooltip,
  Loader,
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { notifications } from '@mantine/notifications'
import { IconArrowLeft, IconPlus, IconX, IconLink } from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/contexts/AuthContext'
import type { PasalUpdate, Pasal } from '@/lib/database.types'

// Type for pasal link with relations
interface PasalLinkWithRelations {
  id: string
  source_pasal_id: string
  target_pasal_id: string
  keterangan: string | null
  target_pasal: {
    id: string
    nomor: string
    judul: string | null
    undang_undang: { kode: string }
  }
}

export function PasalEditPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { user } = useAuth()

  // State for link management
  const [linkSearchValue, setLinkSearchValue] = useState('')
  const [linkKeterangan, setLinkKeterangan] = useState('')

  // Fetch pasal data
  const { data: pasal, isLoading: loadingPasal } = useQuery({
    queryKey: ['pasal', id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('pasal')
        .select('*')
        .eq('id', id!)
        .single()

      if (error) throw error
      return data as Pasal
    },
    enabled: !!id,
  })

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

  // Fetch pasal links (only where current pasal is source and link is active)
  const { data: pasalLinks, isLoading: isLoadingLinks } = useQuery({
    queryKey: ['pasal_links', id],
    queryFn: async () => {
      if (!id) return [] as PasalLinkWithRelations[]

      const { data, error } = await supabase
        .from('pasal_links')
        .select(`
          id,
          source_pasal_id,
          target_pasal_id,
          keterangan,
          target_pasal:pasal!pasal_links_target_pasal_id_fkey(id, nomor, judul, undang_undang(kode))
        `)
        .eq('source_pasal_id', id)
        .eq('is_active', true)

      if (error) throw error
      return data as unknown as PasalLinkWithRelations[]
    },
    enabled: !!id,
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

  // Add link mutation
  const addLinkMutation = useMutation({
    mutationFn: async ({ targetPasalId, keterangan }: { targetPasalId: string; keterangan?: string }) => {
      const { data, error } = await supabase
        .from('pasal_links')
        .insert({
          source_pasal_id: id!,
          target_pasal_id: targetPasalId,
          keterangan: keterangan || null,
          created_by: user?.id,
        } as never)
        .select()

      if (error) throw error
      if (!data || data.length === 0) {
        throw new Error('Gagal menambah link. Pastikan Anda terdaftar sebagai admin.')
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal_links', id] })
      notifications.show({
        title: 'Berhasil',
        message: 'Link pasal berhasil ditambahkan',
        color: 'green',
      })
      setLinkSearchValue('')
      setLinkKeterangan('')
    },
    onError: (error) => {
      notifications.show({
        title: 'Gagal',
        message: `Error: ${(error as Error).message}`,
        color: 'red',
      })
    },
  })

  // Delete link mutation (soft delete)
  const deleteLinkMutation = useMutation({
    mutationFn: async (linkId: string) => {
      const { data, error } = await supabase
        .from('pasal_links')
        .update({
          is_active: false,
          deleted_at: new Date().toISOString(),
        } as never)
        .eq('id', linkId)
        .select()

      if (error) throw error
      if (!data || data.length === 0) {
        throw new Error('Gagal menghapus link. Pastikan Anda terdaftar sebagai admin.')
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal_links', id] })
      notifications.show({
        title: 'Berhasil',
        message: 'Link pasal berhasil dihapus',
        color: 'green',
      })
    },
    onError: (error) => {
      notifications.show({
        title: 'Gagal',
        message: `Error: ${(error as Error).message}`,
        color: 'red',
      })
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
      const { data: result, error } = await supabase
        .from('pasal')
        .update({
          ...data,
          updated_by: user?.id,
        } as never)
        .eq('id', id!)
        .select()

      if (error) throw error

      // Check if update actually happened (RLS might silently block)
      if (!result || result.length === 0) {
        throw new Error('Gagal memperbarui. Pastikan Anda terdaftar sebagai admin di database.')
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal'] })
      notifications.show({
        title: 'Berhasil',
        message: 'Pasal berhasil diperbarui',
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

  const handleSubmit = (values: PasalUpdate) => {
    updateMutation.mutate(values)
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
        <Title order={2}>Edit Pasal</Title>
        <Text c="dimmed">Perbarui data pasal</Text>
      </div>

      <Card shadow="sm" padding="lg" radius="md" withBorder pos="relative">
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
              <Button variant="default" onClick={() => navigate('/pasal')}>
                Batal
              </Button>
              <Button type="submit" loading={updateMutation.isPending}>
                Simpan Perubahan
              </Button>
            </Group>
          </Stack>
        </form>
      </Card>

      {/* Pasal Terkait Section */}
      <Card shadow="sm" padding="lg" radius="md" withBorder>
        <Group mb="md">
          <IconLink size={20} />
          <Title order={4}>Pasal Terkait</Title>
        </Group>

        {isLoadingLinks ? (
          <Group justify="center" py="md">
            <Loader size="sm" />
          </Group>
        ) : (
          <Stack gap="md">
            {/* Existing links */}
            {pasalLinks && pasalLinks.length > 0 ? (
              <Stack gap="xs">
                {pasalLinks.map((link) => {
                  const targetPasal = link.target_pasal

                  return (
                    <Card key={link.id} withBorder padding="xs" radius="sm">
                      <Group justify="space-between">
                        <Group gap="xs">
                          <Badge size="sm" color="gray" variant="light">
                            {targetPasal?.undang_undang?.kode}
                          </Badge>
                          <Text size="sm" fw={500}>
                            Pasal {targetPasal?.nomor}
                          </Text>
                          {targetPasal?.judul && (
                            <Text size="xs" c="dimmed">
                              - {targetPasal?.judul}
                            </Text>
                          )}
                        </Group>
                        <Tooltip label="Hapus link">
                          <ActionIcon
                            size="sm"
                            variant="subtle"
                            color="red"
                            onClick={() => deleteLinkMutation.mutate(link.id)}
                            loading={deleteLinkMutation.isPending}
                          >
                            <IconX size={14} />
                          </ActionIcon>
                        </Tooltip>
                      </Group>
                      {link.keterangan && (
                        <Text size="xs" c="dimmed" mt={4}>
                          Keterangan: {link.keterangan}
                        </Text>
                      )}
                    </Card>
                  )
                })}
              </Stack>
            ) : (
              <Text size="sm" c="dimmed" ta="center" py="sm">
                Tidak ada pasal terkait
              </Text>
            )}

            {/* Add new link form */}
            <Divider label="Tambah Pasal Terkait" labelPosition="center" />

            <Stack gap="xs">
              <Autocomplete
                label="Cari Pasal"
                placeholder="Ketik untuk mencari pasal..."
                data={
                  allPasalList
                    ?.filter((p) => p.id !== id)
                    .filter((p) => !pasalLinks?.some(
                      (link) => link.target_pasal_id === p.id
                    ))
                    .map((p) => ({
                      value: p.id,
                      label: `${p.undang_undang.kode} - Pasal ${p.nomor}${p.judul ? ` (${p.judul})` : ''}`,
                    })) || []
                }
                value={linkSearchValue}
                onChange={setLinkSearchValue}
              />

              <TextInput
                label="Keterangan"
                placeholder="Keterangan hubungan antar pasal (opsional)"
                value={linkKeterangan}
                onChange={(e) => setLinkKeterangan(e.currentTarget.value)}
              />

              <Button
                leftSection={<IconPlus size={16} />}
                disabled={!linkSearchValue}
                loading={addLinkMutation.isPending}
                onClick={() => {
                  const selectedItem = allPasalList?.find(
                    (p) => `${p.undang_undang.kode} - Pasal ${p.nomor}${p.judul ? ` (${p.judul})` : ''}` === linkSearchValue
                  )
                  if (selectedItem) {
                    addLinkMutation.mutate({
                      targetPasalId: selectedItem.id,
                      keterangan: linkKeterangan || undefined,
                    })
                  }
                }}
              >
                Tambah Link
              </Button>
            </Stack>
          </Stack>
        )}
      </Card>
    </Stack>
  )
}
