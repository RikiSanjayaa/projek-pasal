import { useState, useEffect, useMemo, useRef } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import {
  Alert,
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
  Tooltip,
} from '@mantine/core'
import { useDebouncedValue, useDisclosure } from '@mantine/hooks'
import { notifications } from '@mantine/notifications'
import {
  IconArrowsSort,
  IconPlus,
  IconSearch,
  IconEdit,
  IconTrash,
  IconTrashFilled,
} from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { DataTable, type Column } from '@/components/DataTable'
import { IconAction } from '@/components/IconAction'
import { SearchHighlight } from '@/components/SearchHighlight'
import { VERIFICATION_OPTIONS, VerificationBadge } from '@/components/VerificationBadge'
import { api, toQueryString, type PaginatedResponse } from '@/lib/api'
import type { PasalWithUndangUndang } from '@/lib/database.types'
import { formatPasalLabel } from '@/lib/pasal-format'
import { invalidatePasalData } from '@/lib/query-invalidation'
import { defaultSearchSuggestions } from '@/lib/smart-search'

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

const SORT_DATE_LABEL: Record<string, { key: 'updated_at' | 'created_at' | 'verified_at'; label: string }> = {
  updated_at: { key: 'updated_at', label: 'Diubah' },
  created_at: { key: 'created_at', label: 'Ditambahkan' },
  verified_at: { key: 'verified_at', label: 'Diverifikasi' },
}

const formatShortDate = (value: string) =>
  new Date(value).toLocaleString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })

