import React from 'react'
import { Button, Card, Group, Modal, Text, Title, Stack, CopyButton, ActionIcon, Badge, TextInput, Alert, Menu, Table, Tooltip } from '@mantine/core'
import { showNotification } from '@mantine/notifications'
import { IconCopy, IconEdit, IconDevices, IconRefresh, IconTrash } from '@tabler/icons-react'
import { useAuth } from '@/contexts/AuthContext'
import { supabase } from '@/lib/supabase'
import { requestPasswordRecovery } from '@/lib/auth'
import type { UserWithDevices } from '@/lib/database.types'
import { SearchablePaginatedList } from '@/components/SearchablePaginatedList'

// Helper to format date in Indonesian locale
function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  })
}

// Helper to calculate days until expiry
function daysUntilExpiry(expiresAt: string): number {
  const now = new Date()
  const expiry = new Date(expiresAt)
  const diffTime = expiry.getTime() - now.getTime()
  return Math.ceil(diffTime / (1000 * 60 * 60 * 24))
}

// Helper to get expiry status badge
function ExpiryBadge({ expiresAt }: { expiresAt: string }) {
  const days = daysUntilExpiry(expiresAt)

  if (days < 0) {
    return <Badge color="red" variant="filled">Kadaluarsa</Badge>
  }
  if (days <= 30) {
    return <Badge color="yellow" variant="filled">{days} hari lagi</Badge>
  }
  if (days <= 90) {
    return <Badge color="orange" variant="light">{days} hari lagi</Badge>
  }
  return <Badge color="green" variant="light">{formatDate(expiresAt)}</Badge>
}

