import { ReactNode, useEffect, useMemo, useState } from 'react'
import { TextInput, Group, Pagination, Select, Text, Stack, Card, ScrollArea, SegmentedControl } from '@mantine/core'
import { IconSearch } from '@tabler/icons-react'

interface PaginationInfo {
  currentPage: number
  totalPages: number
  pageSize: number
  totalItems: number
  startIndex: number
  endIndex: number
}

interface SectionConfig<T> {
  title: string
  emptyText: string
  render: (items: T[], pagination: PaginationInfo) => ReactNode
}

interface SearchablePaginatedListProps<T> {
  data: T[]
  searchPlaceholder?: string
  getSearchableText: (item: T) => string
  isActive: (item: T) => boolean
  activeSection: SectionConfig<T>
  inactiveSection: SectionConfig<T>
  /** Tombol tambahan di kanan kolom pencarian (mis. refresh). */
  toolbarActions?: ReactNode
  defaultPageSize?: number
  isLoading?: boolean
  loadingText?: string
}

const PAGE_SIZE_OPTIONS = [
  { value: '5', label: '5 per halaman' },
  { value: '10', label: '10 per halaman' },
  { value: '15', label: '15 per halaman' },
  { value: '20', label: '20 per halaman' },
]

type SectionKey = 'active' | 'inactive'

/** Satu kartu: pencarian, pilihan kelompok (aktif/nonaktif), tabel, dan paginasi. */
export function SearchablePaginatedList<T>({
  data,
  searchPlaceholder = 'Cari berdasarkan nama atau email...',
  getSearchableText,
  isActive,
  activeSection,
  inactiveSection,
  toolbarActions,
  defaultPageSize = 10,
  isLoading = false,
  loadingText = 'Memuat data...',
}: SearchablePaginatedListProps<T>) {
  const [searchQuery, setSearchQuery] = useState('')
  const [sectionKey, setSectionKey] = useState<SectionKey>('active')
  const [pageSize, setPageSize] = useState(defaultPageSize)
  const [page, setPage] = useState(1)

  const filteredData = useMemo(() => {
    const query = searchQuery.toLowerCase().trim()
    if (!query) return data
    return data.filter((item) => getSearchableText(item).toLowerCase().includes(query))
  }, [data, searchQuery, getSearchableText])

  const activeItems = useMemo(() => filteredData.filter(isActive), [filteredData, isActive])
  const inactiveItems = useMemo(() => filteredData.filter((item) => !isActive(item)), [filteredData, isActive])

  useEffect(() => {
    setPage(1)
  }, [searchQuery, sectionKey])

  const section = sectionKey === 'active' ? activeSection : inactiveSection
  const items = sectionKey === 'active' ? activeItems : inactiveItems
  const totalPages = Math.ceil(items.length / pageSize)
  const startIndex = (page - 1) * pageSize
  const endIndex = Math.min(startIndex + pageSize, items.length)
  const pagination: PaginationInfo = {
    currentPage: page,
    totalPages,
    pageSize,
    totalItems: items.length,
    startIndex,
    endIndex,
  }

  return (
    <Card padding="md">
      <Stack gap="md">
        <Group gap="sm" wrap="wrap">
          <TextInput
            placeholder={searchPlaceholder}
            leftSection={<IconSearch size={16} />}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.currentTarget.value)}
            style={{ flex: 1, minWidth: 220 }}
          />
          <SegmentedControl
            value={sectionKey}
            onChange={(value) => setSectionKey(value as SectionKey)}
            data={[
              { value: 'active', label: `${activeSection.title} (${activeItems.length})` },
              { value: 'inactive', label: `${inactiveSection.title} (${inactiveItems.length})` },
            ]}
          />
          {toolbarActions}
        </Group>

        {isLoading ? (
          <Text c="dimmed" ta="center" py="lg">
            {loadingText}
          </Text>
        ) : items.length === 0 ? (
          <Text c="dimmed" ta="center" py="lg">
            {searchQuery.trim() ? 'Tidak ada yang cocok dengan pencarian.' : section.emptyText}
          </Text>
        ) : (
          <>
            <ScrollArea style={{ width: '100%' }} type="auto" scrollbarSize={6} offsetScrollbars>
              {section.render(items.slice(startIndex, endIndex), pagination)}
            </ScrollArea>
            <Group justify="space-between">
              <Text size="sm" c="dimmed">
                Menampilkan {startIndex + 1}-{endIndex} dari {items.length}
              </Text>
              <Group gap="md">
                {totalPages > 1 && <Pagination value={page} onChange={setPage} total={totalPages} size="sm" />}
                <Select
                  comboboxProps={{ withinPortal: true }}
                  data={PAGE_SIZE_OPTIONS}
                  value={String(pageSize)}
                  onChange={(value) => {
                    setPageSize(Number(value))
                    setPage(1)
                  }}
                  w={150}
                  size="sm"
                  allowDeselect={false}
                />
              </Group>
            </Group>
          </>
        )}
      </Stack>
    </Card>
  )
}
