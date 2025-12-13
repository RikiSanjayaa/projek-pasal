import { ReactNode } from 'react'
import {
  Table,
  Checkbox,
  Text,
  Group,
  Pagination,
  Select,
  Skeleton,
  Stack,
} from '@mantine/core'

export interface Column<T> {
  key: string
  title: string
  width?: number | string
  render?: (value: any, record: T, index: number) => ReactNode
  sortable?: boolean
}

export interface DataTableProps<T> {
  columns: Column<T>[]
  data: T[]
  loading?: boolean
  // Pagination
  current: number
  pageSize: number
  total: number
  pageSizeOptions?: { value: string; label: string }[]
  onPageChange: (page: number) => void
  onPageSizeChange: (pageSize: number) => void
  // Selection
  selectable?: boolean
  selectedIds?: string[]
  onSelect?: (ids: string[]) => void
  getRowId?: (record: T) => string
  // Row actions
  onRowClick?: (record: T) => void
  rowActions?: (record: T) => ReactNode
  // Empty state
  emptyText?: string
  // Loading skeleton count
  skeletonCount?: number
}

const PAGE_SIZE_OPTIONS = [
  { value: '5', label: '5 per halaman' },
  { value: '10', label: '10 per halaman' },
  { value: '15', label: '15 per halaman' },
  { value: '20', label: '20 per halaman' },
  { value: '30', label: '30 per halaman' },
]

export function DataTable<T extends Record<string, any>>({
  columns,
  data,
  loading = false,
  current,
  pageSize,
  total,
  pageSizeOptions = PAGE_SIZE_OPTIONS,
  onPageChange,
  onPageSizeChange,
  selectable = false,
  selectedIds = [],
  onSelect,
  getRowId = (record) => record.id,
  onRowClick,
  rowActions,
  emptyText = 'Tidak ada data',
  skeletonCount = 5,
}: DataTableProps<T>) {
  const totalPages = Math.ceil(total / pageSize)

  const handleSelectAll = (checked: boolean) => {
    if (!onSelect) return
    if (checked) {
      onSelect(data.map(getRowId))
    } else {
      onSelect([])
    }
  }

  const handleSelect = (id: string, checked: boolean) => {
    if (!onSelect) return
    if (checked) {
      onSelect([...selectedIds, id])
    } else {
      onSelect(selectedIds.filter(selectedId => selectedId !== id))
    }
  }

  const renderCell = (column: Column<T>, record: T, index: number) => {
    if (column.render) {
      return column.render(record[column.key], record, index)
    }

    const value = record[column.key]
    if (typeof value === 'string' || typeof value === 'number') {
      return <Text>{value}</Text>
    }

    return <Text>-</Text>
  }

  if (loading) {
    return (
      <Stack gap="sm">
        {[...Array(skeletonCount)].map((_, i) => (
          <Skeleton key={i} height={50} />
        ))}
      </Stack>
    )
  }

  return (
    <>
      <Table striped highlightOnHover>
        <Table.Thead>
          <Table.Tr>
            {selectable && (
              <Table.Th w={40}>
                <Checkbox
                  checked={selectedIds.length === data.length && data.length > 0}
                  indeterminate={selectedIds.length > 0 && selectedIds.length < data.length}
                  onChange={(e) => handleSelectAll(e.currentTarget.checked)}
                />
              </Table.Th>
            )}
            {columns.map((column) => (
              <Table.Th key={column.key} w={column.width}>
                {column.title}
              </Table.Th>
            ))}
            {rowActions && <Table.Th w={80}>Aksi</Table.Th>}
          </Table.Tr>
        </Table.Thead>
        <Table.Tbody>
          {data.map((record, index) => {
            const id = getRowId(record)
            return (
              <Table.Tr
                key={id}
                style={{ cursor: onRowClick ? 'pointer' : 'default' }}
                onClick={() => onRowClick?.(record)}
                bg={selectedIds.includes(id) ? 'var(--mantine-color-blue-light)' : undefined}
              >
                {selectable && (
                  <Table.Td onClick={(e) => e.stopPropagation()}>
                    <Checkbox
                      checked={selectedIds.includes(id)}
                      onChange={(e) => handleSelect(id, e.currentTarget.checked)}
                    />
                  </Table.Td>
                )}
                {columns.map((column) => (
                  <Table.Td key={column.key}>
                    {renderCell(column, record, index)}
                  </Table.Td>
                ))}
                {rowActions && (
                  <Table.Td onClick={(e) => e.stopPropagation()}>
                    {rowActions(record)}
                  </Table.Td>
                )}
              </Table.Tr>
            )
          })}
        </Table.Tbody>
      </Table>

      {data.length === 0 && (
        <Text c="dimmed" ta="center" py="xl">
          {emptyText}
        </Text>
      )}

      <Group justify="space-between" mt="md">
        <Group gap="xs">
          <Text size="sm" c="dimmed">
            Total: {total} data
          </Text>
        </Group>
        <Group gap="md">
          {totalPages > 1 && (
            <Pagination
              value={current}
              onChange={onPageChange}
              total={totalPages}
            />
          )}
          <Select
            comboboxProps={{ withinPortal: true }}
            data={pageSizeOptions}
            value={String(pageSize)}
            onChange={(value) => onPageSizeChange(Number(value))}
            w={150}
            size="sm"
          />
        </Group>
      </Group>
    </>
  )
}