export function ManageUsersPage() {
  const { adminUser, session } = useAuth()
  const [createLoading, setCreateLoading] = React.useState(false)
  const [toggleLoading, setToggleLoading] = React.useState(false)
  const [resetLoading, setResetLoading] = React.useState(false)
  const [reprovisionLoading, setReprovisionLoading] = React.useState(false)
  const [forceLogoutLoading, setForceLogoutLoading] = React.useState(false)
  const [deleteLoading, setDeleteLoading] = React.useState(false)

  // Modal states
  const [credsModalOpen, setCredsModalOpen] = React.useState(false)
  const [confirmCreateOpen, setConfirmCreateOpen] = React.useState(false)
  const [toggleModalOpen, setToggleModalOpen] = React.useState(false)
  const [resetConfirmOpen, setResetConfirmOpen] = React.useState(false)
  const [reprovisionModalOpen, setReprovisionModalOpen] = React.useState(false)
  const [devicesModalOpen, setDevicesModalOpen] = React.useState(false)
  const [deleteModalOpen, setDeleteModalOpen] = React.useState(false)

  // Data states
  const [pendingBody, setPendingBody] = React.useState<{ email: string; nama: string } | null>(null)
  const [creds, setCreds] = React.useState<{ email: string; password: string; expires_at: string } | null>(null)
  const [users, setUsers] = React.useState<UserWithDevices[]>([])
  const [emailInput, setEmailInput] = React.useState('')
  const [emailError, setEmailError] = React.useState<string | null>(null)
  const [namaInput, setNamaInput] = React.useState('')

  // Action targets
  const [toggleTarget, setToggleTarget] = React.useState<{ id: string; email: string; targetActive: boolean } | null>(null)
  const [resetTarget, setResetTarget] = React.useState<{ id: string; email: string } | null>(null)
  const [reprovisionTarget, setReprovisionTarget] = React.useState<{ id: string; email: string } | null>(null)
  const [devicesTarget, setDevicesTarget] = React.useState<{ user: UserWithDevices } | null>(null)
  const [deleteTarget, setDeleteTarget] = React.useState<{ id: string; email: string; nama: string } | null>(null)

  const EDGE_FUNCTION_URL = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-user`
  const DELETE_USER_URL = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/delete-user`

  // Fetch users with their devices
  const fetchUsers = React.useCallback(async () => {
    if (!adminUser) return
    try {
      const { data } = await supabase
        .from('users')
        .select(`
          *,
          user_devices(*),
          created_by_admin:admin_users!created_by(id, nama, email)
        `)
        .order('created_at', { ascending: false })
      if (data) setUsers(data as UserWithDevices[])
    } catch {
      // ignore
    }
  }, [adminUser])

  React.useEffect(() => {
    fetchUsers()
  }, [fetchUsers])

  // Toggle user active state
  const toggleActiveUser = async (userId: string, targetActive: boolean) => {
    if (!adminUser) {
      showNotification({ title: 'Error', message: 'Tidak terautentikasi', color: 'red' })
      return
    }

    setToggleLoading(true)
    try {
      const { error } = await supabase
        .from('users')
        .update({ is_active: targetActive } as never)
        .eq('id', userId)

      if (error) throw error

      setUsers((prev) => prev.map((u) => (u.id === userId ? { ...u, is_active: targetActive } : u)))
      setToggleModalOpen(false)
      setToggleTarget(null)
      showNotification({ title: 'Berhasil', message: `Pengguna berhasil di${targetActive ? 'aktifkan' : 'nonaktifkan'}`, color: 'green' })
    } catch (err: any) {
      showNotification({ title: 'Error', message: String(err?.message || err), color: 'red' })
    } finally {
      setToggleLoading(false)
    }
  }

  // Re-provision expired user (extend 3 more years)
  const reprovisionUser = async (userId: string) => {
    if (!adminUser) {
      showNotification({ title: 'Error', message: 'Tidak terautentikasi', color: 'red' })
      return
    }

    setReprovisionLoading(true)
    try {
      const now = new Date()
      const newExpiresAt = new Date(now.getTime() + (3 * 365 * 24 * 60 * 60 * 1000))

      const { error } = await supabase
        .from('users')
        .update({
          expires_at: newExpiresAt.toISOString(),
          is_active: true
        } as never)
        .eq('id', userId)

      if (error) throw error

      setUsers((prev) => prev.map((u) => (u.id === userId ? { ...u, expires_at: newExpiresAt.toISOString(), is_active: true } : u)))
      setReprovisionModalOpen(false)
      setReprovisionTarget(null)
      showNotification({ title: 'Berhasil', message: 'Masa aktif pengguna diperpanjang 3 tahun', color: 'green' })
    } catch (err: any) {
      showNotification({ title: 'Error', message: String(err?.message || err), color: 'red' })
    } finally {
      setReprovisionLoading(false)
    }
  }

  // Force logout a specific device
  const forceLogoutDevice = async (deviceId: string, userId: string) => {
    setForceLogoutLoading(true)
    try {
      const { error } = await supabase
        .from('user_devices')
        .update({ is_active: false } as never)
        .eq('id', deviceId)

      if (error) throw error

      // Update local state
      setUsers((prev) => prev.map((u) => {
        if (u.id === userId) {
          return {
            ...u,
            user_devices: u.user_devices.map((d) => d.id === deviceId ? { ...d, is_active: false } : d)
          }
        }
        return u
      }))

      // Update devices modal target
      if (devicesTarget) {
        setDevicesTarget({
          user: {
            ...devicesTarget.user,
            user_devices: devicesTarget.user.user_devices.map((d) => d.id === deviceId ? { ...d, is_active: false } : d)
          }
        })
      }

      showNotification({ title: 'Berhasil', message: 'Perangkat berhasil dilogout', color: 'green' })
    } catch (err: any) {
      showNotification({ title: 'Error', message: String(err?.message || err), color: 'red' })
    } finally {
      setForceLogoutLoading(false)
    }
  }

  // Delete user via Edge Function
  const deleteUser = async (userId: string) => {
    if (!session?.access_token) return
    setDeleteLoading(true)
    try {
      const res = await fetch(DELETE_USER_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({ user_id: userId }),
      })

      let json: any = null
      const ct = res.headers.get('content-type') || ''
      let textBody = ''
      if (ct.includes('application/json')) {
        try { json = await res.json() } catch (e) { textBody = await res.text() }
      } else {
        textBody = await res.text()
        try { json = JSON.parse(textBody) } catch (e) { }
      }

      if (!res.ok) {
        const errMsg = json?.error || textBody || res.statusText || 'Request failed'
        throw new Error(errMsg)
      }

      // Remove user from local state
      setUsers((prev) => prev.filter((u) => u.id !== userId))
      setDeleteModalOpen(false)
      setDeleteTarget(null)
      showNotification({ title: 'Berhasil', message: 'Pengguna berhasil dihapus', color: 'green' })
    } catch (err: any) {
      showNotification({ title: 'Error', message: String(err?.message || err), color: 'red' })
    } finally {
      setDeleteLoading(false)
    }
  }

  // Create new user via Edge Function
  const performCreateUser = async (body: { email: string; nama: string }) => {
    if (!session?.access_token) return
    setCreateLoading(true)
    try {
      const res = await fetch(EDGE_FUNCTION_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify(body),
      })

      let json: any = null
      const ct = res.headers.get('content-type') || ''
      let textBody = ''
      if (ct.includes('application/json')) {
        try { json = await res.json() } catch (e) { textBody = await res.text() }
      } else {
        textBody = await res.text()
        try { json = JSON.parse(textBody) } catch (e) { }
      }

      if (!res.ok) {
        const errMsg = json?.error || textBody || res.statusText || 'Request failed'
        throw new Error(errMsg)
      }

      setCreds({ email: json.email, password: json.password, expires_at: json.expires_at })
      setCredsModalOpen(true)

      // Refresh user list
      await fetchUsers()

      // Clear inputs
      setEmailInput('')
      setNamaInput('')
      setEmailError(null)
    } catch (err: any) {
      showNotification({ title: 'Error', message: String(err?.message || err), color: 'red' })
    } finally {
      setCreateLoading(false)
    }
  }

  const handleCreateClick = () => {
    if (!emailInput.trim()) {
      showNotification({ title: 'Validasi', message: 'Email diperlukan', color: 'yellow' })
      return
    }
    if (!namaInput.trim()) {
      showNotification({ title: 'Validasi', message: 'Nama diperlukan', color: 'yellow' })
      return
    }
    setPendingBody({ email: emailInput.trim(), nama: namaInput.trim() })
    setConfirmCreateOpen(true)
  }

  // Check if user is admin (any admin, not just super_admin)
  if (!adminUser) {
    return (
      <Card>
        <Title order={3}>Access denied</Title>
        <Text>Anda harus login sebagai admin untuk melihat halaman ini.</Text>
      </Card>
    )
  }

  return (
    <div>
      <Group mb="md" style={{ display: 'block' }}>
        <div>
          <Title order={2}>Kelola Pengguna</Title>
          <Text c="dimmed">Kelola pengguna aplikasi mobile</Text>
        </div>
        <div style={{ width: '100%', marginTop: '1rem' }}>
          <Alert title="Form membuat pengguna baru" color="blue" variant="light">
            Form ini akan membuat akun pengguna baru dengan masa aktif 3 tahun. Kredensial sementara hanya akan ditampilkan sekali.
            <div style={{ height: 8 }} />
            <Group mt="xs" style={{ maxWidth: '760px' }}>
              <TextInput
                placeholder="Email (required)"
                type="email"
                required
                value={emailInput}
                onChange={(e) => {
                  const v = e.currentTarget.value
                  setEmailInput(v)
                  const ok = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v.trim())
                  setEmailError(v.trim() ? (ok ? null : 'Masukkan email yang valid') : 'Email diperlukan')
                }}
                error={emailError}
                style={{ flex: 1 }}
              />
              <TextInput placeholder="Nama (required)" value={namaInput} onChange={(e) => setNamaInput(e.currentTarget.value)} style={{ width: 220 }} required />
              <Button color="blue" onClick={handleCreateClick} loading={createLoading} disabled={!emailInput.trim() || !namaInput.trim() || !!emailError}>
                Tambah Pengguna
              </Button>
            </Group>
          </Alert>
        </div>
      </Group>

      {/* Users List with Search and Pagination */}
      <SearchablePaginatedList
        data={users}
        searchTitle="Cari User"
        searchPlaceholder="Cari berdasarkan nama atau email..."
        getSearchableText={(user) => `${user.nama} ${user.email}`.toLowerCase()}
        isActive={(user) => user.is_active && daysUntilExpiry(user.expires_at) >= 0}
        activeSection={{
          title: 'Pengguna Aktif',
          emptyText: 'Tidak ada pengguna aktif',
          render: (items) => (
            <div style={{ minWidth: 700 }}>
              <Table striped highlightOnHover style={{ width: '100%' }}>
                <Table.Thead>
                  <Table.Tr>
                    <Table.Th>Nama</Table.Th>
                    <Table.Th>Email</Table.Th>
                    <Table.Th>Masa Aktif</Table.Th>
                    <Table.Th>Perangkat</Table.Th>
                    <Table.Th>Aksi</Table.Th>
                  </Table.Tr>
                </Table.Thead>
              <Table.Tbody>
                {items.map((user) => {
                  const activeDevices = user.user_devices?.filter(d => d.is_active).length || 0
                  return (
                    <Table.Tr key={user.id}>
                      <Table.Td><Text fw={600}>{user.nama}</Text></Table.Td>
                      <Table.Td>{user.email}</Table.Td>
                      <Table.Td><ExpiryBadge expiresAt={user.expires_at} /></Table.Td>
                      <Table.Td>
                        <Tooltip label="Lihat perangkat">
                          <Badge
                            color={activeDevices > 0 ? 'blue' : 'gray'}
                            variant="light"
                            style={{ cursor: 'pointer' }}
                            onClick={() => {
                              setDevicesTarget({ user })
                              setDevicesModalOpen(true)
                            }}
                            leftSection={<IconDevices size={12} />}
                          >
                            {activeDevices} aktif
                          </Badge>
                        </Tooltip>
                      </Table.Td>
                      <Table.Td onClick={(e) => e.stopPropagation()}>
                        <Group gap={4}>
                          <Menu withArrow position="left" shadow="sm">
                            <Menu.Target>
                              <Tooltip label="Kelola">
                                <ActionIcon variant="subtle" color="blue">
                                  <IconEdit size={16} />
                                </ActionIcon>
                              </Tooltip>
                            </Menu.Target>
                            <Menu.Dropdown>
                              <Menu.Item
                                color="blue"
                                onClick={() => {
                                  setDevicesTarget({ user })
                                  setDevicesModalOpen(true)
                                }}
                              >
                                Kelola Perangkat
                              </Menu.Item>
                              <Menu.Item
                                color="yellow"
                                onClick={() => {
                                  setResetTarget({ id: user.id, email: user.email })
                                  setResetConfirmOpen(true)
                                }}
                              >
                                Kirim Reset Password
                              </Menu.Item>
                              <Menu.Item
                                color="orange"
                                onClick={() => {
                                  setToggleTarget({ id: user.id, email: user.email, targetActive: false })
                                  setToggleModalOpen(true)
                                }}
                              >
                                Nonaktifkan Pengguna
                              </Menu.Item>
                            </Menu.Dropdown>
                          </Menu>
                          <Tooltip label="Hapus">
                            <ActionIcon
                              variant="subtle"
                              color="red"
                              onClick={() => {
                                setDeleteTarget({ id: user.id, email: user.email, nama: user.nama })
                                setDeleteModalOpen(true)
                              }}
                            >
                              <IconTrash size={16} />
                            </ActionIcon>
                          </Tooltip>
                        </Group>
                      </Table.Td>
                    </Table.Tr>
                  )
                })}
              </Table.Tbody>
              </Table>
            </div>
          ),
        }}
        inactiveSection={{
          title: 'Pengguna Tidak Aktif / Kadaluarsa',
          emptyText: 'Tidak ada pengguna tidak aktif atau kadaluarsa',
          render: (items) => (
            <div style={{ minWidth: 700 }}>
              <Table striped highlightOnHover style={{ width: '100%' }}>
                <Table.Thead>
                  <Table.Tr>
                    <Table.Th>Nama</Table.Th>
                    <Table.Th>Email</Table.Th>
                    <Table.Th>Status</Table.Th>
                    <Table.Th>Masa Aktif</Table.Th>
                    <Table.Th>Aksi</Table.Th>
                  </Table.Tr>
                </Table.Thead>
              <Table.Tbody>
                {items.map((user) => {
                  const isExpired = daysUntilExpiry(user.expires_at) < 0
                  return (
                    <Table.Tr key={user.id}>
                      <Table.Td><Text fw={600}>{user.nama}</Text></Table.Td>
                      <Table.Td>{user.email}</Table.Td>
                      <Table.Td>
                        {!user.is_active && <Badge color="gray" variant="filled" mr={4}>Nonaktif</Badge>}
                        {isExpired && <Badge color="red" variant="filled">Kadaluarsa</Badge>}
                      </Table.Td>
                      <Table.Td><ExpiryBadge expiresAt={user.expires_at} /></Table.Td>
                      <Table.Td onClick={(e) => e.stopPropagation()}>
                        <Group gap={4}>
                          <Menu withArrow position="left" shadow="sm">
                            <Menu.Target>
                              <Tooltip label="Kelola">
                                <ActionIcon variant="subtle" color="blue">
                                  <IconEdit size={16} />
                                </ActionIcon>
                              </Tooltip>
                            </Menu.Target>
                            <Menu.Dropdown>
                              <Menu.Item
                                color="green"
                                leftSection={<IconRefresh size={14} />}
                                onClick={() => {
                                  setReprovisionTarget({ id: user.id, email: user.email })
                                  setReprovisionModalOpen(true)
                                }}
                              >
                                Perpanjang 3 Tahun
                              </Menu.Item>
                              {!user.is_active && (
                                <Menu.Item
                                  color="green"
                                  onClick={() => {
                                    setToggleTarget({ id: user.id, email: user.email, targetActive: true })
                                    setToggleModalOpen(true)
                                  }}
                                >
                                  Aktifkan Pengguna
                                </Menu.Item>
                              )}
                              <Menu.Item
                                color="yellow"
                                onClick={() => {
                                  setResetTarget({ id: user.id, email: user.email })
                                  setResetConfirmOpen(true)
                                }}
                              >
                                Kirim Reset Password
                              </Menu.Item>
                            </Menu.Dropdown>
                          </Menu>
                          <Tooltip label="Hapus">
                            <ActionIcon
                              variant="subtle"
                              color="red"
                              onClick={() => {
                                setDeleteTarget({ id: user.id, email: user.email, nama: user.nama })
                                setDeleteModalOpen(true)
                              }}
                            >
                              <IconTrash size={16} />
                            </ActionIcon>
                          </Tooltip>
                        </Group>
                      </Table.Td>
                    </Table.Tr>
                  )
                })}
              </Table.Tbody>
              </Table>
            </div>
          ),
        }}
      />

      {/* Credentials Modal */}
      <Modal opened={credsModalOpen} onClose={() => setCredsModalOpen(false)} title="Kredensial Sementara" closeOnClickOutside={false} closeOnEscape={false}>
        {creds ? (
          <Stack>
            <Alert color="yellow" title="Simpan kredensial ini sekarang!">
              Kredensial ini hanya ditampilkan sekali dan tidak dapat dilihat lagi.
            </Alert>
            <div>
              <Text size="sm">Email</Text>
              <Group>
                <Text fw={600}>{creds.email}</Text>
                <CopyButton value={creds.email} timeout={2000}>
                  {({ copied, copy }) => (
                    <ActionIcon color={copied ? 'teal' : 'blue'} onClick={copy}>
                      <IconCopy size={16} />
                    </ActionIcon>
                  )}
                </CopyButton>
              </Group>
            </div>
            <div>
              <Text size="sm">Password Sementara</Text>
              <Group>
                <Text fw={600} style={{ fontFamily: 'monospace' }}>{creds.password}</Text>
                <CopyButton value={creds.password} timeout={2000}>
                  {({ copied, copy }) => (
                    <ActionIcon color={copied ? 'teal' : 'blue'} onClick={copy}>
                      <IconCopy size={16} />
                    </ActionIcon>
                  )}
                </CopyButton>
              </Group>
            </div>
            <div>
              <Text size="sm">Masa Aktif Sampai</Text>
              <Text fw={600}>{formatDate(creds.expires_at)}</Text>
            </div>
            <Text size="sm" c="dimmed">Beritahu pengguna untuk mengganti password saat pertama kali login.</Text>
            <Button onClick={() => setCredsModalOpen(false)}>Selesai</Button>
          </Stack>
        ) : (
          <Text>Memuat...</Text>
        )}
      </Modal>

      {/* Confirm Create Modal */}
      <Modal opened={confirmCreateOpen} onClose={() => setConfirmCreateOpen(false)} title="Konfirmasi Pembuatan Pengguna">
        <Stack>
          <Text>Anda akan membuat pengguna baru dengan email <b>{pendingBody?.email}</b> dan nama <b>{pendingBody?.nama}</b>.</Text>
          <Text size="sm" c="dimmed">Pengguna akan memiliki masa aktif 3 tahun dari sekarang.</Text>
          <Group>
            <Button variant="default" onClick={() => setConfirmCreateOpen(false)}>Batal</Button>
            <Button color="blue" onClick={async () => {
              if (!pendingBody) return
              setConfirmCreateOpen(false)
              await performCreateUser(pendingBody)
              setPendingBody(null)
            }}>Ya, Buat</Button>
          </Group>
        </Stack>
      </Modal>

      {/* Toggle Active Modal */}
      <Modal
        opened={toggleModalOpen}
        onClose={() => { setToggleModalOpen(false); setToggleTarget(null) }}
        title={toggleTarget?.targetActive ? 'Konfirmasi Aktifkan Pengguna' : 'Konfirmasi Nonaktifkan Pengguna'}
      >
        <Stack>
          <Text>
            {toggleTarget?.targetActive
              ? `Anda akan mengaktifkan kembali pengguna ${toggleTarget?.email}.`
              : `Anda akan menonaktifkan pengguna ${toggleTarget?.email}. Pengguna tidak akan bisa mengakses aplikasi.`}
          </Text>
          <Group>
            <Button variant="default" onClick={() => { setToggleModalOpen(false); setToggleTarget(null) }}>Batal</Button>
            <Button
              color={toggleTarget?.targetActive ? 'green' : 'red'}
              loading={toggleLoading}
              onClick={async () => {
                if (!toggleTarget) return
                await toggleActiveUser(toggleTarget.id, toggleTarget.targetActive)
              }}
            >
              {toggleTarget?.targetActive ? 'Aktifkan' : 'Nonaktifkan'}
            </Button>
          </Group>
        </Stack>
      </Modal>

      {/* Reset Password Confirm Modal */}
      <Modal opened={resetConfirmOpen} onClose={() => { setResetConfirmOpen(false); setResetTarget(null) }} title="Kirim Reset Password">
        <Stack>
          <Text>Anda akan mengirim email reset password ke <b>{resetTarget?.email}</b>. Lanjutkan?</Text>
          <Group>
            <Button variant="default" onClick={() => { setResetConfirmOpen(false); setResetTarget(null) }}>Batal</Button>
            <Button color="yellow" loading={resetLoading} onClick={async () => {
              if (!resetTarget) return
              setResetConfirmOpen(false)
              setResetLoading(true)
              try {
                await requestPasswordRecovery(resetTarget.email)
                showNotification({ title: 'Terkirim', message: 'Email reset password terkirim.', color: 'green' })
              } catch (err: any) {
                showNotification({ title: 'Error', message: String(err?.message || err), color: 'red' })
              } finally {
                setResetLoading(false)
                setResetTarget(null)
              }
            }}>Kirim</Button>
          </Group>
        </Stack>
      </Modal>

      {/* Re-provision Modal */}
      <Modal opened={reprovisionModalOpen} onClose={() => { setReprovisionModalOpen(false); setReprovisionTarget(null) }} title="Perpanjang Masa Aktif">
        <Stack>
          <Text>Anda akan memperpanjang masa aktif pengguna <b>{reprovisionTarget?.email}</b> menjadi 3 tahun dari sekarang.</Text>
          <Text size="sm" c="dimmed">Pengguna juga akan diaktifkan kembali jika sebelumnya nonaktif.</Text>
          <Group>
            <Button variant="default" onClick={() => { setReprovisionModalOpen(false); setReprovisionTarget(null) }}>Batal</Button>
            <Button color="green" loading={reprovisionLoading} onClick={async () => {
              if (!reprovisionTarget) return
              await reprovisionUser(reprovisionTarget.id)
            }}>Perpanjang</Button>
          </Group>
        </Stack>
      </Modal>

      {/* Devices Modal */}
      <Modal opened={devicesModalOpen} onClose={() => { setDevicesModalOpen(false); setDevicesTarget(null) }} title={`Perangkat - ${devicesTarget?.user.nama}`} size="lg">
        <Stack>
          {devicesTarget?.user.user_devices && devicesTarget.user.user_devices.length > 0 ? (
            <Table>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Nama Perangkat</Table.Th>
                  <Table.Th>Status</Table.Th>
                  <Table.Th>Terakhir Aktif</Table.Th>
                  <Table.Th>Aksi</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                {devicesTarget.user.user_devices.map((device) => (
                  <Table.Tr key={device.id}>
                    <Table.Td>{device.device_name || 'Unknown Device'}</Table.Td>
                    <Table.Td>
                      <Badge color={device.is_active ? 'green' : 'gray'} variant="light">
                        {device.is_active ? 'Aktif' : 'Tidak Aktif'}
                      </Badge>
                    </Table.Td>
                    <Table.Td>{formatDate(device.last_active_at)}</Table.Td>
                    <Table.Td>
                      {device.is_active && (
                        <Button
                          size="xs"
                          color="red"
                          variant="light"
                          loading={forceLogoutLoading}
                          onClick={() => forceLogoutDevice(device.id, devicesTarget.user.id)}
                        >
                          Force Logout
                        </Button>
                      )}
                    </Table.Td>
                  </Table.Tr>
                ))}
              </Table.Tbody>
            </Table>
          ) : (
            <Text c="dimmed" ta="center">Pengguna belum pernah login dari perangkat manapun.</Text>
          )}
          <Button variant="default" onClick={() => { setDevicesModalOpen(false); setDevicesTarget(null) }}>Tutup</Button>
        </Stack>
      </Modal>

      {/* Delete User Confirmation Modal */}
      <Modal opened={deleteModalOpen} onClose={() => { setDeleteModalOpen(false); setDeleteTarget(null) }} title="Hapus Pengguna">
        <Stack>
          <Alert color="red" title="Peringatan!">
            Tindakan ini tidak dapat dibatalkan. Pengguna akan dihapus secara permanen dari sistem dan tidak akan bisa login kembali.
          </Alert>
          <Text>Anda yakin ingin menghapus pengguna <b>{deleteTarget?.nama}</b> ({deleteTarget?.email})?</Text>
          <Group>
            <Button variant="default" onClick={() => { setDeleteModalOpen(false); setDeleteTarget(null) }}>Batal</Button>
            <Button color="red" loading={deleteLoading} onClick={async () => {
              if (!deleteTarget) return
              await deleteUser(deleteTarget.id)
            }}>Hapus</Button>
          </Group>
        </Stack>
      </Modal>
    </div>
  )
}
