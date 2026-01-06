import { Card, Title, Table, Badge, ScrollArea, Text, Skeleton, Stack } from '@mantine/core'
import { aggregateAdminContributions } from '@/lib/chartUtils'

interface TopContributorsProps {
  logs: any[]
  loading?: boolean
}

export function TopContributors({ logs, loading }: TopContributorsProps) {
  if (loading) {
    return (
      <Card shadow="sm" padding="lg" radius="md" withBorder style={{ height: '100%' }}>
        <Title order={4} mb="md">Kontributor Teratas</Title>
        <Stack>
          {[1, 2, 3, 4, 5].map(i => <Skeleton key={i} height={40} radius="sm" />)}
        </Stack>
      </Card>
    )
  }

  const contributions = aggregateAdminContributions(logs)

  const rows = contributions.slice(0, 8).map((contrib, index) => (
    <Table.Tr key={contrib.email}>
      <Table.Td>
        <div>
          <Text size="xs" c="dimmed">{contrib.email}</Text>
        </div>
      </Table.Td>
      <Table.Td align="right"><Text size="sm" c="green">{contrib.creates}</Text></Table.Td>
      <Table.Td align="right"><Text size="sm" c="blue">{contrib.updates}</Text></Table.Td>
      <Table.Td align="right"><Text size="sm" c="red">{contrib.deletes}</Text></Table.Td>
      <Table.Td align="right">
        <Badge
          variant="light"
          color={index === 0 ? 'yellow' : index === 1 ? 'gray' : index === 2 ? 'orange' : 'blue'}
        >
          {contrib.total}
        </Badge>
      </Table.Td>
    </Table.Tr>
  ))

  return (
    <Card shadow="sm" padding="lg" radius="md" withBorder style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <Title order={4} mb="md">Kontributor Teratas</Title>

      <ScrollArea h={400}>
        <Table verticalSpacing="sm">
          <Table.Thead>
            <Table.Tr>
              <Table.Th>User</Table.Th>
              <Table.Th style={{ textAlign: 'right', fontWeight: 'normal' }}>Tambah</Table.Th>
              <Table.Th style={{ textAlign: 'right', fontWeight: 'normal' }}>Ubah</Table.Th>
              <Table.Th style={{ textAlign: 'right', fontWeight: 'normal' }}>Hapus</Table.Th>
              <Table.Th style={{ textAlign: 'right', fontWeight: 'bold' }}>Total</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>{rows}</Table.Tbody>
        </Table>
      </ScrollArea>
    </Card>
  )
}