const getPasalColumns = (searchQuery: string, extraTerms: string[], sort: string): Column<PasalWithUndangUndang>[] => [
  {
    key: 'nomor',
    title: 'Pasal',
    width: 130,
    render: (value, record) => (
      <Stack gap={4} align="flex-start">
        <Badge color="blue" variant="light" size="sm">
          {record.undang_undang?.kode}
        </Badge>
        <SearchHighlight fw={600} text={formatPasalLabel(value as string)} query={searchQuery} extraTerms={extraTerms} />
      </Stack>
    ),
  },
  {
    key: 'judul',
    title: 'Judul',
    width: 200,
    render: (value, record) => (
      <Stack gap={2}>
        <SearchHighlight size="sm" lineClamp={2} text={(value as string) || '-'} query={searchQuery} extraTerms={extraTerms} />
        {record.bab && (
          <Text size="xs" c="dimmed" lineClamp={2}>{record.bab}</Text>
        )}
      </Stack>
    ),
  },
  {
    key: 'isi',
    title: 'Isi',
    render: (value) => (
      <SearchHighlight size="sm" c="dimmed" lineClamp={2} text={String(value || '')} query={searchQuery} extraTerms={extraTerms} autoSnippet />
    ),
  },
  {
    key: 'verification_status',
    title: 'Status',
    width: 150,
    render: (_, record) => {
      const status = getPasalStatus(record)
      const sortDate = SORT_DATE_LABEL[sort]
      const sortValue = sortDate ? record[sortDate.key] : null
      return (
        <Stack gap={4} align="flex-start">
          <VerificationBadge
            status={record.verification_status}
            verifiedAt={record.verified_at}
            verifierName={record.verifier?.nama}
            size="sm"
          />
          {status.label !== 'Aktif' && (
            <Tooltip label={status.description}>
              <Badge color={status.color} variant="light" size="sm">
                {status.label}
              </Badge>
            </Tooltip>
          )}
          {sortDate && sortValue && (
            <Text size="xs" c="dimmed">
              {sortDate.label} {formatShortDate(sortValue)}
            </Text>
          )}
        </Stack>
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

  const filterVerification = searchParams.get('verifikasi')
  const setFilterVerification = (value: string | null) => {
    const params = new URLSearchParams(searchParams)
    if (value) {
      params.set('verifikasi', value)
    } else {
      params.delete('verifikasi')
    }
    params.delete('page')
    setSearchParams(params)
  }

  const sort = searchParams.get('urut') || 'nomor'
  const setSort = (value: string | null) => {
    const params = new URLSearchParams(searchParams)
    if (value && value !== 'nomor') {
      params.set('urut', value)
    } else {
      params.delete('urut')
    }
    params.delete('page')
    setSearchParams(params)
  }

  const [deleteModal, { open: openDelete, close: closeDelete }] = useDisclosure(false)
  const [bulkDeleteModal, { open: openBulkDelete, close: closeBulkDelete }] = useDisclosure(false)
  const [selectedPasal, setSelectedPasal] = useState<PasalWithUndangUndang | null>(null)
  const [selectedIds, setSelectedIds] = useState<string[]>([])

  const { data: smartSuggestionData } = useQuery({
    queryKey: ['search_aliases', 'suggestions', debouncedSearch],
    queryFn: async () => {
      return api.get<{ suggestions: string[] }>(
        `/admin/search-aliases/suggestions${toQueryString({ search: debouncedSearch })}`
      )
    },
    enabled: debouncedSearch.trim().length > 1,
  })

  const smartSuggestions = useMemo(() => {
    const remote = smartSuggestionData?.suggestions || []
    return remote.length > 0 ? remote : defaultSearchSuggestions(debouncedSearch)
  }, [smartSuggestionData?.suggestions, debouncedSearch])

  const pasalColumns = useMemo(
    () => getPasalColumns(debouncedSearch, smartSuggestions, sort),
    [debouncedSearch, smartSuggestions, sort]
  )

  // UU untuk filter: termasuk yang nonaktif, tapi bukan yang sudah dihapus (Ujicoba, KUHAP 1981).
  const { data: undangUndangList } = useQuery({
    queryKey: ['undang_undang', 'list', 'filter'],
    queryFn: async () => {
      const response = await api.get<PaginatedResponse<{ id: string; kode: string; nama: string; is_active: boolean }>>(
        '/admin/undang-undang?per_page=200'
      )
      return response.data
    },
  })

  // Track previous value to only reset page on actual changes
  const prevDebouncedSearch = useRef(debouncedSearch)

  useEffect(() => {
    if (debouncedSearch !== prevDebouncedSearch.current) {
      prevDebouncedSearch.current = debouncedSearch

      if (page > 1) {
        const params = new URLSearchParams(searchParams)
        params.delete('page')
        setSearchParams(params, { replace: true })
      }
    }
  }, [debouncedSearch, page, searchParams, setSearchParams])

  // Fetch pasal with pagination
  const { data: pasalData, isLoading } = useQuery({
    queryKey: ['pasal', 'list', page, pageSize, debouncedSearch, filterUU, filterVerification, sort],
    queryFn: async () => {
      // Handle "pasal" prefix - extract just the number/identifier
      let searchTerm = debouncedSearch.toLowerCase().trim()
      if (searchTerm.startsWith('pasal ')) {
        searchTerm = searchTerm.substring(6).trim()
      }

      const response = await api.get<PaginatedResponse<PasalWithUndangUndang>>(
        `/admin/pasal${toQueryString({
          page,
          per_page: pageSize,
          search: searchTerm,
          undang_undang_id: filterUU,
          verification_status: filterVerification,
          sort,
        })}`
      )

      // Sort results by numeric relevance when searching by number
      let sortedData = response.data
      if (sort === 'nomor' && searchTerm && /^\d/.test(searchTerm)) {
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

      return { data: sortedData, count: response.total }
    },
  })

  // Delete mutation (soft delete with deleted_at timestamp)
  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/admin/pasal/${id}`)
    },
    onSuccess: async () => {
      await invalidatePasalData(queryClient)
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
      await api.post('/admin/pasal/bulk-delete', { ids })
    },
    onSuccess: async () => {
      await invalidatePasalData(queryClient)
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

      <Card padding="md">
        <Stack gap="md">
          <TextInput
            placeholder="Cari nomor, judul, atau isi pasal..."
            leftSection={<IconSearch size={16} />}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <Group wrap="wrap" align="flex-start">
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
            <Select
              placeholder="Status verifikasi"
              data={VERIFICATION_OPTIONS}
              value={filterVerification}
              onChange={setFilterVerification}
              clearable
              w={{ base: '100%', sm: 200 }}
            />
            <Select
              aria-label="Urutkan"
              leftSection={<IconArrowsSort size={16} />}
              data={[
                { value: 'nomor', label: debouncedSearch.trim() ? 'Paling relevan' : 'Urutan pasal' },
                { value: 'updated_at', label: 'Terakhir diubah' },
                { value: 'created_at', label: 'Terakhir ditambahkan' },
                { value: 'verified_at', label: 'Terakhir diverifikasi' },
              ]}
              value={sort}
              onChange={setSort}
              allowDeselect={false}
              w={{ base: '100%', sm: 210 }}
            />
          </Group>

          {!isLoading && debouncedSearch.trim() && (pasalData?.count || 0) === 0 && smartSuggestions.length > 0 && (
            <Alert color="yellow" variant="light" title="Tidak ada hasil persis">
              <Stack gap="xs">
                <Text size="sm">Coba cari dengan istilah yang lebih umum:</Text>
                <Group gap="xs">
                  {smartSuggestions.map((suggestion) => (
                    <Button key={suggestion} size="xs" variant="light" onClick={() => setSearch(suggestion)}>
                      {suggestion}
                    </Button>
                  ))}
                </Group>
              </Stack>
            </Alert>
          )}
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
              <Group gap={2} wrap="nowrap">
                <IconAction label="Edit pasal" icon={<IconEdit size={18} />} color="blue" onClick={() => navigate(`/pasal/${pasal.id}/edit`)} />
                <IconAction label="Hapus pasal" icon={<IconTrash size={18} />} color="red" onClick={() => handleDelete(pasal)} />
              </Group>
            )}
            emptyText="Tidak ada data pasal"
          />
        </Stack>
      </Card>

      {/* Delete Confirmation Modal */}
      <Modal
        opened={deleteModal}
        onClose={closeDelete}
        title="Konfirmasi Hapus"
        centered
      >
        <Text mb="lg">
          Apakah Anda yakin ingin menghapus <strong>{formatPasalLabel(selectedPasal?.nomor)}</strong> dari{' '}
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
