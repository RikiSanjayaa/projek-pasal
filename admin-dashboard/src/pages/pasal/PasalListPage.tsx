import { useState, useEffect } from 'react'
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
  Divider,
  Loader,
  Collapse,
  Box,
} from '@mantine/core'
import { useDebouncedValue, useDisclosure } from '@mantine/hooks'
import { notifications } from '@mantine/notifications'
import {
  IconPlus,
  IconSearch,
  IconEdit,
  IconTrash,
  IconTrashFilled,
  IconLink,
  IconChevronDown,
  IconChevronUp,
} from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { DataTable, type Column } from '@/components/DataTable'
import { supabase } from '@/lib/supabase'
import type { PasalWithUndangUndang } from '@/lib/database.types'

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

const PAGE_SIZE_OPTIONS = [
  { value: '5', label: '5 per halaman' },
  { value: '10', label: '10 per halaman' },
  { value: '15', label: '15 per halaman' },
  { value: '20', label: '20 per halaman' },
  { value: '30', label: '30 per halaman' },
]

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
]

// Component to show linked pasal detail when expanded
function LinkedPasalDetail({ pasalId, excludePasalId }: { pasalId: string; excludePasalId?: string }) {
  const { data: pasal, isLoading } = useQuery({
    queryKey: ['pasal', 'detail', pasalId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('pasal')
        .select('*, undang_undang(*)')
        .eq('id', pasalId)
        .single()

      if (error) throw error
      return data as PasalWithUndangUndang
    },
    enabled: !!pasalId,
  })

  // Fetch related links for this pasal (only where this pasal is source, excluding the parent)
  const { data: relatedLinks } = useQuery({
    queryKey: ['pasal_links', 'related', pasalId, excludePasalId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('pasal_links')
        .select(`
          id,
          source_pasal_id,
          target_pasal_id,
          keterangan,
          target_pasal:pasal!pasal_links_target_pasal_id_fkey(id, nomor, judul, undang_undang(kode))
        `)
        .eq('source_pasal_id', pasalId)
        .eq('is_active', true)

      if (error) throw error

      // Filter out the link to the excluded pasal (to prevent loop)
      const filtered = (data as unknown as PasalLinkWithRelations[]).filter((link) => {
        return link.target_pasal_id !== excludePasalId
      })

      return filtered
    },
    enabled: !!pasalId,
  })

  if (isLoading) {
    return (
      <Box mt="sm" p="sm" style={{ borderTop: '1px solid var(--mantine-color-default-border)' }}>
        <Loader size="xs" />
      </Box>
    )
  }

  if (!pasal) return null

  return (
    <Box mt="sm" p="sm" style={{ borderTop: '1px solid var(--mantine-color-default-border)' }}>
      <Stack gap="xs">
        {/* Isi Pasal */}
        <div>
          <Text size="xs" c="dimmed" mb={2}>Isi Pasal</Text>
          <Card withBorder padding="xs" bg="var(--mantine-color-default-hover)">
            <Text size="xs" style={{ whiteSpace: 'pre-wrap' }} lineClamp={6}>
              {pasal.isi}
            </Text>
          </Card>
        </div>

        {/* Penjelasan */}
        {pasal.penjelasan && (
          <div>
            <Text size="xs" c="dimmed" mb={2}>Penjelasan</Text>
            <Card withBorder padding="xs" bg="var(--mantine-color-blue-light)">
              <Text size="xs" style={{ whiteSpace: 'pre-wrap' }} lineClamp={3}>
                {pasal.penjelasan}
              </Text>
            </Card>
          </div>
        )}

        {/* Keywords */}
        {pasal.keywords && pasal.keywords.length > 0 && (
          <Group gap={4}>
            {pasal.keywords.slice(0, 5).map((kw, idx) => (
              <Badge key={idx} variant="outline" size="xs">
                {kw}
              </Badge>
            ))}
            {pasal.keywords.length > 5 && (
              <Badge size="xs" variant="outline" color="gray">
                +{pasal.keywords.length - 5}
              </Badge>
            )}
          </Group>
        )}

        {/* Related pasal links (excluding parent) */}
        {relatedLinks && relatedLinks.length > 0 && (
          <div>
            <Text size="xs" c="dimmed" mb={2}>
              <IconLink size={10} style={{ verticalAlign: 'middle', marginRight: 2 }} />
              Pasal terkait lainnya
            </Text>
            <Group gap={4}>
              {relatedLinks.map((link) => {
                return (
                  <Badge
                    key={link.id}
                    size="xs"
                    variant="light"
                    color="gray"
                  >
                    {link.target_pasal?.undang_undang?.kode} Pasal {link.target_pasal?.nomor}
                  </Badge>
                )
              })}
            </Group>
          </div>
        )}
      </Stack>
    </Box>
  )
}

