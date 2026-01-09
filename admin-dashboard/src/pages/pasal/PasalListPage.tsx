import { useState, useEffect, useRef } from 'react'
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
  ActionIcon,
  Modal,
  Tooltip,
  MultiSelect,
} from '@mantine/core'
import { useDebouncedValue, useDisclosure } from '@mantine/hooks'
import { notifications } from '@mantine/notifications'
import {
  IconPlus,
  IconSearch,
  IconEdit,
  IconTrash,
  IconTrashFilled,
} from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { DataTable, type Column } from '@/components/DataTable'
import { supabase } from '@/lib/supabase'
import type { PasalWithUndangUndang } from '@/lib/database.types'

const PAGE_SIZE_OPTIONS = [
  { value: '5', label: '5 per halaman' },
  { value: '10', label: '10 per halaman' },
  { value: '15', label: '15 per halaman' },
  { value: '20', label: '20 per halaman' },
  { value: '30', label: '30 per halaman' },
]

// Helper function to determine pasal status
const getPasalStatus = (pasal: PasalWithUndangUndang): { label: string; color: string; description: string } => {
  // Check if UU is inactive (pasal inactive due to UU cascade)
  if (!pasal.undang_undang?.is_active) {
    return {
      label: 'UU Nonaktif',
      color: 'orange',
      description: 'Pasal tidak aktif karena UU dinonaktifkan',
    }
  }
  // Check if pasal itself is inactive (soft-deleted)
  if (!pasal.is_active) {
    return {
      label: 'Dihapus',
      color: 'red',
      description: 'Pasal telah dihapus',
    }
  }
  // Active
  return {
    label: 'Aktif',
    color: 'green',
    description: 'Pasal aktif dan akan tampil di aplikasi mobile',
  }
}

