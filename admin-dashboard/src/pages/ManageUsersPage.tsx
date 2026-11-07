import { useState } from 'react'
import {
  ActionIcon,
  Alert,
  Badge,
  Button,
  CopyButton,
  Group,
  Modal,
  PasswordInput,
  ScrollArea,
  Stack,
  Table,
  Tabs,
  Text,
  TextInput,
  Title,
  Tooltip,
} from '@mantine/core'
import { Dropzone } from '@mantine/dropzone'
import { useDisclosure, useMediaQuery } from '@mantine/hooks'
import { modals } from '@mantine/modals'
import { showNotification } from '@mantine/notifications'
import {
  IconCalendarPlus,
  IconCheck,
  IconCopy,
  IconDevices,
  IconFileSpreadsheet,
  IconKey,
  IconLogout,
  IconRefresh,
  IconTrash,
  IconUpload,
  IconUserCheck,
  IconUserOff,
  IconUserPlus,
  IconX,
} from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { IconAction } from '@/components/IconAction'
import { SearchablePaginatedList } from '@/components/SearchablePaginatedList'
import { api, type PaginatedResponse } from '@/lib/api'
import { invalidateAdminData } from '@/lib/query-invalidation'

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
  if (days < 0) return <Badge color="red">Kedaluwarsa</Badge>
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
  const [addOpen, addModal] = useDisclosure(false)

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
    onSuccess: async (user) => {
      await invalidateAdminData(queryClient)
      addModal.close()
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
    onSuccess: async () => {
      await invalidateAdminData(queryClient)
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const extendMutation = useMutation({
    mutationFn: (id: string) => api.patch(`/admin/mobile-users/${id}/extend`, { years: 3 }),
    onSuccess: async () => {
      await invalidateAdminData(queryClient)
      showNotification({ title: 'Berhasil', message: 'Masa aktif diperpanjang 3 tahun', color: 'green' })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const resetPasswordMutation = useMutation({
    mutationFn: (id: string) => api.patch<MobileUser & { temporary_password: string }>(`/admin/mobile-users/${id}/password`),
    onSuccess: async (user) => {
      await invalidateAdminData(queryClient)
      setCredentials({ email: user.email, password: user.temporary_password, expires_at: user.expires_at })
      showNotification({ title: 'Berhasil', message: 'Password baru berhasil dibuat', color: 'green' })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/admin/mobile-users/${id}`),
    onSuccess: async () => {
      await invalidateAdminData(queryClient)
      showNotification({ title: 'Berhasil', message: 'Pengguna dihapus', color: 'green' })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const deviceMutation = useMutation({
    mutationFn: ({ userId, deviceId }: { userId: string; deviceId: string }) =>
      api.delete(`/admin/mobile-users/${userId}/devices/${deviceId}`),
    onSuccess: async (_, variables) => {
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
      await invalidateAdminData(queryClient)
    },
    onError: (error: Error) => showNotification({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const batchMutation = useMutation({
    mutationFn: async (file: File) => {
      const buffer = await file.arrayBuffer()
      const XLSX = await import('xlsx')
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
    onSuccess: async (result) => {
      await invalidateAdminData(queryClient)
      addModal.close()
      showNotification({ title: 'Import selesai', message: `${result.created.length} berhasil, ${result.errors.length} gagal`, color: result.errors.length ? 'orange' : 'green' })
    },
    onError: (error: Error) => showNotification({ title: 'Gagal import', message: error.message, color: 'red' }),
  })

  const confirmResetPassword = (user: MobileUser) =>
    modals.openConfirmModal({
      title: 'Reset password?',
      children: <Text size="sm">Password lama {user.nama} langsung tidak berlaku. Password baru ditampilkan satu kali.</Text>,
      labels: { confirm: 'Reset password', cancel: 'Batal' },
      onConfirm: () => resetPasswordMutation.mutate(user.id),
    })

  const confirmDelete = (user: MobileUser) =>
    modals.openConfirmModal({
      title: 'Hapus pengguna?',
      children: <Text size="sm">Akun {user.nama} ({user.email}) dan perangkatnya akan dihapus.</Text>,
      labels: { confirm: 'Hapus', cancel: 'Batal' },
      confirmProps: { color: 'red' },
      onConfirm: () => deleteMutation.mutate(user.id),
    })

  const renderUserActions = (user: MobileUser) => {
    const isExtending = extendMutation.isPending && extendMutation.variables === user.id
    const isResettingPassword = resetPasswordMutation.isPending && resetPasswordMutation.variables === user.id
    const isToggling = toggleMutation.isPending && toggleMutation.variables?.id === user.id
    const isDeleting = deleteMutation.isPending && deleteMutation.variables === user.id

    return (
      <Group gap={2} wrap="nowrap">
        <IconAction label="Perpanjang 3 tahun" icon={<IconCalendarPlus size={18} />} color="blue" onClick={() => extendMutation.mutate(user.id)} loading={isExtending} />
        <IconAction label="Reset password" icon={<IconKey size={18} />} color="blue" onClick={() => confirmResetPassword(user)} loading={isResettingPassword} />
        <IconAction
          label={user.is_active ? 'Nonaktifkan' : 'Aktifkan'}
          icon={user.is_active ? <IconUserOff size={18} /> : <IconUserCheck size={18} />}
          color={user.is_active ? 'orange' : 'green'}
          onClick={() => toggleMutation.mutate({ id: user.id, active: !user.is_active })}
          loading={isToggling}
        />
        <IconAction label="Hapus pengguna" icon={<IconTrash size={18} />} color="red" onClick={() => confirmDelete(user)} loading={isDeleting} />
      </Group>
    )
  }

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
        <Table.Td w={1}>
          {renderUserActions(user)}
        </Table.Td>
      </Table.Tr>
    )
  })

  const renderTable = (items: MobileUser[]) => (
    <Table striped highlightOnHover miw={820} verticalSpacing="xs">
      <Table.Thead>
        <Table.Tr>
          <Table.Th>Nama</Table.Th>
          <Table.Th>Email</Table.Th>
          <Table.Th>Status</Table.Th>
          <Table.Th>Masa Aktif</Table.Th>
          <Table.Th>Perangkat</Table.Th>
          <Table.Th>Aksi</Table.Th>
        </Table.Tr>
      </Table.Thead>
      <Table.Tbody>{renderRows(items)}</Table.Tbody>
    </Table>
  )

  return (
    <Stack gap="lg">
      <Group justify="space-between" wrap="wrap">
        <div>
          <Title order={2}>Kelola Pengguna</Title>
          <Text c="dimmed">Akun pengguna aplikasi mobile</Text>
        </div>
        <Button leftSection={<IconUserPlus size={16} />} onClick={addModal.open} fullWidth={isMobile}>
          Tambah Pengguna
        </Button>
      </Group>

      <SearchablePaginatedList
        data={users}
        isLoading={isLoading}
        getSearchableText={(user) => `${user.nama} ${user.email}`}
        isActive={(user) => user.is_active && daysUntilExpiry(user.expires_at) >= 0}
        toolbarActions={
          <IconAction label="Muat ulang" icon={<IconRefresh size={18} />} onClick={() => queryClient.invalidateQueries({ queryKey: ['mobile_users'] })} />
        }
        activeSection={{
          title: 'Aktif',
          emptyText: 'Tidak ada pengguna aktif.',
          render: renderTable,
        }}
        inactiveSection={{
          title: 'Nonaktif / kedaluwarsa',
          emptyText: 'Tidak ada pengguna nonaktif atau kedaluwarsa.',
          render: renderTable,
        }}
      />

      <Modal opened={addOpen} onClose={addModal.close} title="Tambah pengguna mobile" size="lg" fullScreen={isMobile}>
        <Tabs defaultValue="single">
          <Tabs.List mb="md">
            <Tabs.Tab value="single" leftSection={<IconUserPlus size={14} />}>Satu pengguna</Tabs.Tab>
            <Tabs.Tab value="xlsx" leftSection={<IconFileSpreadsheet size={14} />}>Import XLSX</Tabs.Tab>
          </Tabs.List>
          <Tabs.Panel value="single">
            <Stack>
              <TextInput label="Email" required value={email} onChange={(event) => setEmail(event.currentTarget.value)} />
              <TextInput label="Nama" required value={nama} onChange={(event) => setNama(event.currentTarget.value)} />
              <PasswordInput label="Password awal" description="Kosongkan untuk dibuatkan otomatis" value={password} onChange={(event) => setPassword(event.currentTarget.value)} />
              <Group justify="flex-end">
                <Button onClick={() => createMutation.mutate()} loading={createMutation.isPending} disabled={!email || !nama}>
                  Tambah
                </Button>
              </Group>
            </Stack>
          </Tabs.Panel>
          <Tabs.Panel value="xlsx">
            <Stack>
              <Text size="sm" c="dimmed">
                Baris pertama berisi kolom <b>email</b>, <b>nama</b>, dan <b>password</b> (opsional). Maksimal 5 MB.
              </Text>
              <Dropzone
                onDrop={(files) => files[0] && batchMutation.mutate(files[0])}
                loading={batchMutation.isPending}
                accept={{
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'],
                  'application/vnd.ms-excel': ['.xls'],
                }}
                maxSize={5 * 1024 * 1024}
                multiple={false}
              >
                <Stack align="center" gap="xs" mih={120} justify="center" style={{ pointerEvents: 'none' }}>
                  <Dropzone.Accept><IconCheck size={28} /></Dropzone.Accept>
                  <Dropzone.Reject><IconX size={28} /></Dropzone.Reject>
                  <Dropzone.Idle><IconUpload size={28} /></Dropzone.Idle>
                  <Text size="sm">Seret file XLSX ke sini atau klik untuk memilih</Text>
                </Stack>
              </Dropzone>
            </Stack>
          </Tabs.Panel>
        </Tabs>
      </Modal>

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
                    <IconAction
                      label="Paksa keluar dari perangkat ini"
                      icon={<IconLogout size={18} />}
                      color="red"
                      loading={deviceMutation.isPending && deviceMutation.variables?.deviceId === device.id}
                      onClick={() => selectedUser && deviceMutation.mutate({ userId: selectedUser.id, deviceId: device.id })}
                    />
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
