import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Stack,
  Card,
  Group,
  Text,
  Badge,
  Loader,
  Collapse,
  ActionIcon,
  Tooltip,
  Button,
  Autocomplete,
  TextInput,
  Box,
} from '@mantine/core'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { IconLink, IconChevronDown, IconChevronUp, IconPlus, IconX, IconArrowRight } from '@tabler/icons-react'
import { notifications } from '@mantine/notifications'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/contexts/AuthContext'
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
      <div style={{ padding: '0.5rem', borderTop: '1px solid var(--mantine-color-default-border)' }}>
        <Loader size="xs" />
      </div>
    )
  }

  if (!pasal) return null

  return (
    <div style={{ padding: '0.5rem', borderTop: '1px solid var(--mantine-color-default-border)' }}>
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
              <Text size="xs" style={{ whiteSpace: 'pre-wrap' }}>
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
              {relatedLinks.slice(0, 3).map((link) => (
                <Badge key={link.id} size="xs" variant="outline" color="blue">
                  {link.target_pasal?.undang_undang?.kode} Pasal {link.target_pasal?.nomor}
                </Badge>
              ))}
              {relatedLinks.length > 3 && (
                <Badge size="xs" variant="outline" color="gray">
                  +{relatedLinks.length - 3}
                </Badge>
              )}
            </Group>
          </div>
        )}
      </Stack>
    </div>
  )
}

// Type for pending link (before pasal is created)
interface PendingLink {
  targetPasalId: string
  targetPasalLabel: string
  keterangan: string
}

interface PasalLinksSidebarProps {
  pasalId?: string // Optional for create mode
  isEditMode?: boolean
  // Create mode props
  isCreateMode?: boolean
  pendingLinks?: PendingLink[]
  onAddPendingLink?: (link: PendingLink) => void
  onRemovePendingLink?: (targetPasalId: string) => void
  allPasalList?: { id: string; nomor: string; judul: string | null; undang_undang: { kode: string } }[]
}

