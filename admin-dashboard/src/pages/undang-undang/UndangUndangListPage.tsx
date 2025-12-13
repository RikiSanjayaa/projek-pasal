import { useState } from 'react'
import {
  Title,
  Text,
  Stack,
  Card,
  Group,
  Button,
  TextInput,
  Textarea,
  NumberInput,
  Table,
  Badge,
  ActionIcon,
  Modal,
  Switch,
  Skeleton,
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { useDisclosure } from '@mantine/hooks'
import { notifications } from '@mantine/notifications'
import { IconPlus, IconEdit } from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { UndangUndang, UndangUndangInsert, UndangUndangUpdate } from '@/lib/database.types'

export function UndangUndangListPage() {
  const queryClient = useQueryClient()
  const [createModal, { open: openCreate, close: closeCreate }] = useDisclosure(false)
  const [editModal, { open: openEdit, close: closeEdit }] = useDisclosure(false)
  const [selectedUU, setSelectedUU] = useState<UndangUndang | null>(null)

  // Fetch undang-undang
  const { data: undangUndangList, isLoading } = useQuery({
    queryKey: ['undang_undang', 'all'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('undang_undang')
        .select('*')
        .order('kode')

      if (error) throw error
      return data as UndangUndang[]
    },
  })

  // Create form
  const createForm = useForm<UndangUndangInsert>({
    initialValues: {
      kode: '',
      nama: '',
      nama_lengkap: '',
      deskripsi: '',
      tahun: undefined,
    },
    validate: {
      kode: (value) => (!value ? 'Kode wajib diisi' : null),
      nama: (value) => (!value ? 'Nama wajib diisi' : null),
    },
  })

  // Edit form
  const editForm = useForm<UndangUndangUpdate>({
    initialValues: {
      kode: '',
      nama: '',
      nama_lengkap: '',
      deskripsi: '',
      tahun: undefined,
      is_active: true,
    },
  })

  // Create mutation
  const createMutation = useMutation({
    mutationFn: async (data: UndangUndangInsert) => {
      const { error } = await supabase.from('undang_undang').insert(data as never)
      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['undang_undang'] })
      notifications.show({
        title: 'Berhasil',
        message: 'Undang-undang berhasil ditambahkan',
        color: 'green',
      })
      closeCreate()
      createForm.reset()
    },
    onError: (error: Error) => {
      notifications.show({
        title: 'Gagal',
        message: error.message,
        color: 'red',
      })
    },
  })

  // Update mutation
  const updateMutation = useMutation({
    mutationFn: async ({ id, data }: { id: string; data: UndangUndangUpdate }) => {
      const { data: result, error } = await supabase
        .from('undang_undang')
        .update(data as never)
        .eq('id', id)
        .select()

      if (error) throw error

      // Check if update actually happened (RLS might silently block)
      if (!result || result.length === 0) {
        throw new Error('Gagal memperbarui. Pastikan Anda terdaftar sebagai admin di database.')
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['undang_undang'] })
      notifications.show({
        title: 'Berhasil',
        message: 'Undang-undang berhasil diperbarui',
        color: 'green',
      })
      closeEdit()
    },
    onError: (error: Error) => {
      notifications.show({
        title: 'Gagal',
        message: error.message,
        color: 'red',
      })
    },
  })

  const handleEdit = (uu: UndangUndang) => {
    setSelectedUU(uu)
    editForm.setValues({
      kode: uu.kode,
      nama: uu.nama,
      nama_lengkap: uu.nama_lengkap || '',
      deskripsi: uu.deskripsi || '',
      tahun: uu.tahun || undefined,
      is_active: uu.is_active,
    })
    openEdit()
  }

  return (
    <Stack gap="lg">
      <Group justify="space-between">
        <div>
          <Title order={2}>Undang-Undang</Title>
          <Text c="dimmed">Kelola daftar undang-undang</Text>
        </div>
        <Button leftSection={<IconPlus size={18} />} onClick={openCreate}>
          Tambah UU
        </Button>
      </Group>

      <Card shadow="sm" padding="md" radius="md" withBorder>
        {isLoading ? (
          <Stack gap="sm">
            {[...Array(4)].map((_, i) => (
              <Skeleton key={i} height={50} />
            ))}
          </Stack>
        ) : (
          <Table striped highlightOnHover>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Kode</Table.Th>
                <Table.Th>Nama</Table.Th>
                <Table.Th>Tahun</Table.Th>
                <Table.Th>Status</Table.Th>
                <Table.Th w={100}>Aksi</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {undangUndangList?.map((uu) => (
                <Table.Tr key={uu.id}>
                  <Table.Td>
                    <Badge color="blue" variant="filled">
                      {uu.kode}
                    </Badge>
                  </Table.Td>
                  <Table.Td>
                    <Text fw={500}>{uu.nama}</Text>
                    <Text size="xs" c="dimmed" lineClamp={1}>
                      {uu.nama_lengkap}
                    </Text>
                  </Table.Td>
                  <Table.Td>{uu.tahun || '-'}</Table.Td>
                  <Table.Td>
                    <Badge color={uu.is_active ? 'green' : 'red'} variant="light">
                      {uu.is_active ? 'Aktif' : 'Nonaktif'}
                    </Badge>
                  </Table.Td>
                  <Table.Td>
                    <Group gap="xs">
                      <ActionIcon
                        variant="subtle"
                        color="blue"
                        onClick={() => handleEdit(uu)}
                      >
                        <IconEdit size={16} />
                      </ActionIcon>
                    </Group>
                  </Table.Td>
                </Table.Tr>
              ))}
            </Table.Tbody>
          </Table>
        )}
      </Card>

      {/* Create Modal */}
      <Modal
        opened={createModal}
        onClose={closeCreate}
        title="Tambah Undang-Undang Baru"
        size="lg"
      >
        <form onSubmit={createForm.onSubmit((values) => createMutation.mutate(values))}>
          <Stack gap="md">
            <TextInput
              label="Kode"
              placeholder="Contoh: KUHP, UU_ITE"
              required
              {...createForm.getInputProps('kode')}
            />
            <TextInput
              label="Nama Singkat"
              placeholder="Contoh: KUHP"
              required
              {...createForm.getInputProps('nama')}
            />
            <TextInput
              label="Nama Lengkap"
              placeholder="Contoh: Kitab Undang-Undang Hukum Pidana"
              {...createForm.getInputProps('nama_lengkap')}
            />
            <Textarea
              label="Deskripsi"
              placeholder="Deskripsi singkat..."
              minRows={3}
              {...createForm.getInputProps('deskripsi')}
            />
            <NumberInput
              label="Tahun"
              placeholder="Contoh: 1946"
              {...createForm.getInputProps('tahun')}
            />
            <Group justify="flex-end" mt="md">
              <Button variant="default" onClick={closeCreate}>
                Batal
              </Button>
              <Button type="submit" loading={createMutation.isPending}>
                Simpan
              </Button>
            </Group>
          </Stack>
        </form>
      </Modal>

      {/* Edit Modal */}
      <Modal
        opened={editModal}
        onClose={closeEdit}
        title={`Edit ${selectedUU?.kode}`}
        size="lg"
      >
        <form
          onSubmit={editForm.onSubmit((values) =>
            updateMutation.mutate({ id: selectedUU!.id, data: values })
          )}
        >
          <Stack gap="md">
            <TextInput
              label="Kode"
              placeholder="Contoh: KUHP, UU_ITE"
              required
              {...editForm.getInputProps('kode')}
            />
            <TextInput
              label="Nama Singkat"
              placeholder="Contoh: KUHP"
              required
              {...editForm.getInputProps('nama')}
            />
            <TextInput
              label="Nama Lengkap"
              placeholder="Contoh: Kitab Undang-Undang Hukum Pidana"
              {...editForm.getInputProps('nama_lengkap')}
            />
            <Textarea
              label="Deskripsi"
              placeholder="Deskripsi singkat..."
              minRows={3}
              {...editForm.getInputProps('deskripsi')}
            />
            <NumberInput
              label="Tahun"
              placeholder="Contoh: 1946"
              {...editForm.getInputProps('tahun')}
            />
            <Switch
              label="Aktif"
              description="Undang-undang yang tidak aktif tidak akan tampil di aplikasi"
              {...editForm.getInputProps('is_active', { type: 'checkbox' })}
            />
            <Group justify="flex-end" mt="md">
              <Button variant="default" onClick={closeEdit}>
                Batal
              </Button>
              <Button type="submit" loading={updateMutation.isPending}>
                Simpan
              </Button>
            </Group>
          </Stack>
        </form>
      </Modal>
    </Stack>
  )
}
