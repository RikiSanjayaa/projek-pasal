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
  Badge,
  ActionIcon,
  Modal,
  Tooltip,
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
import { DataTable, type Column } from '@/components/DataTable'
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

// Helper functions for date formatting
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

  // Define table columns inside component
  const pasalTrashColumns: Column<DeletedPasal>[] = [
    {
      key: 'undang_undang',
      title: 'Undang-Undang',
      width: 120,
      render: (_, record) => (
        <Badge color="blue" variant="light">
          {record.undang_undang.kode}
        </Badge>
      ),
    },
    {
      key: 'nomor',
      title: 'Nomor',
      width: 100,
      render: (value) => (
        <Text fw={500}>Pasal {value}</Text>
      ),
    },
    {
      key: 'judul',
      title: 'Judul',
      render: (value) => (
        <Text size="sm" lineClamp={1}>
          {value || '-'}
        </Text>
      ),
    },
    {
      key: 'isi',
      title: 'Isi',
      render: (value) => (
        <Text size="sm" c="dimmed" lineClamp={2} style={{ maxWidth: 300 }}>
          {value}
        </Text>
      ),
    },
    {
      key: 'keywords',
      title: 'Keywords',
      render: (value) => (
        <Group gap={4}>
          {value?.slice(0, 2).map((kw: string, idx: number) => (
            <Badge key={idx} size="xs" variant="outline">
              {kw}
            </Badge>
          ))}
          {(value?.length || 0) > 2 && (
            <Badge size="xs" variant="outline" color="gray">
              +{(value?.length || 0) - 2}
            </Badge>
          )}
        </Group>
      ),
    },
    {
      key: 'deleted_at',
      title: 'Dihapus',
      width: 150,
      render: (value) => {
        const daysAgo = getDaysAgo(value)
        const daysLeft = 30 - daysAgo

        return (
          <Stack gap={2}>
            <Text size="xs">{formatDate(value)}</Text>
            <Badge
              size="xs"
              color={daysLeft <= 7 ? 'red' : daysLeft <= 14 ? 'yellow' : 'gray'}
              variant="light"
            >
              {daysLeft > 0 ? `${daysLeft} hari lagi` : 'Segera dihapus'}
            </Badge>
          </Stack>
        )
      },
    },
  ]

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
        <DataTable
          columns={pasalTrashColumns}
          data={pasalData?.data || []}
          loading={isLoading}
          current={page}
          pageSize={PAGE_SIZE}
          total={pasalData?.count || 0}
          onPageChange={setPage}
          onPageSizeChange={() => { }} // Not used in trash page
          selectable
          selectedIds={selectedIds}
          onSelect={setSelectedIds}
          getRowId={(record) => record.id}
          onRowClick={(pasal) => navigate(`/pasal/${pasal.id}`)}
          rowActions={(pasal) => (
            <Group gap={4}>
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
          )}
          emptyText="Tidak ada pasal di sampah"
        />
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
