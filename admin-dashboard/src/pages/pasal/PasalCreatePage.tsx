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
  Alert,
  Divider,
  Autocomplete,
  Badge,
  ActionIcon,
  Tooltip,
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { notifications } from '@mantine/notifications'
import { IconArrowLeft, IconInfoCircle, IconPlus, IconX, IconLink } from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
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
  const [linkSearchValue, setLinkSearchValue] = useState('')
  const [linkKeterangan, setLinkKeterangan] = useState('')

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
      undang_undang_id: (value) => (!value ? 'Pilih undang-undang' : null),
      nomor: (value) => (!value ? 'Nomor pasal wajib diisi' : null),
      isi: (value) => (!value ? 'Isi pasal wajib diisi' : null),
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

  // Add pending link
  const handleAddPendingLink = () => {
    const selectedItem = allPasalList?.find(
      (p) => `${p.undang_undang.kode} - Pasal ${p.nomor}${p.judul ? ` (${p.judul})` : ''}` === linkSearchValue
    )
    if (selectedItem) {
      // Check if already added
      if (pendingLinks.some((l) => l.targetPasalId === selectedItem.id)) {
        notifications.show({
          title: 'Peringatan',
          message: 'Pasal ini sudah ditambahkan ke daftar link',
          color: 'yellow',
        })
        return
      }

      setPendingLinks([
        ...pendingLinks,
        {
          targetPasalId: selectedItem.id,
          targetPasalLabel: `${selectedItem.undang_undang.kode} - Pasal ${selectedItem.nomor}${selectedItem.judul ? ` (${selectedItem.judul})` : ''}`,
          keterangan: linkKeterangan,
        },
      ])
      setLinkSearchValue('')
      setLinkKeterangan('')
    }
  }

  // Remove pending link
  const handleRemovePendingLink = (targetPasalId: string) => {
    setPendingLinks(pendingLinks.filter((l) => l.targetPasalId !== targetPasalId))
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

      {/* Pasal Terkait Section */}
      <Card shadow="sm" padding="lg" radius="md" withBorder>
        <Group mb="md">
          <IconLink size={20} />
          <Title order={4}>Pasal Terkait (Preview)</Title>
        </Group>

        <Alert icon={<IconInfoCircle size={16} />} color="blue" variant="light" mb="md">
          Link pasal terkait akan dibuat setelah pasal disimpan.
        </Alert>

        <Stack gap="md">
          {/* Pending links preview */}
          {pendingLinks.length > 0 ? (
            <Stack gap="xs">
              {pendingLinks.map((link) => (
                <Card key={link.targetPasalId} withBorder padding="xs" radius="sm">
                  <Group justify="space-between">
                    <Group gap="xs">
                      <Badge size="sm" color="blue" variant="light">
                        Preview
                      </Badge>
                      <Text size="sm" fw={500}>
                        {link.targetPasalLabel}
                      </Text>
                    </Group>
                    <Tooltip label="Hapus dari preview">
                      <ActionIcon
                        size="sm"
                        variant="subtle"
                        color="red"
                        onClick={() => handleRemovePendingLink(link.targetPasalId)}
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
              ))}
            </Stack>
          ) : (
            <Text size="sm" c="dimmed" ta="center" py="sm">
              Belum ada pasal terkait yang ditambahkan
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
                  ?.filter((p) => !pendingLinks.some((link) => link.targetPasalId === p.id))
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
              onClick={handleAddPendingLink}
              variant="light"
            >
              Tambah ke Preview
            </Button>
          </Stack>
        </Stack>
      </Card>
    </Stack>
  )
}
