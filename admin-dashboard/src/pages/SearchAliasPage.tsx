import { useMemo, useState } from 'react'
import {
  ActionIcon,
  Alert,
  Badge,
  Button,
  Card,
  Group,
  Modal,
  Stack,
  Switch,
  Table,
  TagsInput,
  Text,
  TextInput,
  Title,
  Tooltip,
} from '@mantine/core'
import { useDisclosure, useMediaQuery } from '@mantine/hooks'
import { notifications } from '@mantine/notifications'
import { IconEdit, IconPlus, IconRefresh, IconSearch, IconTrash } from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '@/contexts/AuthContext'
import { api, type PaginatedResponse } from '@/lib/api'

interface SearchAlias {
  id: string
  term: string
  aliases: string[]
  category: string | null
  notes: string | null
  is_active: boolean
  created_at: string
  updated_at: string
}

const emptyForm = {
  term: '',
  aliases: [] as string[],
  category: '',
  notes: '',
  is_active: true,
}

function normalizeSearchText(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function SearchAliasPage() {
  const { adminUser } = useAuth()
  const queryClient = useQueryClient()
  const isMobile = useMediaQuery('(max-width: 48em)')
  const [search, setSearch] = useState('')
  const [form, setForm] = useState(emptyForm)
  const [editing, setEditing] = useState<SearchAlias | null>(null)
  const [deleting, setDeleting] = useState<SearchAlias | null>(null)
  const [formOpened, formModal] = useDisclosure(false)

  const { data: aliases = [], isLoading } = useQuery({
    queryKey: ['search_aliases'],
    queryFn: async () => {
      const response = await api.get<PaginatedResponse<SearchAlias>>('/admin/search-aliases?per_page=500')
      return response.data
    },
    enabled: adminUser?.role === 'super_admin',
  })

  const filteredAliases = useMemo(() => {
    const q = normalizeSearchText(search)
    if (!q) return aliases

    return aliases.filter((item) =>
      normalizeSearchText([item.term, item.category || '', item.notes || '', item.aliases.join(' ')].join(' ')).includes(q)
    )
  }, [aliases, search])

  const saveMutation = useMutation({
    mutationFn: async () => {
      const payload = {
        ...form,
        term: normalizeSearchText(form.term),
        aliases: form.aliases.map(normalizeSearchText).filter(Boolean),
        category: form.category.trim() || null,
        notes: form.notes.trim() || null,
      }

      if (editing) {
        return api.put<SearchAlias>(`/admin/search-aliases/${editing.id}`, payload)
      }

      return api.post<SearchAlias>('/admin/search-aliases', payload)
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['search_aliases'] })
      setForm(emptyForm)
      setEditing(null)
      formModal.close()
      notifications.show({ title: 'Berhasil', message: 'Alias pencarian tersimpan', color: 'green' })
    },
    onError: (error: Error) => notifications.show({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => api.delete(`/admin/search-aliases/${id}`),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['search_aliases'] })
      setDeleting(null)
      notifications.show({ title: 'Berhasil', message: 'Alias pencarian dihapus', color: 'green' })
    },
    onError: (error: Error) => notifications.show({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const openCreate = () => {
    setEditing(null)
    setForm(emptyForm)
    formModal.open()
  }

  const openEdit = (alias: SearchAlias) => {
    setEditing(alias)
    setForm({
      term: alias.term,
      aliases: alias.aliases || [],
      category: alias.category || '',
      notes: alias.notes || '',
      is_active: alias.is_active,
    })
    formModal.open()
  }

  if (adminUser?.role !== 'super_admin') {
    return (
      <Card withBorder>
        <Title order={3}>Akses ditolak</Title>
        <Text>Halaman ini hanya untuk super admin.</Text>
      </Card>
    )
  }

  return (
    <Stack gap="lg">
      <Group justify="space-between" wrap="wrap">
        <div>
          <Title order={2}>Smart Search</Title>
          <Text c="dimmed">Kelola kata pencarian agar user tetap menemukan pasal meski memakai istilah sehari-hari.</Text>
        </div>
        <Group gap="sm" w={isMobile ? '100%' : 'auto'}>
          <Button
            variant="light"
            leftSection={<IconRefresh size={16} />}
            onClick={() => queryClient.invalidateQueries({ queryKey: ['search_aliases'] })}
            fullWidth={isMobile}
          >
            Refresh
          </Button>
          <Button leftSection={<IconPlus size={16} />} onClick={openCreate} fullWidth={isMobile}>
            Tambah Alias
          </Button>
        </Group>
      </Group>

      <Alert color="blue" variant="light">
        Contoh: kata pencarian <strong>maling</strong> diarahkan ke <strong>pencurian</strong>, <strong>mencuri</strong>, dan <strong>mengambil barang</strong>.
      </Alert>

      <Card withBorder padding="md">
        <TextInput
          value={search}
          onChange={(event) => setSearch(event.currentTarget.value)}
          leftSection={<IconSearch size={16} />}
          placeholder="Cari alias, kata target, atau kategori..."
        />
      </Card>

      <Card withBorder padding="md">
        <Table striped highlightOnHover miw={850}>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>Kata pencarian</Table.Th>
              <Table.Th>Kata target</Table.Th>
              <Table.Th>Kategori</Table.Th>
              <Table.Th>Status</Table.Th>
              <Table.Th>Aksi</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {filteredAliases.map((alias) => (
              <Table.Tr key={alias.id}>
                <Table.Td>
                  <Text fw={700}>{alias.term}</Text>
                  {alias.notes && <Text size="xs" c="dimmed" lineClamp={1}>{alias.notes}</Text>}
                </Table.Td>
                <Table.Td>
                  <Group gap={6}>
                    {alias.aliases.map((item) => (
                      <Badge key={item} variant="light">{item}</Badge>
                    ))}
                  </Group>
                </Table.Td>
                <Table.Td>{alias.category || '-'}</Table.Td>
                <Table.Td>
                  <Badge color={alias.is_active ? 'green' : 'gray'} variant="light">
                    {alias.is_active ? 'Aktif' : 'Nonaktif'}
                  </Badge>
                </Table.Td>
                <Table.Td>
                  <Group gap={4}>
                    <Tooltip label="Edit">
                      <ActionIcon variant="subtle" onClick={() => openEdit(alias)}>
                        <IconEdit size={16} />
                      </ActionIcon>
                    </Tooltip>
                    <Tooltip label="Hapus">
                      <ActionIcon variant="subtle" color="red" onClick={() => setDeleting(alias)}>
                        <IconTrash size={16} />
                      </ActionIcon>
                    </Tooltip>
                  </Group>
                </Table.Td>
              </Table.Tr>
            ))}
            {!isLoading && filteredAliases.length === 0 && (
              <Table.Tr>
                <Table.Td colSpan={5}>
                  <Text ta="center" c="dimmed" py="lg">Belum ada alias pencarian.</Text>
                </Table.Td>
              </Table.Tr>
            )}
          </Table.Tbody>
        </Table>
      </Card>

      <Modal
        opened={formOpened}
        onClose={formModal.close}
        title={editing ? 'Edit Alias Pencarian' : 'Tambah Alias Pencarian'}
        size="lg"
        fullScreen={isMobile}
      >
        <Stack>
          <TextInput
            label="Kata yang diketik user"
            placeholder="Contoh: maling"
            value={form.term}
            onChange={(event) => setForm((current) => ({ ...current, term: event.currentTarget.value }))}
            required
          />
          <TagsInput
            label="Arahkan ke kata hukum"
            placeholder="Ketik lalu Enter, contoh: pencurian"
            value={form.aliases}
            onChange={(aliases) => setForm((current) => ({ ...current, aliases }))}
            required
          />
          <TextInput
            label="Kategori"
            placeholder="Contoh: Pidana umum"
            value={form.category}
            onChange={(event) => setForm((current) => ({ ...current, category: event.currentTarget.value }))}
          />
          <TextInput
            label="Catatan"
            placeholder="Opsional"
            value={form.notes}
            onChange={(event) => setForm((current) => ({ ...current, notes: event.currentTarget.value }))}
          />
          <Switch
            label="Aktif"
            checked={form.is_active}
            onChange={(event) => setForm((current) => ({ ...current, is_active: event.currentTarget.checked }))}
          />
          <Group justify="flex-end">
            <Button variant="default" onClick={formModal.close}>Batal</Button>
            <Button
              onClick={() => saveMutation.mutate()}
              loading={saveMutation.isPending}
              disabled={!form.term.trim() || form.aliases.length === 0}
            >
              Simpan
            </Button>
          </Group>
        </Stack>
      </Modal>

      <Modal opened={!!deleting} onClose={() => setDeleting(null)} title="Hapus Alias" centered>
        <Text mb="lg">
          Hapus alias <strong>{deleting?.term}</strong>?
        </Text>
        <Group justify="flex-end">
          <Button variant="default" onClick={() => setDeleting(null)}>Batal</Button>
          <Button color="red" loading={deleteMutation.isPending} onClick={() => deleting && deleteMutation.mutate(deleting.id)}>
            Hapus
          </Button>
        </Group>
      </Modal>
    </Stack>
  )
}
