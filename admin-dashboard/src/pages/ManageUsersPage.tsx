import { useMemo, useState } from 'react'
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
import { Dropzone } from '@mantine/dropzone'
import { useDisclosure, useMediaQuery } from '@mantine/hooks'
import { showNotification } from '@mantine/notifications'
import { IconCheck, IconCopy, IconDevices, IconFileSpreadsheet, IconRefresh, IconTrash, IconUpload, IconX } from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as XLSX from 'xlsx'
import { api, type PaginatedResponse } from '@/lib/api'

interface UserDevice {
  id: string
  device_id: string
  device_name: string | null
  platform: string | null
  is_active: boolean
  last_active_at: string
}

interface MobileUser {
  id: string
  email: string
  nama: string
  is_active: boolean
  expires_at: string
  created_at: string
  devices?: UserDevice[]
}

function formatDate(dateStr?: string | null) {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })
}

function daysUntilExpiry(expiresAt: string) {
  return Math.ceil((new Date(expiresAt).getTime() - Date.now()) / (1000 * 60 * 60 * 24))
}

function ExpiryBadge({ expiresAt }: { expiresAt: string }) {
  const days = daysUntilExpiry(expiresAt)
  if (days < 0) return <Badge color="red">Kadaluarsa</Badge>
  if (days <= 30) return <Badge color="yellow">{days} hari lagi</Badge>
  return <Badge color="green" variant="light">{formatDate(expiresAt)}</Badge>
}

