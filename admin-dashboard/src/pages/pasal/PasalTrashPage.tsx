import { useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
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
  Modal,
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
import { IconAction } from '@/components/IconAction'
import { api, toQueryString, type PaginatedResponse } from '@/lib/api'
import { formatPasalLabel } from '@/lib/pasal-format'
import { invalidatePasalData } from '@/lib/query-invalidation'

// Type for deleted pasal
interface DeletedPasal {
  id: string
  nomor: string
  judul: string | null
  isi: string
  bab: string | null
  deleted_at: string
  // null bila undang-undangnya juga sudah dihapus
  undang_undang: {
    id: string
    kode: string
    nama: string
  } | null
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
  const [searchParams] = useSearchParams()

  const [page, setPage] = useState(1)
  const [search, setSearch] = useState(searchParams.get('search') || '')
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
      render: (_, record) =>
        record.undang_undang ? (
          <Badge color="blue" variant="light">
            {record.undang_undang.kode}
          </Badge>
        ) : (
          <Badge color="gray" variant="light">
            UU dihapus
          </Badge>
        ),
    },
    {
      key: 'nomor',
      title: 'Nomor',
      width: 100,
      render: (value) => (
        <Text fw={500}>{formatPasalLabel(value as string)}</Text>
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
      const response = await api.get<PaginatedResponse<{ id: string; kode: string; nama: string }>>(
        '/admin/undang-undang?is_active=1&per_page=200'
      )
      return response.data
    },
  })

  // Fetch deleted pasal
  const { data: pasalData, isLoading } = useQuery({
    queryKey: ['pasal', 'trash', page, debouncedSearch, filterUU],
    queryFn: async () => {
      const response = await api.get<PaginatedResponse<DeletedPasal>>(
        `/admin/pasal${toQueryString({
          trash: 1,
          page,
          per_page: PAGE_SIZE,
          search: debouncedSearch,
          undang_undang_id: filterUU,
        })}`
      )
      return { data: response.data, count: response.total }
    },
  })

  // Restore mutation
  const restoreMutation = useMutation({
    mutationFn: async (id: string) => {
      await api.patch(`/admin/pasal/${id}/restore`)
    },
    onSuccess: async () => {
      await invalidatePasalData(queryClient)
      notifications.show({
        title: 'Berhasil',
        message: 'Pasal berhasil dipulihkan',
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
      await api.delete(`/admin/pasal/${id}/force`)
    },
    onSuccess: async () => {
      await invalidatePasalData(queryClient)
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
      await api.post('/admin/pasal/bulk-restore', { ids })
    },
    onSuccess: async () => {
      await invalidatePasalData(queryClient)
      notifications.show({
        title: 'Berhasil',
        message: `${selectedIds.length} pasal berhasil dipulihkan`,
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
      await api.post('/admin/pasal/bulk-force-delete', { ids })
    },
    onSuccess: async () => {
      await invalidatePasalData(queryClient)
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
          <Text c="dimmed">Pasal yang sudah dihapus. Pulihkan atau hapus permanen.</Text>
        </div>
      </Group>

      <Alert icon={<IconAlertTriangle size={16} />} color="yellow" variant="light">
        Pasal di sampah akan dihapus permanen secara otomatis setelah 30 hari.
        Anda dapat memulihkan pasal atau menghapusnya permanen secara manual.
      </Alert>

      <Card padding="md">
        <Stack gap="md">
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

          {selectedIds.length > 0 && (
            <Group justify="space-between" p="xs" bg="var(--mantine-color-blue-light)" style={{ borderRadius: 'var(--mantine-radius-md)' }}>
              <Text size="sm" fw={500}>
                {selectedIds.length} pasal dipilih
              </Text>
              <Group gap="xs">
                <Button size="xs" color="green" leftSection={<IconRestore size={14} />} onClick={openBulkRestore}>
                  Pulihkan semua
                </Button>
                <Button size="xs" color="red" leftSection={<IconTrash size={14} />} onClick={openBulkDelete}>
                  Hapus permanen
                </Button>
              </Group>
            </Group>
          )}

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
              <Group gap={2} wrap="nowrap">
                <IconAction
                  label="Pulihkan"
                  icon={<IconRestore size={18} />}
                  color="green"
                  onClick={() => {
                    setSelectedPasal(pasal)
                    openRestore()
                  }}
                />
                <IconAction
                  label="Hapus permanen"
                  icon={<IconTrash size={18} />}
                  color="red"
                  onClick={() => {
                    setSelectedPasal(pasal)
                    openDelete()
                  }}
                />
              </Group>
            )}
            emptyText="Tidak ada pasal di sampah"
          />
        </Stack>
      </Card>

      {/* Restore Modal */}
      <Modal opened={restoreModal} onClose={closeRestore} title="Pulihkan Pasal">
        <Stack gap="md">
          <Text>
            Apakah Anda yakin ingin memulihkan pasal ini?
          </Text>
          <Card withBorder padding="sm">
            <Text fw={500}>
              {selectedPasal?.undang_undang?.kode ?? 'UU dihapus'} - {formatPasalLabel(selectedPasal?.nomor)}
            </Text>
            {selectedPasal?.judul && (
              <Text size="sm" c="dimmed">{selectedPasal.judul}</Text>
            )}
          </Card>
          <Text size="sm" c="dimmed">
            Link pasal terkait juga akan dipulihkan (jika pasal target masih aktif).
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
              Pulihkan
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
              {selectedPasal?.undang_undang?.kode ?? 'UU dihapus'} - {formatPasalLabel(selectedPasal?.nomor)}
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
      <Modal opened={bulkRestoreModal} onClose={closeBulkRestore} title="Pulihkan Pasal">
        <Stack gap="md">
          <Text>
            Apakah Anda yakin ingin memulihkan <strong>{selectedIds.length} pasal</strong>?
          </Text>
          <Text size="sm" c="dimmed">
            Link pasal terkait juga akan dipulihkan (jika pasal target masih aktif).
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
              Pulihkan {selectedIds.length} Pasal
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
