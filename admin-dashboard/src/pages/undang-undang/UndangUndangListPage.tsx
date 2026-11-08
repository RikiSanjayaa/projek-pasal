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
  NumberInput,
  Table,
  Badge,
  Modal,
  Switch,
  Skeleton,
  ScrollArea,
  Alert,
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { useDisclosure, useMediaQuery } from '@mantine/hooks'
import { notifications } from '@mantine/notifications'
import { IconPlus, IconEdit, IconAlertCircle, IconList } from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { IconAction } from '@/components/IconAction'
import { api } from '@/lib/api'
import type { UndangUndang, UndangUndangInsert, UndangUndangUpdate } from '@/lib/database.types'
import { invalidateUndangUndangData } from '@/lib/query-invalidation'

interface PaginatedResponse<T> {
  data: T[]
}

export function UndangUndangListPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const isMobile = useMediaQuery('(max-width: 48em)')
  const [createModal, { open: openCreate, close: closeCreate }] = useDisclosure(false)
  const [editModal, { open: openEdit, close: closeEdit }] = useDisclosure(false)
  const [selectedUU, setSelectedUU] = useState<(UndangUndang & { pasal?: { id: string; nomor: string }[] }) | null>(null)

  const baseColumnWidth = 150
  const selectableWidth = 40
  const actionsWidth = 80
  const minTableWidth = Math.max(700, 5 * baseColumnWidth + selectableWidth + actionsWidth)

  // Fetch undang-undang
  const { data: undangUndangList, isLoading } = useQuery({
    queryKey: ['undang_undang', 'all'],
    queryFn: async () => {
      const response = await api.get<PaginatedResponse<UndangUndang & { pasal: { id: string; nomor: string }[] }>>(
        '/admin/undang-undang?with_pasal=1&per_page=200'
      )
      // Manually sorting pasal by nomor numeric if possible, or string
      const sortedData = response.data?.map((uu: any) => ({
        ...uu,
        pasal: uu.pasal?.sort((a: any, b: any) => {
          // Try to sort numerically if it looks like a number
          const numA = parseInt(a.nomor)
          const numB = parseInt(b.nomor)
          if (!isNaN(numA) && !isNaN(numB)) return numA - numB
          return a.nomor.localeCompare(b.nomor, undefined, { numeric: true })
        })
      }))

      return sortedData as (UndangUndang & { pasal: { id: string; nomor: string }[] })[]
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
      official_url: '',
      source_url: '',
      catatan_teks: '',
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
      official_url: '',
      source_url: '',
      catatan_teks: '',
      is_active: true,
    },
  })

  // Create mutation
  const createMutation = useMutation({
    mutationFn: async (data: UndangUndangInsert) => {
      await api.post('/admin/undang-undang', data)
    },
    onSuccess: async () => {
      await invalidateUndangUndangData(queryClient)
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
      await api.put(`/admin/undang-undang/${id}`, data)
    },
    onSuccess: async () => {
      await invalidateUndangUndangData(queryClient)
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
      official_url: uu.official_url || '',
      source_url: uu.source_url || '',
      catatan_teks: uu.catatan_teks || '',
      is_active: uu.is_active,
    })
    openEdit()
  }

  return (
    <Stack gap="lg">
      <Group justify="space-between" wrap="wrap">
        <div>
          <Title order={2}>Undang-Undang</Title>
          <Text c="dimmed">Kelola daftar undang-undang</Text>
        </div>
        <Button leftSection={<IconPlus size={18} />} onClick={openCreate} fullWidth={isMobile}>
          Tambah UU
        </Button>
      </Group>

      <Card padding="md" radius="md" withBorder>
        {isLoading ? (
          <Stack gap="sm">
            {[...Array(4)].map((_, i) => (
              <Skeleton key={i} height={50} />
            ))}
          </Stack>
        ) : isMobile ? (
          <Stack gap="sm">
            {undangUndangList?.map((uu) => (
              <Card
                key={uu.id}
                withBorder
                padding="sm"
                radius="md"
                style={{ cursor: 'pointer' }}
                onClick={() => navigate(`/pasal?uu=${uu.id}`)}
              >
                <Stack gap="xs">
                  <Group justify="space-between" align="flex-start" wrap="nowrap">
                    <div style={{ minWidth: 0 }}>
                      <Badge color="blue" variant="filled" mb="xs">
                        {uu.kode}
                      </Badge>
                      <Text fw={600} style={{ overflowWrap: 'anywhere' }}>
                        {uu.nama}
                      </Text>
                      {uu.nama_lengkap && (
                        <Text size="xs" c="dimmed" lineClamp={2}>
                          {uu.nama_lengkap}
                        </Text>
                      )}
                    </div>
                    <IconAction
                      label="Edit undang-undang"
                      icon={<IconEdit size={18} />}
                      color="blue"
                      onClick={(event) => {
                        event.stopPropagation()
                        handleEdit(uu)
                      }}
                    />
                  </Group>

                  <Text size="sm" c="dimmed" lineClamp={3}>
                    {uu.deskripsi || '-'}
                  </Text>
                  <Group gap="xs">
                    <Badge variant="light" color="gray">
                      {uu.pasal?.length || 0} Pasal
                    </Badge>
                    <Badge variant="light" color="gray">
                      {uu.tahun || '-'}
                    </Badge>
                    <Badge color={uu.is_active ? 'green' : 'red'} variant="light">
                      {uu.is_active ? 'Aktif' : 'Nonaktif'}
                    </Badge>
                  </Group>
                </Stack>
              </Card>
            ))}
          </Stack>
        ) : (
          <ScrollArea style={{ width: '100%' }} type="always" scrollbarSize={6} offsetScrollbars>
            <div style={{ minWidth: minTableWidth }}>
              <Table striped highlightOnHover>
                <Table.Thead>
                  <Table.Tr>
                    <Table.Th>Kode</Table.Th>
                    <Table.Th>Nama</Table.Th>
                    <Table.Th>Deskripsi</Table.Th>
                    <Table.Th>Total Pasal</Table.Th>
                    <Table.Th>Tahun</Table.Th>
                    <Table.Th>Status</Table.Th>
                    <Table.Th w={1}>Aksi</Table.Th>
                  </Table.Tr>
                </Table.Thead>
                <Table.Tbody>
                  {undangUndangList?.map((uu) => (
                    <Table.Tr
                      key={uu.id}
                      style={{
                        cursor: 'pointer',
                      }}
                      onClick={() => navigate(`/pasal?uu=${uu.id}`)}
                    >
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
                      <Table.Td style={{ width: 200 }}><Text lineClamp={2} size="sm">{uu.deskripsi || '-'}</Text></Table.Td>
                      <Table.Td>
                        <Badge variant="light" color="gray">
                          {uu.pasal?.length || 0} Pasal
                        </Badge>
                      </Table.Td>
                      <Table.Td>{uu.tahun || '-'}</Table.Td>
                      <Table.Td>
                        <Badge color={uu.is_active ? 'green' : 'red'} variant="light">
                          {uu.is_active ? 'Aktif' : 'Nonaktif'}
                        </Badge>
                      </Table.Td>
                      <Table.Td>
                        <Group gap={2} wrap="nowrap">
                          <IconAction
                            label="Lihat pasal"
                            icon={<IconList size={18} />}
                            onClick={(e) => {
                              e.stopPropagation()
                              navigate(`/pasal?uu=${uu.id}`)
                            }}
                          />
                          <IconAction
                            label="Edit undang-undang"
                            icon={<IconEdit size={18} />}
                            color="blue"
                            onClick={(e) => {
                              e.stopPropagation()
                              handleEdit(uu)
                            }}
                          />
                        </Group>
                      </Table.Td>
                    </Table.Tr>
                  ))}
                </Table.Tbody>
              </Table>
            </div>
          </ScrollArea>
        )}
      </Card>

      {/* Create Modal */}
      <Modal
        opened={createModal}
        onClose={closeCreate}
        title="Tambah Undang-Undang Baru"
        size="lg"
        fullScreen={isMobile}
      >
        <form onSubmit={createForm.onSubmit((values) => createMutation.mutate({ ...values, catatan_teks: values.catatan_teks?.trim() || null }))}>
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
            <TextInput
              label="Link naskah resmi"
              description="Dipakai admin saat verifikasi dan ditampilkan di mobile, contoh halaman JDIH BPK"
              placeholder="https://peraturan.bpk.go.id/Details/..."
              {...createForm.getInputProps('official_url')}
            />
            <TextInput
              label="Sumber teks"
              description="Asal teks yang diimport (tidak resmi), contoh datahukum.com"
              placeholder="https://www.datahukum.com/peraturan/..."
              {...createForm.getInputProps('source_url')}
            />
            <Textarea
              label="Catatan status teks"
              description="Tampil di setiap pasal UU ini. Contoh: terjemahan tidak resmi."
              placeholder="Opsional"
              minRows={3}
              autosize
              {...createForm.getInputProps('catatan_teks')}
            />
            <Group justify="flex-end" mt="md" grow={isMobile}>
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
        fullScreen={isMobile}
      >
        <form
          onSubmit={editForm.onSubmit((values) =>
            updateMutation.mutate({ id: selectedUU!.id, data: { ...values, catatan_teks: values.catatan_teks?.trim() || null } })
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
            <TextInput
              label="Link naskah resmi"
              description="Dipakai admin saat verifikasi dan ditampilkan di mobile, contoh halaman JDIH BPK"
              placeholder="https://peraturan.bpk.go.id/Details/..."
              {...editForm.getInputProps('official_url')}
            />
            <TextInput
              label="Sumber teks"
              description="Asal teks yang diimport (tidak resmi), contoh datahukum.com"
              placeholder="https://www.datahukum.com/peraturan/..."
              {...editForm.getInputProps('source_url')}
            />
            <Textarea
              label="Catatan status teks"
              description="Tampil di setiap pasal UU ini. Contoh: terjemahan tidak resmi."
              placeholder="Opsional"
              minRows={3}
              autosize
              {...editForm.getInputProps('catatan_teks')}
            />
            <Switch
              label="Aktif"
              description="Mengubah status ini akan mempengaruhi semua pasal terkait"
              {...editForm.getInputProps('is_active', { type: 'checkbox' })}
            />
            {selectedUU && editForm.values.is_active !== selectedUU.is_active && (
              <Alert
                icon={<IconAlertCircle size={16} />}
                color={editForm.values.is_active ? 'green' : 'orange'}
                variant="light"
              >
                {editForm.values.is_active ? (
                  <>
                    <Text size="sm" fw={500}>Mengaktifkan {selectedUU.kode}</Text>
                    <Text size="xs">
                      Semua {selectedUU.pasal?.length || 0} pasal terkait akan ikut diaktifkan
                      dan akan tampil di aplikasi mobile.
                    </Text>
                  </>
                ) : (
                  <>
                    <Text size="sm" fw={500}>Menonaktifkan {selectedUU.kode}</Text>
                    <Text size="xs">
                      Semua {selectedUU.pasal?.length || 0} pasal terkait akan ikut dinonaktifkan
                      dan akan dihapus dari aplikasi mobile saat sync berikutnya.
                    </Text>
                  </>
                )}
              </Alert>
            )}
            <Group justify="flex-end" mt="md" grow={isMobile}>
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
