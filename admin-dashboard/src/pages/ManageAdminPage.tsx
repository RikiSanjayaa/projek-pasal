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
import { IconCopy, IconDevices, IconLogout, IconRefresh, IconUserCheck, IconUserOff, IconUserPlus } from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '@/contexts/AuthContext'
import { IconAction } from '@/components/IconAction'
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
  const [selectedAdminId, setSelectedAdminId] = useState<string | null>(null)
  const [devicesOpen, devicesModal] = useDisclosure(false)
  const [addOpen, addModal] = useDisclosure(false)

  const { data: admins = [], isLoading } = useQuery({
    queryKey: ['admin_users'],
    queryFn: async () => {
      const response = await api.get<PaginatedResponse<AdminUser>>('/admin/admin-users?per_page=500')
      return response.data
    },
    enabled: adminUser?.role === 'super_admin',
  })

  const selectedAdmin = admins.find((admin) => admin.id === selectedAdminId)

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
      addModal.close()
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
        <Title order={3}>Akses ditolak</Title>
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
        <Table.Td><Badge color={admin.role === 'super_admin' ? 'teal' : 'blue'} variant="light">{admin.role === 'super_admin' ? 'Super admin' : 'Admin'}</Badge></Table.Td>
        <Table.Td><Badge color={admin.is_active ? 'green' : 'gray'} variant="light">{admin.is_active ? 'Aktif' : 'Nonaktif'}</Badge></Table.Td>
        <Table.Td>
          <Tooltip label="Lihat perangkat mobile">
            <Badge
              color={activeDevices ? 'blue' : 'gray'}
              variant="light"
              leftSection={<IconDevices size={12} />}
              style={{ cursor: 'pointer' }}
              onClick={() => {
                setSelectedAdminId(admin.id)
                devicesModal.open()
              }}
            >
              {activeDevices} aktif
            </Badge>
          </Tooltip>
        </Table.Td>
        <Table.Td w={1}>
          {allowToggle && (
            <IconAction
              label={admin.is_active ? 'Nonaktifkan' : 'Aktifkan'}
              icon={admin.is_active ? <IconUserOff size={18} /> : <IconUserCheck size={18} />}
              color={admin.is_active ? 'orange' : 'green'}
              onClick={() => toggleMutation.mutate({ id: admin.id, active: !admin.is_active })}
              loading={toggleMutation.isPending && toggleMutation.variables?.id === admin.id}
            />
          )}
        </Table.Td>
      </Table.Tr>
    )
  })

  const renderTable = (items: AdminUser[], allowToggle: boolean) => (
    <Table striped highlightOnHover miw={760} verticalSpacing="xs">
      <Table.Thead>
        <Table.Tr>
          <Table.Th>Nama</Table.Th>
          <Table.Th>Email</Table.Th>
          <Table.Th>Role</Table.Th>
          <Table.Th>Status</Table.Th>
          <Table.Th>Perangkat mobile</Table.Th>
          <Table.Th>Aksi</Table.Th>
        </Table.Tr>
      </Table.Thead>
      <Table.Tbody>{renderRows(items, allowToggle)}</Table.Tbody>
    </Table>
  )

  return (
    <Stack gap="lg">
      <Group justify="space-between" wrap="wrap">
        <div>
          <Title order={2}>Akun Admin</Title>
          <Text c="dimmed">Akun untuk dashboard dan aplikasi mobile. Akses mobile tanpa kedaluwarsa akun, maksimal 3 perangkat aktif.</Text>
        </div>
        <Button leftSection={<IconUserPlus size={16} />} onClick={addModal.open} fullWidth={isMobile}>
          Tambah Admin
        </Button>
      </Group>

      <SearchablePaginatedList
        data={admins}
        isLoading={isLoading}
        getSearchableText={(admin) => `${admin.nama} ${admin.email} ${admin.role}`}
        isActive={(admin) => admin.role === 'super_admin'}
        toolbarActions={
          <IconAction label="Muat ulang" icon={<IconRefresh size={18} />} onClick={() => queryClient.invalidateQueries({ queryKey: ['admin_users'] })} />
        }
        activeSection={{
          title: 'Super admin',
          emptyText: 'Tidak ada super admin.',
          render: (items) => renderTable(items, false),
        }}
        inactiveSection={{
          title: 'Admin',
          emptyText: 'Tidak ada admin.',
          render: (items) => renderTable(items, true),
        }}
      />

      <Modal opened={addOpen} onClose={addModal.close} title="Tambah admin baru" fullScreen={isMobile}>
        <Stack>
          <TextInput label="Email" required value={email} onChange={(event) => setEmail(event.currentTarget.value)} />
          <TextInput label="Nama" required value={nama} onChange={(event) => setNama(event.currentTarget.value)} />
          <PasswordInput label="Password awal" description="Kosongkan untuk dibuatkan otomatis" value={password} onChange={(event) => setPassword(event.currentTarget.value)} />
          <Group justify="flex-end">
            <Button onClick={() => createMutation.mutate()} loading={createMutation.isPending} disabled={!email || !nama}>
              Tambah Admin
            </Button>
          </Group>
        </Stack>
      </Modal>

      <Modal opened={!!credentials} onClose={() => setCredentials(null)} title="Kredensial Sementara" closeOnClickOutside={false} fullScreen={isMobile}>
        {credentials && (
          <Stack>
            <Alert color="yellow">Password hanya ditampilkan sekali. Simpan sebelum menutup modal.</Alert>
            <Group justify="space-between"><Text>{credentials.email}</Text><CopyButton value={credentials.email}>{({ copy }) => <ActionIcon onClick={copy}><IconCopy size={16} /></ActionIcon>}</CopyButton></Group>
            <Group justify="space-between"><Text ff="monospace">{credentials.password}</Text><CopyButton value={credentials.password}>{({ copy }) => <ActionIcon onClick={copy}><IconCopy size={16} /></ActionIcon>}</CopyButton></Group>
          </Stack>
        )}
      </Modal>

      <Modal opened={devicesOpen} onClose={devicesModal.close} title={`Perangkat mobile - ${selectedAdmin?.nama}`} size="lg" fullScreen={isMobile}>
        <Text size="sm" c="dimmed" mb="md">
          Sesi mobile hanya untuk membaca, tidak memberi akses API dashboard. Paksa keluar mencabut sesi perangkat ini; saat offline, akses lokal berhenti paling lambat setelah 30 hari tanpa verifikasi server.
        </Text>
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
                    <IconAction
                      label="Paksa keluar dari perangkat ini"
                      icon={<IconLogout size={18} />}
                      color="red"
                      loading={deviceMutation.isPending && deviceMutation.variables?.deviceId === device.id}
                      onClick={() => selectedAdmin && deviceMutation.mutate({ adminId: selectedAdmin.id, deviceId: device.id })}
                    />
                  )}
                </Table.Td>
              </Table.Tr>
            ))}
            {!selectedAdmin?.devices?.length && (
              <Table.Tr><Table.Td colSpan={4}><Text c="dimmed" ta="center">Belum ada perangkat mobile terdaftar.</Text></Table.Td></Table.Tr>
            )}
          </Table.Tbody>
        </Table>
        </ScrollArea>
      </Modal>
    </Stack>
  )
}
