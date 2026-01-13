import React, { ReactNode, useMemo, useState } from 'react'
import { TextInput, Group, Pagination, Select, Text, Stack, Card, Title } from '@mantine/core'
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
  searchTitle?: string
  searchPlaceholder?: string
  getSearchableText: (item: T) => string
  isActive: (item: T) => boolean
  activeSection: SectionConfig<T>
  inactiveSection: SectionConfig<T>
  defaultPageSize?: number
}

const PAGE_SIZE_OPTIONS = [
  { value: '5', label: '5 per halaman' },
  { value: '10', label: '10 per halaman' },
  { value: '15', label: '15 per halaman' },
  { value: '20', label: '20 per halaman' },
]

export function SearchablePaginatedList<T>({
  data,
  searchTitle,
  searchPlaceholder = 'Cari berdasarkan nama atau email...',
  getSearchableText,
  isActive,
  activeSection,
  inactiveSection,
  defaultPageSize = 10,
}: SearchablePaginatedListProps<T>) {
  const [searchQuery, setSearchQuery] = useState('')
  const [activePageSize, setActivePageSize] = useState(defaultPageSize)
  const [inactivePageSize, setInactivePageSize] = useState(defaultPageSize)
  const [activePage, setActivePage] = useState(1)
  const [inactivePage, setInactivePage] = useState(1)

  // Filter all data based on search query
  const filteredData = useMemo(() => {
    if (!searchQuery.trim()) return data
    const query = searchQuery.toLowerCase().trim()
    return data.filter((item) => getSearchableText(item).toLowerCase().includes(query))
  }, [data, searchQuery, getSearchableText])

  // Split into active and inactive
  const activeItems = useMemo(() => filteredData.filter(isActive), [filteredData, isActive])
  const inactiveItems = useMemo(() => filteredData.filter((item) => !isActive(item)), [filteredData, isActive])

  // Reset pages when search changes
  React.useEffect(() => {
    setActivePage(1)
    setInactivePage(1)
  }, [searchQuery])

  // Paginate active items
  const activeTotalPages = Math.ceil(activeItems.length / activePageSize)
  const activeStartIndex = (activePage - 1) * activePageSize
  const activeEndIndex = Math.min(activeStartIndex + activePageSize, activeItems.length)
  const paginatedActiveItems = activeItems.slice(activeStartIndex, activeEndIndex)

  // Paginate inactive items
  const inactiveTotalPages = Math.ceil(inactiveItems.length / inactivePageSize)
  const inactiveStartIndex = (inactivePage - 1) * inactivePageSize
  const inactiveEndIndex = Math.min(inactiveStartIndex + inactivePageSize, inactiveItems.length)
  const paginatedInactiveItems = inactiveItems.slice(inactiveStartIndex, inactiveEndIndex)

  const activePaginationInfo: PaginationInfo = {
    currentPage: activePage,
    totalPages: activeTotalPages,
    pageSize: activePageSize,
    totalItems: activeItems.length,
    startIndex: activeStartIndex,
    endIndex: activeEndIndex,
  }

  const inactivePaginationInfo: PaginationInfo = {
    currentPage: inactivePage,
    totalPages: inactiveTotalPages,
    pageSize: inactivePageSize,
    totalItems: inactiveItems.length,
    startIndex: inactiveStartIndex,
    endIndex: inactiveEndIndex,
  }

  const renderPaginationControls = (
    pagination: PaginationInfo,
    pageSize: number,
    onPageChange: (page: number) => void,
    onPageSizeChange: (size: number) => void
  ) => (
    <Group justify="space-between" mt="md">
      <Text size="sm" c="dimmed">
        {pagination.totalItems > 0
          ? `Menampilkan ${pagination.startIndex + 1}-${pagination.endIndex} dari ${pagination.totalItems}`
          : 'Tidak ada data'}
      </Text>
      <Group gap="md">
        {pagination.totalPages > 1 && (
          <Pagination
            value={pagination.currentPage}
            onChange={onPageChange}
            total={pagination.totalPages}
            size="sm"
          />
        )}
        <Select
          comboboxProps={{ withinPortal: true }}
          data={PAGE_SIZE_OPTIONS}
          value={String(pageSize)}
          onChange={(value) => onPageSizeChange(Number(value))}
          w={140}
          size="sm"
        />
      </Group>
    </Group>
  )

  return (
    <Stack gap="lg">
      {/* Search Input - Full Width in Card */}
      <Card shadow="sm" padding="md" radius="md" withBorder>
        <Stack gap="sm">
          {searchTitle && <Title order={5}>{searchTitle}</Title>}
          <TextInput
            placeholder={searchPlaceholder}
            leftSection={<IconSearch size={16} />}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.currentTarget.value)}
            style={{ flex: 1, width: '100%' }}
          />
        </Stack>
      </Card>

      {/* Active Section */}
      <div>
        <Title order={5} mb="sm">
          {activeSection.title} ({activeItems.length})
        </Title>
        <Card shadow="sm" padding="md" radius="md" withBorder>
          {paginatedActiveItems.length === 0 ? (
            <Text c="dimmed" ta="center">
              {activeSection.emptyText}
            </Text>
          ) : (
            activeSection.render(paginatedActiveItems, activePaginationInfo)
          )}
          {activeItems.length > 0 &&
            renderPaginationControls(
              activePaginationInfo,
              activePageSize,
              setActivePage,
              (size) => {
                setActivePageSize(size)
                setActivePage(1)
              }
            )}
        </Card>
      </div>

      {/* Inactive Section */}
      <div>
        <Title order={5} mb="sm">
          {inactiveSection.title} ({inactiveItems.length})
        </Title>
        <Card shadow="sm" padding="md" radius="md" withBorder>
          {paginatedInactiveItems.length === 0 ? (
            <Text c="dimmed" ta="center">
              {inactiveSection.emptyText}
            </Text>
          ) : (
            inactiveSection.render(paginatedInactiveItems, inactivePaginationInfo)
          )}
          {inactiveItems.length > 0 &&
            renderPaginationControls(
              inactivePaginationInfo,
              inactivePageSize,
              setInactivePage,
              (size) => {
                setInactivePageSize(size)
                setInactivePage(1)
              }
            )}
        </Card>
      </div>
    </Stack>
  )
}
