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
  Select,
  Table,
  Badge,
  ActionIcon,
  Pagination,
  Skeleton,
  Modal,
  Tooltip,
  Checkbox,
  Alert,
} from '@mantine/core'
import { useDebouncedValue, useDisclosure } from '@mantine/hooks'
import { notifications } from '@mantine/notifications'
import {
  IconArrowLeft,
  IconSearch,
  IconRestore,
  IconTrash,
  IconAlertTriangle,
} from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

// Type for deleted pasal
interface DeletedPasal {
  id: string
  nomor: string
  judul: string | null
  isi: string
  deleted_at: string
  undang_undang: {
    id: string
    kode: string
    nama: string
  }
}

const PAGE_SIZE = 10

export function PasalTrashPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [debouncedSearch] = useDebouncedValue(search, 300)
  const [filterUU, setFilterUU] = useState<string | null>(null)
  const [selectedIds, setSelectedIds] = useState<string[]>([])

  // Modal states
  const [restoreModal, { open: openRestore, close: closeRestore }] = useDisclosure(false)
  const [deleteModal, { open: openDelete, close: closeDelete }] = useDisclosure(false)
  const [bulkRestoreModal, { open: openBulkRestore, close: closeBulkRestore }] = useDisclosure(false)
  const [bulkDeleteModal, { open: openBulkDelete, close: closeBulkDelete }] = useDisclosure(false)
  const [selectedPasal, setSelectedPasal] = useState<DeletedPasal | null>(null)

  // Fetch undang-undang for filter
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

  // Fetch deleted pasal
  const { data: pasalData, isLoading } = useQuery({
    queryKey: ['pasal', 'trash', page, debouncedSearch, filterUU],
    queryFn: async () => {
      let query = supabase
        .from('pasal')
        .select('id, nomor, judul, isi, deleted_at, undang_undang(id, kode, nama)', { count: 'exact' })
        .eq('is_active', false)
        .not('deleted_at', 'is', null)
        .order('deleted_at', { ascending: false })
        .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1)

      if (debouncedSearch) {
        query = query.or(`nomor.ilike.%${debouncedSearch}%,judul.ilike.%${debouncedSearch}%,isi.ilike.%${debouncedSearch}%`)
      }

      if (filterUU) {
        query = query.eq('undang_undang_id', filterUU)
      }

      const { data, error, count } = await query

      if (error) throw error
      return { data: data as unknown as DeletedPasal[], count: count || 0 }
    },
  })

  const totalPages = Math.ceil((pasalData?.count || 0) / PAGE_SIZE)

  // Restore mutation
  const restoreMutation = useMutation({
    mutationFn: async (id: string) => {
      const { data, error } = await supabase
        .from('pasal')
        .update({
          is_active: true,
          deleted_at: null,
        } as never)
        .eq('id', id)
        .select()

      if (error) throw error
      if (!data || data.length === 0) {
        throw new Error('Gagal restore. Pastikan Anda terdaftar sebagai admin.')
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal'] })
      notifications.show({
        title: 'Berhasil',
        message: 'Pasal berhasil di-restore',
        color: 'green',
      })
      closeRestore()
    },
    onError: (error) => {
      notifications.show({
        title: 'Gagal',
        message: `Error: ${error.message}`,
        color: 'red',
      })
    },
  })

  // Permanent delete mutation
  const permanentDeleteMutation = useMutation({
    mutationFn: async (id: string) => {
      // First delete related links
      await supabase
        .from('pasal_links')
        .delete()
        .or(`source_pasal_id.eq.${id},target_pasal_id.eq.${id}`)

      // Then delete the pasal
      const { error } = await supabase
        .from('pasal')
        .delete()
        .eq('id', id)

      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal'] })
      notifications.show({
        title: 'Berhasil',
        message: 'Pasal berhasil dihapus permanen',
        color: 'green',
      })
      closeDelete()
    },
    onError: (error) => {
      notifications.show({
        title: 'Gagal',
        message: `Error: ${error.message}`,
        color: 'red',
      })
    },
  })

  // Bulk restore mutation
  const bulkRestoreMutation = useMutation({
    mutationFn: async (ids: string[]) => {
      const { data, error } = await supabase
        .from('pasal')
        .update({
          is_active: true,
          deleted_at: null,
        } as never)
        .in('id', ids)
        .select()

      if (error) throw error
      if (!data || data.length === 0) {
        throw new Error('Gagal restore. Pastikan Anda terdaftar sebagai admin.')
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal'] })
      notifications.show({
        title: 'Berhasil',
        message: `${selectedIds.length} pasal berhasil di-restore`,
        color: 'green',
      })
      setSelectedIds([])
      closeBulkRestore()
    },
    onError: (error) => {
      notifications.show({
        title: 'Gagal',
        message: `Error: ${error.message}`,
        color: 'red',
      })
    },
  })

  // Bulk permanent delete mutation
  const bulkPermanentDeleteMutation = useMutation({
    mutationFn: async (ids: string[]) => {
      // Delete related links for all pasal
      for (const id of ids) {
        await supabase
          .from('pasal_links')
          .delete()
          .or(`source_pasal_id.eq.${id},target_pasal_id.eq.${id}`)
      }

      // Delete all pasal
      const { error } = await supabase
        .from('pasal')
        .delete()
        .in('id', ids)

      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal'] })
      notifications.show({
        title: 'Berhasil',
        message: `${selectedIds.length} pasal berhasil dihapus permanen`,
        color: 'green',
      })
      setSelectedIds([])
      closeBulkDelete()
    },
    onError: (error) => {
      notifications.show({
        title: 'Gagal',
        message: `Error: ${error.message}`,
        color: 'red',
      })
    },
  })

  const handleSelectAll = (checked: boolean) => {
    if (checked) {
      setSelectedIds(pasalData?.data?.map((p) => p.id) || [])
    } else {
      setSelectedIds([])
    }
  }

  const handleSelectOne = (id: string, checked: boolean) => {
    if (checked) {
      setSelectedIds([...selectedIds, id])
    } else {
      setSelectedIds(selectedIds.filter((i) => i !== id))
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('id-ID', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  const getDaysAgo = (dateString: string) => {
    const deleted = new Date(dateString)
    const now = new Date()
    const diffTime = Math.abs(now.getTime() - deleted.getTime())
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24))
    return diffDays
  }

  return (
    <Stack gap="lg">
      <Group>
        <Button
          variant="subtle"
          leftSection={<IconArrowLeft size={18} />}
          onClick={() => navigate('/pasal')}
        >
          Kembali ke Daftar Pasal
        </Button>
      </Group>

      <Group justify="space-between" align="flex-start">
        <div>
          <Title order={2}>Sampah</Title>
          <Text c="dimmed">Pasal yang sudah dihapus. Restore atau hapus permanen.</Text>
        </div>
      </Group>

      <Alert icon={<IconAlertTriangle size={16} />} color="yellow" variant="light">
        Pasal di sampah akan dihapus permanen secara otomatis setelah 30 hari.
        Anda dapat me-restore pasal atau menghapus permanen secara manual.
      </Alert>

      {/* Filters */}
      <Card shadow="sm" padding="md" radius="md" withBorder>
        <Group>
          <TextInput
            placeholder="Cari nomor, judul, atau isi pasal..."
            leftSection={<IconSearch size={16} />}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ flex: 1 }}
          />
          <Select
            placeholder="Filter Undang-Undang"
            data={
              undangUndangList?.map((uu) => ({
                value: uu.id,
                label: `${uu.kode} - ${uu.nama}`,
              })) || []
            }
            value={filterUU}
            onChange={setFilterUU}
            clearable
            w={250}
          />
        </Group>
      </Card>

      {/* Bulk Actions */}
      {selectedIds.length > 0 && (
        <Card shadow="sm" padding="sm" radius="md" withBorder bg="var(--mantine-color-blue-light)">
          <Group justify="space-between">
            <Text size="sm" fw={500}>
              {selectedIds.length} pasal dipilih
            </Text>
            <Group gap="xs">
              <Button
                size="xs"
                color="green"
                leftSection={<IconRestore size={14} />}
                onClick={openBulkRestore}
              >
                Restore Semua
              </Button>
              <Button
                size="xs"
                color="red"
                leftSection={<IconTrash size={14} />}
                onClick={openBulkDelete}
              >
                Hapus Permanen
              </Button>
            </Group>
          </Group>
        </Card>
      )}

      {/* Table */}
      <Card shadow="sm" padding="md" radius="md" withBorder>
        {isLoading ? (
          <Stack gap="sm">
            {[...Array(5)].map((_, i) => (
              <Skeleton key={i} height={50} />
            ))}
          </Stack>
        ) : (
          <>
            <Table striped highlightOnHover>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th w={40}>
                    <Checkbox
                      checked={selectedIds.length === pasalData?.data?.length && pasalData?.data?.length > 0}
                      indeterminate={selectedIds.length > 0 && selectedIds.length < (pasalData?.data?.length || 0)}
                      onChange={(e) => handleSelectAll(e.currentTarget.checked)}
                    />
                  </Table.Th>
                  <Table.Th>Undang-Undang</Table.Th>
                  <Table.Th>Nomor</Table.Th>
                  <Table.Th>Judul</Table.Th>
                  <Table.Th>Dihapus</Table.Th>
                  <Table.Th w={120}>Aksi</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                {pasalData?.data?.map((pasal) => {
                  const daysAgo = getDaysAgo(pasal.deleted_at)
                  const daysLeft = 30 - daysAgo

                  return (
                    <Table.Tr key={pasal.id}>
                      <Table.Td>
                        <Checkbox
                          checked={selectedIds.includes(pasal.id)}
                          onChange={(e) => handleSelectOne(pasal.id, e.currentTarget.checked)}
                        />
                      </Table.Td>
                      <Table.Td>
                        <Badge variant="light">{pasal.undang_undang.kode}</Badge>
                      </Table.Td>
                      <Table.Td>
                        <Text fw={500}>Pasal {pasal.nomor}</Text>
                      </Table.Td>
                      <Table.Td>
                        <Text size="sm" lineClamp={1}>
                          {pasal.judul || '-'}
                        </Text>
                      </Table.Td>
                      <Table.Td>
                        <Stack gap={2}>
                          <Text size="xs">{formatDate(pasal.deleted_at)}</Text>
                          <Badge
                            size="xs"
                            color={daysLeft <= 7 ? 'red' : daysLeft <= 14 ? 'yellow' : 'gray'}
                            variant="light"
                          >
                            {daysLeft > 0 ? `${daysLeft} hari lagi` : 'Segera dihapus'}
                          </Badge>
                        </Stack>
                      </Table.Td>
                      <Table.Td>
                        <Group gap="xs">
                          <Tooltip label="Restore">
                            <ActionIcon
                              variant="subtle"
                              color="green"
                              onClick={() => {
                                setSelectedPasal(pasal)
                                openRestore()
                              }}
                            >
                              <IconRestore size={16} />
                            </ActionIcon>
                          </Tooltip>
                          <Tooltip label="Hapus Permanen">
                            <ActionIcon
                              variant="subtle"
                              color="red"
                              onClick={() => {
                                setSelectedPasal(pasal)
                                openDelete()
                              }}
                            >
                              <IconTrash size={16} />
                            </ActionIcon>
                          </Tooltip>
                        </Group>
                      </Table.Td>
                    </Table.Tr>
                  )
                })}
              </Table.Tbody>
            </Table>

            {pasalData?.data?.length === 0 && (
              <Text c="dimmed" ta="center" py="xl">
                Tidak ada pasal di sampah
              </Text>
            )}

            {totalPages > 1 && (
              <Group justify="center" mt="md">
                <Pagination value={page} onChange={setPage} total={totalPages} />
              </Group>
            )}
          </>
        )}
      </Card>

      {/* Restore Modal */}
      <Modal opened={restoreModal} onClose={closeRestore} title="Restore Pasal">
        <Stack gap="md">
          <Text>
            Apakah Anda yakin ingin me-restore pasal ini?
          </Text>
          <Card withBorder padding="sm">
            <Text fw={500}>
              {selectedPasal?.undang_undang.kode} - Pasal {selectedPasal?.nomor}
            </Text>
            {selectedPasal?.judul && (
              <Text size="sm" c="dimmed">{selectedPasal.judul}</Text>
            )}
          </Card>
          <Text size="sm" c="dimmed">
            Link pasal terkait juga akan di-restore (jika pasal target masih aktif).
          </Text>
          <Group justify="flex-end">
            <Button variant="default" onClick={closeRestore}>
              Batal
            </Button>
            <Button
              color="green"
              loading={restoreMutation.isPending}
              onClick={() => selectedPasal && restoreMutation.mutate(selectedPasal.id)}
            >
              Restore
            </Button>
          </Group>
        </Stack>
      </Modal>

      {/* Permanent Delete Modal */}
      <Modal opened={deleteModal} onClose={closeDelete} title="Hapus Permanen">
        <Stack gap="md">
          <Alert icon={<IconAlertTriangle size={16} />} color="red" variant="light">
            <Text fw={500}>Peringatan!</Text>
            <Text size="sm">
              Tindakan ini tidak dapat dibatalkan. Pasal dan semua link terkait akan dihapus secara permanen.
            </Text>
          </Alert>
          <Card withBorder padding="sm">
            <Text fw={500}>
              {selectedPasal?.undang_undang.kode} - Pasal {selectedPasal?.nomor}
            </Text>
            {selectedPasal?.judul && (
              <Text size="sm" c="dimmed">{selectedPasal.judul}</Text>
            )}
          </Card>
          <Group justify="flex-end">
            <Button variant="default" onClick={closeDelete}>
              Batal
            </Button>
            <Button
              color="red"
              loading={permanentDeleteMutation.isPending}
              onClick={() => selectedPasal && permanentDeleteMutation.mutate(selectedPasal.id)}
            >
              Hapus Permanen
            </Button>
          </Group>
        </Stack>
      </Modal>

      {/* Bulk Restore Modal */}
      <Modal opened={bulkRestoreModal} onClose={closeBulkRestore} title="Restore Pasal">
        <Stack gap="md">
          <Text>
            Apakah Anda yakin ingin me-restore <strong>{selectedIds.length} pasal</strong>?
          </Text>
          <Text size="sm" c="dimmed">
            Link pasal terkait juga akan di-restore (jika pasal target masih aktif).
          </Text>
          <Group justify="flex-end">
            <Button variant="default" onClick={closeBulkRestore}>
              Batal
            </Button>
            <Button
              color="green"
              loading={bulkRestoreMutation.isPending}
              onClick={() => bulkRestoreMutation.mutate(selectedIds)}
            >
              Restore {selectedIds.length} Pasal
            </Button>
          </Group>
        </Stack>
      </Modal>

      {/* Bulk Permanent Delete Modal */}
      <Modal opened={bulkDeleteModal} onClose={closeBulkDelete} title="Hapus Permanen">
        <Stack gap="md">
          <Alert icon={<IconAlertTriangle size={16} />} color="red" variant="light">
            <Text fw={500}>Peringatan!</Text>
            <Text size="sm">
              Tindakan ini tidak dapat dibatalkan. {selectedIds.length} pasal dan semua link terkait akan dihapus secara permanen.
            </Text>
          </Alert>
          <Group justify="flex-end">
            <Button variant="default" onClick={closeBulkDelete}>
              Batal
            </Button>
            <Button
              color="red"
              loading={bulkPermanentDeleteMutation.isPending}
              onClick={() => bulkPermanentDeleteMutation.mutate(selectedIds)}
            >
              Hapus Permanen {selectedIds.length} Pasal
            </Button>
          </Group>
        </Stack>
      </Modal>
    </Stack>
  )
}
