import { useState } from 'react'
import {
  ActionIcon,
  Alert,
  Badge,
  Button,
  Card,
  CopyButton,
  Group,
  Modal,
  PasswordInput,
  ScrollArea,
  Stack,
  Table,
  Text,
  TextInput,
  Title,
  Tooltip,
} from '@mantine/core'
import { useDisclosure, useMediaQuery } from '@mantine/hooks'
import { showNotification } from '@mantine/notifications'
import { IconCopy, IconDevices, IconRefresh } from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '@/contexts/AuthContext'
import { SearchablePaginatedList } from '@/components/SearchablePaginatedList'
import { api, type PaginatedResponse } from '@/lib/api'
import { invalidateAdminData } from '@/lib/query-invalidation'

interface AdminDevice {
  id: string
  device_id: string
  device_name: string | null
  is_active: boolean
  last_active_at: string
}

interface AdminUser {
  id: string
  email: string
  nama: string
  role: 'admin' | 'super_admin'
  is_active: boolean
  devices?: AdminDevice[]
}

function formatDate(dateStr?: string | null) {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function ManageAdminPage() {
  const { adminUser } = useAuth()
  const queryClient = useQueryClient()
  const isMobile = useMediaQuery('(max-width: 48em)')
  const [email, setEmail] = useState('')
  const [nama, setNama] = useState('')
  const [password, setPassword] = useState('')
  const [credentials, setCredentials] = useState<{ email: string; password: string } | null>(null)
  const [selectedAdmin, setSelectedAdmin] = useState<AdminUser | null>(null)
  const [devicesOpen, devicesModal] = useDisclosure(false)

  const { data: admins = [], isLoading } = useQuery({
    queryKey: ['admin_users'],
    queryFn: async () => {
      const response = await api.get<PaginatedResponse<AdminUser>>('/admin/admin-users?per_page=500')
      return response.data
    },
    enabled: adminUser?.role === 'super_admin',
  })

  const createMutation = useMutation({
    mutationFn: async () => {
      return api.post<AdminUser & { temporary_password?: string }>('/admin/admin-users', {
        email,
        nama,
        password: password || undefined,
        role: 'admin',
      })
    },
    onSuccess: async (admin) => {
      await invalidateAdminData(queryClient)
      setCredentials({ email: admin.email, password: admin.temporary_password || password })
      setEmail('')
      setNama('')
      setPassword('')
      showNotification({ title: 'Berhasil', message: 'Admin berhasil dibuat', color: 'green' })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const toggleMutation = useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) =>
      api.patch(`/admin/admin-users/${id}/${active ? 'activate' : 'deactivate'}`),
    onSuccess: async () => {
      await invalidateAdminData(queryClient)
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const deviceMutation = useMutation({
    mutationFn: ({ adminId, deviceId }: { adminId: string; deviceId: string }) =>
      api.delete(`/admin/admin-users/${adminId}/devices/${deviceId}`),
    onSuccess: async () => {
      await invalidateAdminData(queryClient)
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  if (adminUser?.role !== 'super_admin') {
    return (
      <Card>
        <Title order={3}>Access denied</Title>
        <Text>Halaman ini hanya untuk super admin.</Text>
      </Card>
    )
  }

  const renderRows = (items: AdminUser[], allowToggle: boolean) => items.map((admin) => {
    const activeDevices = admin.devices?.filter((device) => device.is_active).length || 0
    return (
      <Table.Tr key={admin.id}>
        <Table.Td><Text fw={600}>{admin.nama}</Text></Table.Td>
        <Table.Td>{admin.email}</Table.Td>
        <Table.Td><Badge color={admin.role === 'super_admin' ? 'teal' : 'blue'}>{admin.role}</Badge></Table.Td>
        <Table.Td><Badge color={admin.is_active ? 'green' : 'gray'} variant="light">{admin.is_active ? 'Aktif' : 'Nonaktif'}</Badge></Table.Td>
        <Table.Td>
          <Tooltip label="Lihat perangkat">
            <Badge
              color={activeDevices ? 'blue' : 'gray'}
              variant="light"
              leftSection={<IconDevices size={12} />}
              style={{ cursor: 'pointer' }}
              onClick={() => {
                setSelectedAdmin(admin)
                devicesModal.open()
              }}
            >
              {activeDevices} aktif
            </Badge>
          </Tooltip>
        </Table.Td>
        <Table.Td>
          {allowToggle && (
            <Button
              size="xs"
              variant="light"
              color={admin.is_active ? 'orange' : 'green'}
              onClick={() => toggleMutation.mutate({ id: admin.id, active: !admin.is_active })}
              loading={toggleMutation.isPending}
            >
              {admin.is_active ? 'Nonaktifkan' : 'Aktifkan'}
            </Button>
          )}
        </Table.Td>
      </Table.Tr>
    )
  })

  return (
    <Stack gap="lg">
      <Group justify="space-between" wrap="wrap">
        <div>
          <Title order={2}>Manage Admin</Title>
          <Text c="dimmed">Kelola akun admin dashboard</Text>
        </div>
        <Button leftSection={<IconRefresh size={16} />} variant="light" onClick={() => queryClient.invalidateQueries({ queryKey: ['admin_users'] })} fullWidth={isMobile}>
          Refresh
        </Button>
      </Group>

      <Alert title="Tambah admin baru" color="blue" variant="light">
        <Group align="flex-end" grow={isMobile}>
          <TextInput label="Email" value={email} onChange={(event) => setEmail(event.currentTarget.value)} style={{ flex: 1, minWidth: isMobile ? '100%' : 0 }} />
          <TextInput label="Nama" value={nama} onChange={(event) => setNama(event.currentTarget.value)} style={{ flex: 1, minWidth: isMobile ? '100%' : 0 }} />
          <PasswordInput label="Password awal" placeholder="Kosongkan untuk auto-generate" value={password} onChange={(event) => setPassword(event.currentTarget.value)} style={{ flex: 1, minWidth: isMobile ? '100%' : 0 }} />
          <Button onClick={() => createMutation.mutate()} loading={createMutation.isPending} disabled={!email || !nama} fullWidth={isMobile} style={{ minWidth: isMobile ? '100%' : undefined }}>
            Tambah Admin
          </Button>
        </Group>
      </Alert>

      <SearchablePaginatedList
        data={admins}
        isLoading={isLoading}
        searchTitle="Cari admin"
        getSearchableText={(admin) => `${admin.nama} ${admin.email} ${admin.role}`}
        isActive={(admin) => admin.role === 'super_admin'}
        activeSection={{
          title: 'Super Admin',
          emptyText: 'Tidak ada super admin.',
          render: (items) => (
            <Table striped highlightOnHover miw={820}>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Nama</Table.Th>
                  <Table.Th>Email</Table.Th>
                  <Table.Th>Role</Table.Th>
                  <Table.Th>Status</Table.Th>
                  <Table.Th>Perangkat</Table.Th>
                  <Table.Th>Aksi</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>{renderRows(items, false)}</Table.Tbody>
            </Table>
          ),
        }}
        inactiveSection={{
          title: 'Admin',
          emptyText: 'Tidak ada admin.',
          render: (items) => (
            <Table striped highlightOnHover miw={820}>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Nama</Table.Th>
                  <Table.Th>Email</Table.Th>
                  <Table.Th>Role</Table.Th>
                  <Table.Th>Status</Table.Th>
                  <Table.Th>Perangkat</Table.Th>
                  <Table.Th>Aksi</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>{renderRows(items, true)}</Table.Tbody>
            </Table>
          ),
        }}
      />

      <Modal opened={!!credentials} onClose={() => setCredentials(null)} title="Kredensial Sementara" closeOnClickOutside={false} fullScreen={isMobile}>
        {credentials && (
          <Stack>
            <Alert color="yellow">Password hanya ditampilkan sekali. Simpan sebelum menutup modal.</Alert>
            <Group justify="space-between"><Text>{credentials.email}</Text><CopyButton value={credentials.email}>{({ copy }) => <ActionIcon onClick={copy}><IconCopy size={16} /></ActionIcon>}</CopyButton></Group>
            <Group justify="space-between"><Text ff="monospace">{credentials.password}</Text><CopyButton value={credentials.password}>{({ copy }) => <ActionIcon onClick={copy}><IconCopy size={16} /></ActionIcon>}</CopyButton></Group>
          </Stack>
        )}
      </Modal>

      <Modal opened={devicesOpen} onClose={devicesModal.close} title={`Perangkat - ${selectedAdmin?.nama}`} size="lg" fullScreen={isMobile}>
        <ScrollArea>
        <Table striped miw={560}>
          <Table.Thead><Table.Tr><Table.Th>Device</Table.Th><Table.Th>Terakhir Aktif</Table.Th><Table.Th>Status</Table.Th><Table.Th>Aksi</Table.Th></Table.Tr></Table.Thead>
          <Table.Tbody>
            {selectedAdmin?.devices?.map((device) => (
              <Table.Tr key={device.id}>
                <Table.Td>{device.device_name || device.device_id}</Table.Td>
                <Table.Td>{formatDate(device.last_active_at)}</Table.Td>
                <Table.Td><Badge color={device.is_active ? 'green' : 'gray'}>{device.is_active ? 'Aktif' : 'Nonaktif'}</Badge></Table.Td>
                <Table.Td>
                  {device.is_active && (
                    <Button size="xs" color="red" variant="light" onClick={() => selectedAdmin && deviceMutation.mutate({ adminId: selectedAdmin.id, deviceId: device.id })}>
                      Force Logout
                    </Button>
                  )}
                </Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
        </ScrollArea>
      </Modal>
    </Stack>
  )
}