// Define table columns
const pasalColumns: Column<PasalWithUndangUndang>[] = [
  {
    key: 'undang_undang',
    title: 'Undang-Undang',
    width: 120,
    render: (_, record) => (
      <Badge color="blue" variant="light">
        {record.undang_undang?.kode}
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
    key: 'status',
    title: 'Status',
    width: 120,
    render: (_, record) => {
      const status = getPasalStatus(record)
      return (
        <Tooltip label={status.description}>
          <Badge color={status.color} variant="light">
            {status.label}
          </Badge>
        </Tooltip>
      )
    },
  },
]

export function PasalListPage() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const queryClient = useQueryClient()

  // Derive page directly from URL - this is the source of truth
  const page = parseInt(searchParams.get('page') || '1', 10)
  const setPage = (newPage: number) => {
    const params = new URLSearchParams(searchParams)
    if (newPage > 1) {
      params.set('page', newPage.toString())
    } else {
      params.delete('page')
    }
    setSearchParams(params)
  }

  const [pageSize, setPageSize] = useState(10)
  const [search, setSearch] = useState('')
  const [debouncedSearch] = useDebouncedValue(search, 300)

  // Derive filterUU from URL as well
  const filterUU = searchParams.get('uu')
  const setFilterUU = (newUU: string | null) => {
    const params = new URLSearchParams(searchParams)
    if (newUU) {
      params.set('uu', newUU)
    } else {
      params.delete('uu')
    }
    // Reset page when filter changes
    params.delete('page')
    setSearchParams(params)
  }

  const [selectedKeywords, setSelectedKeywords] = useState<string[]>([])
  const [deleteModal, { open: openDelete, close: closeDelete }] = useDisclosure(false)
  const [bulkDeleteModal, { open: openBulkDelete, close: closeBulkDelete }] = useDisclosure(false)
  const [selectedPasal, setSelectedPasal] = useState<PasalWithUndangUndang | null>(null)
  const [selectedIds, setSelectedIds] = useState<string[]>([])

  // Fetch undang-undang for filter (include inactive UU)
  const { data: undangUndangList } = useQuery({
    queryKey: ['undang_undang', 'list', 'all'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('undang_undang')
        .select('id, kode, nama, is_active')
        .order('kode')

      if (error) throw error
      return data as { id: string; kode: string; nama: string; is_active: boolean }[]
    },
  })

  // Fetch keywords for filter
  const { data: keywordsList } = useQuery({
    queryKey: ['keywords', 'list'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('pasal')
        .select('keywords')
        .eq('is_active', true)

      if (error) throw error

      const allKeywords = (data as { keywords: string[] | null }[]).flatMap(p => p.keywords || []).filter(Boolean)
      return [...new Set(allKeywords)].sort()
    },
  })

  // Track previous values to only reset page on actual changes
  const prevDebouncedSearch = useRef(debouncedSearch)
  const prevSelectedKeywordsStr = useRef(JSON.stringify(selectedKeywords))

  useEffect(() => {
    const currentKeywordsStr = JSON.stringify(selectedKeywords)
    const keywordsChanged = currentKeywordsStr !== prevSelectedKeywordsStr.current
    const searchChanged = debouncedSearch !== prevDebouncedSearch.current

    if (searchChanged || keywordsChanged) {
      prevDebouncedSearch.current = debouncedSearch
      prevSelectedKeywordsStr.current = currentKeywordsStr

      if (page > 1) {
        const params = new URLSearchParams(searchParams)
        params.delete('page')
        setSearchParams(params, { replace: true })
      }
    }
  }, [debouncedSearch, selectedKeywords, page, searchParams, setSearchParams])

  // Fetch pasal with pagination
  const { data: pasalData, isLoading } = useQuery({
    queryKey: ['pasal', 'list', page, pageSize, debouncedSearch, filterUU, selectedKeywords],
    queryFn: async () => {
      // Handle "pasal" prefix - extract just the number/identifier
      let searchTerm = debouncedSearch.toLowerCase().trim()
      if (searchTerm.startsWith('pasal ')) {
        searchTerm = searchTerm.substring(6).trim()
      }

      // Show active pasal AND pasal inactive due to UU (not soft-deleted)
      // Soft-deleted pasal (deleted_at IS NOT NULL) are shown in the Trash page
      let query = supabase
        .from('pasal')
        .select('*, undang_undang!inner(*)', { count: 'exact' })
        .is('deleted_at', null)
        .order('nomor')
        .range((page - 1) * pageSize, page * pageSize - 1)

      if (searchTerm) {
        query = query.or(`nomor.ilike.%${searchTerm}%,judul.ilike.%${searchTerm}%,isi.ilike.%${searchTerm}%`)
      }

      if (filterUU) {
        query = query.eq('undang_undang_id', filterUU)
      }

      if (selectedKeywords.length > 0) {
        query = query.overlaps('keywords', selectedKeywords)
      }

      const { data, error, count } = await query

      if (error) throw error

      // Sort results by numeric relevance when searching by number
      let sortedData = data as PasalWithUndangUndang[]
      if (searchTerm && /^\d/.test(searchTerm)) {
        sortedData = [...sortedData].sort((a, b) => {
          const aNomor = a.nomor.toLowerCase()
          const bNomor = b.nomor.toLowerCase()

          // Exact match gets highest priority
          const aExact = aNomor === searchTerm
          const bExact = bNomor === searchTerm
          if (aExact !== bExact) return bExact ? 1 : -1

          // Starts with gets second priority
          const aStarts = aNomor.startsWith(searchTerm)
          const bStarts = bNomor.startsWith(searchTerm)
          if (aStarts !== bStarts) return bStarts ? 1 : -1

          // Within same category, sort numerically
          const aNum = parseInt(aNomor.replace(/[^0-9]/g, '')) || 999
          const bNum = parseInt(bNomor.replace(/[^0-9]/g, '')) || 999
          return aNum - bNum
        })
      }

      return { data: sortedData, count: count || 0 }
    },
  })

  // Delete mutation (soft delete with deleted_at timestamp)
  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { data, error } = await supabase
        .from('pasal')
        .update({
          is_active: false,
          deleted_at: new Date().toISOString(),
        } as never)
        .eq('id', id)
        .select()

      if (error) throw error

      // Check if update actually happened (RLS might silently block)
      if (!data || data.length === 0) {
        throw new Error('Gagal menghapus. Pastikan Anda terdaftar sebagai admin di database.')
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal'] })
      notifications.show({
        title: 'Berhasil',
        message: 'Pasal berhasil dihapus',
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

  // Bulk delete mutation (soft delete with deleted_at timestamp)
  const bulkDeleteMutation = useMutation({
    mutationFn: async (ids: string[]) => {
      const { data, error } = await supabase
        .from('pasal')
        .update({
          is_active: false,
          deleted_at: new Date().toISOString(),
        } as never)
        .in('id', ids)
        .select()

      if (error) throw error

      if (!data || data.length === 0) {
        throw new Error('Gagal menghapus. Pastikan Anda terdaftar sebagai admin di database.')
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pasal'] })
      notifications.show({
        title: 'Berhasil',
        message: `${selectedIds.length} pasal berhasil dihapus`,
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

  const handleDelete = (pasal: PasalWithUndangUndang) => {
    setSelectedPasal(pasal)
    openDelete()
  }

  const confirmDelete = () => {
    if (selectedPasal) {
      deleteMutation.mutate(selectedPasal.id)
    }
  }

  const confirmBulkDelete = () => {
    if (selectedIds.length > 0) {
      bulkDeleteMutation.mutate(selectedIds)
    }
  }

  const handlePageSizeChange = (value: number) => {
    setPageSize(value)
    setPage(1) // Reset to first page when changing page size
    setSelectedIds([]) // Clear selection when changing page size
  }

  return (
    <Stack gap="lg">
      <Group justify="space-between">
        <div>
          <Title order={2}>Data Pasal</Title>
          <Text c="dimmed">Kelola data pasal dari semua undang-undang</Text>
        </div>
        <Group>
          {selectedIds.length > 0 && (
            <Button
              color="red"
              variant="light"
              leftSection={<IconTrash size={18} />}
              onClick={openBulkDelete}
            >
              Hapus {selectedIds.length} Pasal
            </Button>
          )}
          <Button
            variant="light"
            color="gray"
            leftSection={<IconTrashFilled size={18} />}
            onClick={() => navigate('/pasal/trash')}
          >
            Sampah
          </Button>
          <Button leftSection={<IconPlus size={18} />} onClick={() => navigate('/pasal/create')}>
            Tambah Pasal
          </Button>
        </Group>
      </Group>

      {/* Filters */}
      <Card shadow="sm" padding="md" radius="md" withBorder>
        <Stack gap="md">
          <Group wrap="wrap" align="flex-start">
            <TextInput
              placeholder="Cari nomor, judul, atau isi pasal..."
              leftSection={<IconSearch size={16} />}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              w={{ base: '100%', sm: 'auto' }}
              style={{ flex: 1 }}
            />
            <MultiSelect
              placeholder="Filter Keywords"
              data={keywordsList || []}
              value={selectedKeywords}
              onChange={setSelectedKeywords}
              clearable
              searchable
              w={{ base: '100%', sm: 250 }}
            />
            <Select
              placeholder="Filter Undang-Undang"
              data={
                undangUndangList?.map((uu) => ({
                  value: uu.id,
                  label: uu.is_active
                    ? `${uu.kode} - ${uu.nama}`
                    : `${uu.kode} - ${uu.nama} (Nonaktif)`,
                })) || []
              }
              value={filterUU}
              onChange={setFilterUU}
              clearable
              w={{ base: '100%', sm: 250 }}
            />
          </Group>
        </Stack>
      </Card>

      {/* Table */}
      <Card shadow="sm" padding="md" radius="md" withBorder>
        <DataTable
          columns={pasalColumns}
          data={pasalData?.data || []}
          loading={isLoading}
          current={page}
          pageSize={pageSize}
          total={pasalData?.count || 0}
          pageSizeOptions={PAGE_SIZE_OPTIONS}
          onPageChange={setPage}
          onPageSizeChange={handlePageSizeChange}
          selectable
          selectedIds={selectedIds}
          onSelect={setSelectedIds}
          onRowClick={(pasal) => navigate(`/pasal/${pasal.id}`)}
          rowActions={(pasal) => (
            <Group gap={4}>
              <Tooltip label="Edit">
                <ActionIcon
                  variant="subtle"
                  color="blue"
                  onClick={() => navigate(`/pasal/${pasal.id}/edit`)}
                >
                  <IconEdit size={16} />
                </ActionIcon>
              </Tooltip>
              <Tooltip label="Hapus">
                <ActionIcon
                  variant="subtle"
                  color="red"
                  onClick={() => handleDelete(pasal)}
                >
                  <IconTrash size={16} />
                </ActionIcon>
              </Tooltip>
            </Group>
          )}
          emptyText="Tidak ada data pasal"
        />
      </Card>

      {/* Delete Confirmation Modal */}
      <Modal
        opened={deleteModal}
        onClose={closeDelete}
        title="Konfirmasi Hapus"
        centered
      >
        <Text mb="lg">
          Apakah Anda yakin ingin menghapus <strong>Pasal {selectedPasal?.nomor}</strong> dari{' '}
          <strong>{selectedPasal?.undang_undang?.kode}</strong>?
        </Text>
        <Group justify="flex-end">
          <Button variant="default" onClick={closeDelete}>
            Batal
          </Button>
          <Button
            color="red"
            onClick={confirmDelete}
            loading={deleteMutation.isPending}
          >
            Hapus
          </Button>
        </Group>
      </Modal>

      {/* Bulk Delete Confirmation Modal */}
      <Modal
        opened={bulkDeleteModal}
        onClose={closeBulkDelete}
        title="Konfirmasi Hapus Massal"
        centered
      >
        <Text mb="lg">
          Apakah Anda yakin ingin menghapus <strong>{selectedIds.length} pasal</strong> yang dipilih?
        </Text>
        <Group justify="flex-end">
          <Button variant="default" onClick={closeBulkDelete}>
            Batal
          </Button>
          <Button
            color="red"
            onClick={confirmBulkDelete}
            loading={bulkDeleteMutation.isPending}
          >
            Hapus {selectedIds.length} Pasal
          </Button>
        </Group>
      </Modal>
    </Stack>
  )
}