export function ManageUsersPage() {
  const queryClient = useQueryClient()
  const isMobile = useMediaQuery('(max-width: 48em)')
  const [email, setEmail] = useState('')
  const [nama, setNama] = useState('')
  const [password, setPassword] = useState('')
  const [credentials, setCredentials] = useState<{ email: string; password: string; expires_at: string } | null>(null)
  const [selectedUser, setSelectedUser] = useState<MobileUser | null>(null)
  const [devicesOpen, devicesModal] = useDisclosure(false)

  const { data: users = [], isLoading } = useQuery({
    queryKey: ['mobile_users'],
    queryFn: async () => {
      const response = await api.get<PaginatedResponse<MobileUser>>('/admin/mobile-users?per_page=500')
      return response.data
    },
  })

  const createMutation = useMutation({
    mutationFn: async () => {
      return api.post<MobileUser & { temporary_password?: string }>('/admin/mobile-users', {
        email,
        nama,
        password: password || undefined,
      })
    },
    onSuccess: (user) => {
      queryClient.invalidateQueries({ queryKey: ['mobile_users'] })
      setCredentials({ email: user.email, password: user.temporary_password || password, expires_at: user.expires_at })
      setEmail('')
      setNama('')
      setPassword('')
      showNotification({ title: 'Berhasil', message: 'Pengguna berhasil dibuat', color: 'green' })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const toggleMutation = useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) =>
      api.patch(`/admin/mobile-users/${id}/${active ? 'activate' : 'deactivate'}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['mobile_users'] }),
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const extendMutation = useMutation({
    mutationFn: (id: string) => api.patch(`/admin/mobile-users/${id}/extend`, { years: 3 }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mobile_users'] })
      showNotification({ title: 'Berhasil', message: 'Masa aktif diperpanjang 3 tahun', color: 'green' })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const resetPasswordMutation = useMutation({
    mutationFn: (id: string) => api.patch<MobileUser & { temporary_password: string }>(`/admin/mobile-users/${id}/password`),
    onSuccess: (user) => {
      queryClient.invalidateQueries({ queryKey: ['mobile_users'] })
      setCredentials({ email: user.email, password: user.temporary_password, expires_at: user.expires_at })
      showNotification({ title: 'Berhasil', message: 'Password baru berhasil dibuat', color: 'green' })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/admin/mobile-users/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mobile_users'] })
      showNotification({ title: 'Berhasil', message: 'Pengguna dihapus', color: 'green' })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const deviceMutation = useMutation({
    mutationFn: ({ userId, deviceId }: { userId: string; deviceId: string }) =>
      api.delete(`/admin/mobile-users/${userId}/devices/${deviceId}`),
    onSuccess: (_, variables) => {
      setSelectedUser((user) =>
        user
          ? {
              ...user,
              devices: user.devices?.map((device) =>
                device.id === variables.deviceId ? { ...device, is_active: false } : device
              ),
            }
          : user
      )
      queryClient.invalidateQueries({ queryKey: ['mobile_users'] })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const batchMutation = useMutation({
    mutationFn: async (file: File) => {
      const buffer = await file.arrayBuffer()
      const workbook = XLSX.read(buffer, { type: 'array' })
      const rows = XLSX.utils.sheet_to_json<Record<string, string>>(workbook.Sheets[workbook.SheetNames[0]], { defval: '' })
      const users = rows.map((row, index) => {
        const email = String(row.email || '').trim()
        const nama = String(row.nama || '').trim() || email.split('@')[0]
        const password = String(row.password || '').trim()
        if (!email) throw new Error(`Baris ${index + 2}: email wajib diisi`)
        return { email, nama, password: password || undefined }
      })
      return api.post<{ created: MobileUser[]; errors: { row: number; message: string }[] }>('/admin/mobile-users/bulk-create', { users })
    },
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['mobile_users'] })
      showNotification({ title: 'Import selesai', message: `${result.created.length} berhasil, ${result.errors.length} gagal`, color: result.errors.length ? 'orange' : 'green' })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal import', message: error.message, color: 'red' }),
  })

  const activeUsers = useMemo(() => users.filter((user) => user.is_active && daysUntilExpiry(user.expires_at) >= 0), [users])
  const inactiveUsers = useMemo(() => users.filter((user) => !user.is_active || daysUntilExpiry(user.expires_at) < 0), [users])

  const renderUserActions = (user: MobileUser, includeDevices = false) => {
    const activeDevices = user.devices?.filter((device) => device.is_active).length || 0
    const isExtending = extendMutation.isPending && extendMutation.variables === user.id
    const isResettingPassword = resetPasswordMutation.isPending && resetPasswordMutation.variables === user.id
    const isToggling = toggleMutation.isPending && toggleMutation.variables?.id === user.id
    const isDeleting = deleteMutation.isPending && deleteMutation.variables === user.id

    return (
      <Group gap={4} wrap="wrap">
        <Button size="xs" variant="light" onClick={() => extendMutation.mutate(user.id)} loading={isExtending} fullWidth={isMobile}>
          Perpanjang
        </Button>
        <Button size="xs" variant="light" onClick={() => resetPasswordMutation.mutate(user.id)} loading={isResettingPassword} fullWidth={isMobile}>
          Reset Password
        </Button>
        <Button
          size="xs"
          color={user.is_active ? 'orange' : 'green'}
          variant="light"
          onClick={() => toggleMutation.mutate({ id: user.id, active: !user.is_active })}
          loading={isToggling}
          fullWidth={isMobile}
        >
          {user.is_active ? 'Nonaktifkan' : 'Aktifkan'}
        </Button>
        <ActionIcon color="red" variant="subtle" onClick={() => deleteMutation.mutate(user.id)} loading={isDeleting}>
          <IconTrash size={16} />
        </ActionIcon>
        {includeDevices && (
          <Tooltip label="Lihat perangkat">
            <Badge
              color={activeDevices ? 'blue' : 'gray'}
              variant="light"
              leftSection={<IconDevices size={12} />}
              style={{ cursor: 'pointer' }}
              onClick={() => {
                setSelectedUser(user)
                devicesModal.open()
              }}
            >
              {activeDevices} aktif
            </Badge>
          </Tooltip>
        )}
      </Group>
    )
  }

  const renderMobileCards = (items: MobileUser[]) => (
    <Stack gap="sm">
      {items.map((user) => (
        <Card key={user.id} withBorder padding="sm" radius="md">
          <Stack gap="xs">
            <div>
              <Text fw={600}>{user.nama}</Text>
              <Text size="sm" c="dimmed" style={{ overflowWrap: 'anywhere' }}>{user.email}</Text>
            </div>
            <Group gap="xs">
              <Badge color={user.is_active ? 'green' : 'gray'} variant="light">{user.is_active ? 'Aktif' : 'Nonaktif'}</Badge>
              <ExpiryBadge expiresAt={user.expires_at} />
            </Group>
            {renderUserActions(user, true)}
          </Stack>
        </Card>
      ))}
    </Stack>
  )

  const renderRows = (items: MobileUser[]) => items.map((user) => {
    const activeDevices = user.devices?.filter((device) => device.is_active).length || 0

    return (
      <Table.Tr key={user.id}>
        <Table.Td><Text fw={600}>{user.nama}</Text></Table.Td>
        <Table.Td>{user.email}</Table.Td>
        <Table.Td>
          <Badge color={user.is_active ? 'green' : 'gray'} variant="light">{user.is_active ? 'Aktif' : 'Nonaktif'}</Badge>
        </Table.Td>
        <Table.Td><ExpiryBadge expiresAt={user.expires_at} /></Table.Td>
        <Table.Td>
          <Tooltip label="Lihat perangkat">
            <Badge
              color={activeDevices ? 'blue' : 'gray'}
              variant="light"
              leftSection={<IconDevices size={12} />}
              style={{ cursor: 'pointer' }}
              onClick={() => {
                setSelectedUser(user)
                devicesModal.open()
              }}
            >
              {activeDevices} aktif
            </Badge>
          </Tooltip>
        </Table.Td>
        <Table.Td>
          {renderUserActions(user)}
        </Table.Td>
      </Table.Tr>
    )
  })

  return (
    <Stack gap="lg">
      <div>
        <Title order={2}>Manage Users</Title>
        <Text c="dimmed">Kelola akun pengguna mobile</Text>
      </div>

      <Alert title="Tambah pengguna mobile" color="blue" variant="light">
        <Group align="flex-end" grow={isMobile}>
          <TextInput label="Email" value={email} onChange={(event) => setEmail(event.currentTarget.value)} style={{ flex: 1, minWidth: isMobile ? '100%' : 0 }} />
          <TextInput label="Nama" value={nama} onChange={(event) => setNama(event.currentTarget.value)} style={{ flex: 1, minWidth: isMobile ? '100%' : 0 }} />
          <PasswordInput label="Password awal" placeholder="Kosongkan untuk auto-generate" value={password} onChange={(event) => setPassword(event.currentTarget.value)} style={{ flex: 1, minWidth: isMobile ? '100%' : 0 }} />
          <Button onClick={() => createMutation.mutate()} loading={createMutation.isPending} disabled={!email || !nama} fullWidth={isMobile} style={{ minWidth: isMobile ? '100%' : undefined }}>
            Tambah
          </Button>
        </Group>
      </Alert>

      <Dropzone
        onDrop={(files) => files[0] && batchMutation.mutate(files[0])}
        accept={{
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'],
          'application/vnd.ms-excel': ['.xls'],
        }}
        maxSize={5 * 1024 * 1024}
        multiple={false}
      >
        <Group justify="center" mih={80} style={{ pointerEvents: 'none' }}>
          <Dropzone.Accept><IconCheck size={28} /></Dropzone.Accept>
          <Dropzone.Reject><IconX size={28} /></Dropzone.Reject>
          <Dropzone.Idle><IconUpload size={28} /></Dropzone.Idle>
          <Text><IconFileSpreadsheet size={16} style={{ verticalAlign: 'middle' }} /> Import XLSX users: email, nama, password</Text>
        </Group>
      </Dropzone>

      <Card shadow="sm" padding="md" radius="md" withBorder>
        <Group justify="space-between" mb="sm" wrap="wrap">
          <Title order={4}>Pengguna Aktif</Title>
          <Button leftSection={<IconRefresh size={16} />} variant="light" onClick={() => queryClient.invalidateQueries({ queryKey: ['mobile_users'] })} fullWidth={isMobile}>
            Refresh
          </Button>
        </Group>
        {isMobile ? renderMobileCards(activeUsers) : <ScrollArea>
          <Table striped highlightOnHover miw={850}>
            <Table.Thead>
              <Table.Tr><Table.Th>Nama</Table.Th><Table.Th>Email</Table.Th><Table.Th>Status</Table.Th><Table.Th>Masa Aktif</Table.Th><Table.Th>Perangkat</Table.Th><Table.Th>Aksi</Table.Th></Table.Tr>
            </Table.Thead>
            <Table.Tbody>{isLoading ? null : renderRows(activeUsers)}</Table.Tbody>
          </Table>
        </ScrollArea>}
      </Card>

      <Card shadow="sm" padding="md" radius="md" withBorder>
        <Title order={4} mb="sm">Pengguna Nonaktif / Kadaluarsa</Title>
        {isMobile ? renderMobileCards(inactiveUsers) : <ScrollArea>
          <Table striped highlightOnHover miw={850}>
            <Table.Thead>
              <Table.Tr><Table.Th>Nama</Table.Th><Table.Th>Email</Table.Th><Table.Th>Status</Table.Th><Table.Th>Masa Aktif</Table.Th><Table.Th>Perangkat</Table.Th><Table.Th>Aksi</Table.Th></Table.Tr>
            </Table.Thead>
            <Table.Tbody>{renderRows(inactiveUsers)}</Table.Tbody>
          </Table>
        </ScrollArea>}
      </Card>

      <Modal opened={!!credentials} onClose={() => setCredentials(null)} title="Kredensial Sementara" closeOnClickOutside={false} fullScreen={isMobile}>
        {credentials && (
          <Stack>
            <Alert color="yellow">Password hanya ditampilkan sekali. Simpan sebelum menutup modal.</Alert>
            <Group justify="space-between"><Text>{credentials.email}</Text><CopyButton value={credentials.email}>{({ copy }) => <ActionIcon onClick={copy}><IconCopy size={16} /></ActionIcon>}</CopyButton></Group>
            <Group justify="space-between"><Text ff="monospace">{credentials.password}</Text><CopyButton value={credentials.password}>{({ copy }) => <ActionIcon onClick={copy}><IconCopy size={16} /></ActionIcon>}</CopyButton></Group>
            <Text size="sm">Aktif sampai {formatDate(credentials.expires_at)}</Text>
          </Stack>
        )}
      </Modal>

      <Modal opened={devicesOpen} onClose={devicesModal.close} title={`Perangkat - ${selectedUser?.nama}`} size="lg" fullScreen={isMobile}>
        <ScrollArea>
        <Table striped miw={640}>
          <Table.Thead><Table.Tr><Table.Th>Device</Table.Th><Table.Th>Platform</Table.Th><Table.Th>Terakhir Aktif</Table.Th><Table.Th>Status</Table.Th><Table.Th>Aksi</Table.Th></Table.Tr></Table.Thead>
          <Table.Tbody>
            {selectedUser?.devices?.map((device) => (
              <Table.Tr key={device.id}>
                <Table.Td>{device.device_name || device.device_id}</Table.Td>
                <Table.Td>{device.platform || '-'}</Table.Td>
                <Table.Td>{formatDate(device.last_active_at)}</Table.Td>
                <Table.Td><Badge color={device.is_active ? 'green' : 'gray'}>{device.is_active ? 'Aktif' : 'Nonaktif'}</Badge></Table.Td>
                <Table.Td>
                  {device.is_active && (
                    <Button
                      size="xs"
                      color="red"
                      variant="light"
                      loading={deviceMutation.isPending && deviceMutation.variables?.deviceId === device.id}
                      onClick={() => selectedUser && deviceMutation.mutate({ userId: selectedUser.id, deviceId: device.id })}
                    >
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