export function PasalListPage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const queryClient = useQueryClient()
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [search, setSearch] = useState('')
  const [debouncedSearch] = useDebouncedValue(search, 300)
  const [filterUU, setFilterUU] = useState<string | null>(searchParams.get('uu'))
  const [deleteModal, { open: openDelete, close: closeDelete }] = useDisclosure(false)
  const [bulkDeleteModal, { open: openBulkDelete, close: closeBulkDelete }] = useDisclosure(false)
  const [viewModal, { open: openView, close: closeView }] = useDisclosure(false)
  const [selectedPasal, setSelectedPasal] = useState<PasalWithUndangUndang | null>(null)
  const [selectedIds, setSelectedIds] = useState<string[]>([])
  const [expandedLinkId, setExpandedLinkId] = useState<string | null>(null)

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

  // Update URL params when filterUU changes
  useEffect(() => {
    const params = new URLSearchParams(searchParams)
    if (filterUU) {
      params.set('uu', filterUU)
    } else {
      params.delete('uu')
    }
    const newSearch = params.toString()
    if (newSearch !== searchParams.toString()) {
      navigate({ search: newSearch }, { replace: true })
    }
  }, [filterUU, navigate, searchParams])

  // Fetch pasal with pagination
  const { data: pasalData, isLoading } = useQuery({
    queryKey: ['pasal', 'list', page, pageSize, debouncedSearch, filterUU],
    queryFn: async () => {
      let query = supabase
        .from('pasal')
        .select('*, undang_undang!inner(*)', { count: 'exact' })
        .eq('is_active', true)
        .order('nomor')
        .range((page - 1) * pageSize, page * pageSize - 1)

      if (debouncedSearch) {
        query = query.or(`nomor.ilike.%${debouncedSearch}%,judul.ilike.%${debouncedSearch}%,isi.ilike.%${debouncedSearch}%`)
      }

      if (filterUU) {
        query = query.eq('undang_undang_id', filterUU)
      }

      const { data, error, count } = await query

      if (error) throw error
      return { data: data as PasalWithUndangUndang[], count: count || 0 }
    },
  })

  // Fetch pasal links for selected pasal (only where selected pasal is source)
  const { data: pasalLinks, isLoading: isLoadingLinks } = useQuery({
    queryKey: ['pasal_links', selectedPasal?.id],
    queryFn: async () => {
      if (!selectedPasal?.id) return [] as PasalLinkWithRelations[]

      const { data, error } = await supabase
        .from('pasal_links')
        .select(`
          id,
          source_pasal_id,
          target_pasal_id,
          keterangan,
          target_pasal:pasal!pasal_links_target_pasal_id_fkey(id, nomor, judul, undang_undang(kode))
        `)
        .eq('source_pasal_id', selectedPasal.id)
        .eq('is_active', true)

      if (error) throw error
      return data as unknown as PasalLinkWithRelations[]
    },
    enabled: !!selectedPasal?.id && viewModal,
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

  const handleView = (pasal: PasalWithUndangUndang) => {
    setSelectedPasal(pasal)
    openView()
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
          onRowClick={handleView}
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

      {/* View Pasal Modal */}
      <Modal
        opened={viewModal}
        onClose={closeView}
        title={
          <Group gap="xs">
            <Badge color="blue" variant="light">
              {selectedPasal?.undang_undang?.kode}
            </Badge>
            <Text fw={600}>Pasal {selectedPasal?.nomor}</Text>
          </Group>
        }
        size="lg"
        centered
      >
        <Stack gap="md">
          {selectedPasal?.judul && (
            <div>
              <Text size="sm" c="dimmed" mb={4}>Judul</Text>
              <Text fw={500}>{selectedPasal.judul}</Text>
            </div>
          )}

          <div>
            <Text size="sm" c="dimmed" mb={4}>Isi Pasal</Text>
            <Card withBorder padding="sm" bg="var(--mantine-color-default-hover)">
              <Text style={{ whiteSpace: 'pre-wrap' }}>{selectedPasal?.isi}</Text>
            </Card>
          </div>

          {selectedPasal?.penjelasan && (
            <div>
              <Text size="sm" c="dimmed" mb={4}>Penjelasan</Text>
              <Card withBorder padding="sm" bg="var(--mantine-color-blue-light)">
                <Text size="sm" style={{ whiteSpace: 'pre-wrap' }}>{selectedPasal.penjelasan}</Text>
              </Card>
            </div>
          )}

          {selectedPasal?.keywords && selectedPasal.keywords.length > 0 && (
            <div>
              <Text size="sm" c="dimmed" mb={4}>Keywords</Text>
              <Group gap={4}>
                {selectedPasal.keywords.map((kw, idx) => (
                  <Badge key={idx} variant="outline" size="sm">
                    {kw}
                  </Badge>
                ))}
              </Group>
            </div>
          )}

          <Divider my="sm" />

          {/* Pasal Terkait Section */}
          <div>
            <Group justify="space-between" mb="xs">
              <Text size="sm" c="dimmed">
                <IconLink size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} />
                Pasal Terkait
              </Text>
            </Group>

            {isLoadingLinks ? (
              <Group justify="center" py="md">
                <Loader size="sm" />
              </Group>
            ) : pasalLinks && pasalLinks.length > 0 ? (
              <Stack gap="xs">
                {pasalLinks.map((link) => {
                  const targetPasal = link.target_pasal
                  const isExpanded = expandedLinkId === link.id

                  return (
                    <Card
                      key={link.id}
                      withBorder
                      padding="xs"
                      radius="sm"
                      style={{ cursor: 'pointer' }}
                    >
                      <Group
                        justify="space-between"
                        onClick={() => setExpandedLinkId(isExpanded ? null : link.id)}
                      >
                        <Group gap="xs">
                          {isExpanded ? <IconChevronUp size={14} /> : <IconChevronDown size={14} />}
                          <Badge size="xs" color="gray" variant="light">
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
                      </Group>
                      {link.keterangan && (
                        <Text size="xs" c="dimmed" mt={4}>
                          {link.keterangan}
                        </Text>
                      )}

                      {/* Expanded detail of linked pasal */}
                      <Collapse in={isExpanded}>
                        <LinkedPasalDetail
                          pasalId={targetPasal?.id}
                          excludePasalId={selectedPasal?.id}
                        />
                      </Collapse>
                    </Card>
                  )
                })}
              </Stack>
            ) : (
              <Text size="sm" c="dimmed" ta="center" py="sm">
                Tidak ada pasal terkait
              </Text>
            )}
          </div>

          <Group justify="flex-end" mt="md">
            <Button variant="default" onClick={closeView}>
              Tutup
            </Button>
            <Button onClick={() => {
              closeView()
              navigate(`/pasal/${selectedPasal?.id}/edit`)
            }}>
              Edit Pasal
            </Button>
          </Group>
        </Stack>
      </Modal>
    </Stack>
  )
}