export function PasalLinksSidebar({
  pasalId,
  isEditMode = false,
  isCreateMode = false,
  pendingLinks = [],
  onAddPendingLink,
  onRemovePendingLink,
  allPasalList = []
}: PasalLinksSidebarProps) {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { user } = useAuth()
  const [expandedLinkId, setExpandedLinkId] = useState<string | null>(null)
  const [linkSearchValue, setLinkSearchValue] = useState('')
  const [linkKeterangan, setLinkKeterangan] = useState('')

  // Fetch pasal links for this pasal (only where this pasal is source)
  const { data: pasalLinks, isLoading: isLoadingLinks } = useQuery({
    queryKey: ['pasal_links', pasalId],
    queryFn: async () => {
      if (!pasalId) return [] as PasalLinkWithRelations[]

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
      return data as unknown as PasalLinkWithRelations[]
    },
    enabled: !!pasalId && !isCreateMode,
  })

  // Fetch all pasal for autocomplete (when adding links)
  const { data: fetchedAllPasalList } = useQuery({
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
    enabled: (isEditMode || isCreateMode) && allPasalList.length === 0,
  })

  // Use props allPasalList if provided, otherwise use fetched data
  const effectiveAllPasalList = allPasalList.length > 0 ? allPasalList : fetchedAllPasalList || []

  // Handle add link for create mode (inline in onClick)

  // Add link mutation
  const addLinkMutation = useMutation({
    mutationFn: async ({ targetPasalId, keterangan }: { targetPasalId: string; keterangan?: string }) => {
      const { data, error } = await supabase
        .from('pasal_links')
        .insert({
          source_pasal_id: pasalId,
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
      queryClient.invalidateQueries({ queryKey: ['pasal_links', pasalId] })
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
      queryClient.invalidateQueries({ queryKey: ['pasal_links', pasalId] })
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

  return (
    <Card shadow="sm" padding="md" radius="md" withBorder h="fit-content">
      <Group mb="md">
        <IconLink size={20} />
        <Text fw={600}>Pasal Terkait</Text>
      </Group>

      {isCreateMode ? (
        // Create mode: show pending links
        pendingLinks.length > 0 ? (
          <Stack gap="xs">
            {pendingLinks.map((link) => (
              <Card key={link.targetPasalId} withBorder padding="xs" radius="sm">
                <Group justify="space-between" wrap="nowrap">
                  <Group gap="xs" style={{ flex: 1, minWidth: 0 }}>
                    <Badge size="xs" color="blue" variant="light">
                      Preview
                    </Badge>
                    <Text size="sm" fw={500} style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {link.targetPasalLabel}
                    </Text>
                  </Group>
                  <Tooltip label="Hapus link">
                    <ActionIcon
                      size="sm"
                      variant="subtle"
                      color="red"
                      onClick={() => onRemovePendingLink?.(link.targetPasalId)}
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
            Tidak ada pasal terkait
          </Text>
        )
      ) : isLoadingLinks ? (
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
                <Box
                  onClick={() => setExpandedLinkId(isExpanded ? null : link.id)}
                >
                  {/* Desktop Layout */}
                  <Group justify="space-between" wrap="nowrap" visibleFrom="sm">
                    <Group gap="xs" style={{ flex: 1, minWidth: 0 }}>
                      {isExpanded ? <IconChevronUp size={14} /> : <IconChevronDown size={14} />}
                      <Badge size="xs" color="gray" variant="light">
                        {targetPasal?.undang_undang?.kode}
                      </Badge>
                      <Text size="sm" fw={500} style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        Pasal {targetPasal?.nomor}
                      </Text>
                    </Group>
                    <Group gap="xs" wrap="nowrap">
                      <Button
                        size="xs"
                        variant="light"
                        color="blue"
                        onClick={(e) => {
                          e.stopPropagation()
                          navigate(`/pasal/${targetPasal?.id}`)
                        }}
                      >
                        Lihat
                        <IconArrowRight size={16} style={{ marginLeft: 6 }} />
                      </Button>
                      {isEditMode && (
                        <Tooltip label="Hapus link">
                          <ActionIcon
                            size="sm"
                            variant="subtle"
                            color="red"
                            onClick={(e) => {
                              e.stopPropagation()
                              deleteLinkMutation.mutate(link.id)
                            }}
                            loading={deleteLinkMutation.isPending}
                          >
                            <IconX size={14} />
                          </ActionIcon>
                        </Tooltip>
                      )}
                    </Group>
                  </Group>

                  {/* Mobile Layout */}
                  <Stack gap="xs" hiddenFrom="sm">
                    <Group justify="space-between" align="flex-start">
                      <Group gap="xs" style={{ flex: 1, minWidth: 0 }}>
                        {isExpanded ? <IconChevronUp size={14} /> : <IconChevronDown size={14} />}
                        <Badge size="xs" color="gray" variant="light">
                          {targetPasal?.undang_undang?.kode}
                        </Badge>
                        <Text size="sm" fw={500} style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          Pasal {targetPasal?.nomor}                        {targetPasal?.judul && (
                            <Text component="span" size="xs" c="dimmed" ml={4}>
                              - {targetPasal?.judul}
                            </Text>
                          )}                        </Text>
                      </Group>
                      {isEditMode && (
                        <Tooltip label="Hapus link">
                          <ActionIcon
                            size="sm"
                            variant="subtle"
                            color="red"
                            onClick={(e) => {
                              e.stopPropagation()
                              deleteLinkMutation.mutate(link.id)
                            }}
                            loading={deleteLinkMutation.isPending}
                          >
                            <IconX size={14} />
                          </ActionIcon>
                        </Tooltip>
                      )}
                    </Group>

                    {targetPasal?.judul && (
                      <Text size="xs" c="dimmed" style={{ marginLeft: '20px' }}>
                        {targetPasal.judul}
                      </Text>
                    )}

                    <Group justify="flex-end" mt={4}>
                      <Button
                        size="xs"
                        variant="light"
                        color="blue"
                        onClick={(e) => {
                          e.stopPropagation()
                          navigate(`/pasal/${targetPasal?.id}`)
                        }}
                        style={{ width: '100%' }}
                      >
                        Lihat Pasal
                        <IconArrowRight size={16} style={{ marginLeft: 6 }} />
                      </Button>
                    </Group>
                  </Stack>

                </Box>
                {link.keterangan && (
                  <Text size="xs" c="dimmed" mt={4}>
                    {link.keterangan}
                  </Text>
                )}

                {/* Expanded detail of linked pasal */}
                <Collapse in={isExpanded}>
                  <LinkedPasalDetail
                    pasalId={targetPasal?.id}
                    excludePasalId={pasalId}
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

      {(isEditMode || isCreateMode) && (
        <>
          {/* Add new link form */}
          <Box style={{ marginTop: '1rem', paddingTop: '1rem', borderTop: '1px solid var(--mantine-color-default-border)' }}>
            <Text size="sm" fw={500} mb="xs">Tambah Pasal Terkait</Text>

            <Stack gap="xs">
              <Autocomplete
                placeholder="Cari pasal..."
                size="xs"
                data={
                  effectiveAllPasalList
                    .filter((p) => p.id !== pasalId)
                    .filter((p) => {
                      if (isCreateMode) {
                        return !pendingLinks.some((link) => link.targetPasalId === p.id)
                      } else {
                        return !pasalLinks?.some((link) => link.target_pasal_id === p.id)
                      }
                    })
                    .map((p) => ({
                      value: p.id,
                      label: `${p.undang_undang.kode} - Pasal ${p.nomor}${p.judul ? ` (${p.judul})` : ''}`,
                    })) || []
                }
                value={linkSearchValue}
                onChange={setLinkSearchValue}
              />

              <TextInput
                placeholder="Keterangan (opsional)"
                size="xs"
                value={linkKeterangan}
                onChange={(e) => setLinkKeterangan(e.currentTarget.value)}
              />

              <Button
                size="xs"
                leftSection={<IconPlus size={12} />}
                disabled={!linkSearchValue}
                loading={isCreateMode ? false : addLinkMutation.isPending}
                variant={isCreateMode ? "light" : "default"}
                onClick={() => {
                  if (isCreateMode) {
                    if (!onAddPendingLink) return
                    const selectedItem = effectiveAllPasalList.find(
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

                      onAddPendingLink({
                        targetPasalId: selectedItem.id,
                        targetPasalLabel: `${selectedItem.undang_undang.kode} - Pasal ${selectedItem.nomor}${selectedItem.judul ? ` (${selectedItem.judul})` : ''}`,
                        keterangan: linkKeterangan,
                      })
                      setLinkSearchValue('')
                      setLinkKeterangan('')
                    }
                  } else {
                    const selectedItem = effectiveAllPasalList.find(
                      (p) => `${p.undang_undang.kode} - Pasal ${p.nomor}${p.judul ? ` (${p.judul})` : ''}` === linkSearchValue
                    )
                    if (selectedItem) {
                      addLinkMutation.mutate({
                        targetPasalId: selectedItem.id,
                        keterangan: linkKeterangan || undefined,
                      })
                    }
                  }
                }}
                style={{ alignSelf: 'flex-start' }}
              >
                Tambah
              </Button>
            </Stack>
          </Box>
        </>
      )}
    </Card>
  )
}