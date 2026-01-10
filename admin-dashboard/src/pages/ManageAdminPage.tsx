import React from 'react'
import { Button, Card, Group, Modal, Text, Title, Stack, CopyButton, ActionIcon, Badge, TextInput, Alert, Menu, Table } from '@mantine/core'
import { showNotification } from '@mantine/notifications'
import { IconCopy, IconEdit } from '@tabler/icons-react'
import { useAuth } from '@/contexts/AuthContext'
import { supabase } from '@/lib/supabase'
import { requestPasswordRecovery } from '@/lib/auth'
import { SearchablePaginatedList } from '@/components/SearchablePaginatedList'


export function ManageAdminPage() {
  const { adminUser, session } = useAuth()
  const [createLoading, setCreateLoading] = React.useState(false)
  const [toggleLoading, setToggleLoading] = React.useState(false)
  const [resetLoading, setResetLoading] = React.useState(false)
  const [modalOpen, setModalOpen] = React.useState(false)
  const [confirmOpen, setConfirmOpen] = React.useState(false)
  const [pendingBody, setPendingBody] = React.useState<{ email: string; nama: string } | null>(null)
  const [creds, setCreds] = React.useState<{ email: string; password: string } | null>(null)
  const [admins, setAdmins] = React.useState<Array<{ id: string; email: string; nama: string; role: string; is_active: boolean }>>([])
  const [emailInput, setEmailInput] = React.useState<string>('')
  const [emailError, setEmailError] = React.useState<string | null>(null)
  const [namaInput, setNamaInput] = React.useState<string>('')
  const [toggleModalOpen, setToggleModalOpen] = React.useState(false)
  const [toggleTarget, setToggleTarget] = React.useState<{ id: string; email: string; targetActive: boolean } | null>(null)
  const [resetConfirmOpen, setResetConfirmOpen] = React.useState(false)
  const [resetTarget, setResetTarget] = React.useState<{ id: string; email: string } | null>(null)

  const EDGE_FUNCTION_URL = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-admin`

  React.useEffect(() => {
    if (!adminUser) return
      ; (async () => {
        try {
          const { data } = await supabase.from('admin_users').select('id,email,nama,role,is_active').order('created_at', { ascending: false })
          if (data) setAdmins(data as any)
        } catch {
        }
      })()
  }, [adminUser])

  // toggle admin active state
  const toggleActiveAdmin = async (adminId: string, targetActive: boolean) => {
    if (!adminUser) {
      showNotification({ title: 'Not authenticated', message: 'User not authenticated', color: 'red' })
      return
    }

    // prevent user from deactivating themselves
    if (adminUser.id === adminId && targetActive === false) {
      showNotification({ title: 'Peringatan', message: 'Anda tidak dapat menonaktifkan akun Anda sendiri', color: 'yellow' })
      return
    }

    setToggleLoading(true)
    try {
      const { error } = await supabase
        .from('admin_users')
        .update({ is_active: targetActive } as never)
        .eq('id', adminId)

      if (error) throw error

      // update local state
      setAdmins((prev) => prev.map((a) => (a.id === adminId ? { ...a, is_active: targetActive } : a)))
      setToggleModalOpen(false)
      setToggleTarget(null)
    } catch (err: any) {
      showNotification({ title: 'Error', message: String(err?.message || err), color: 'red' })
    } finally {
      setToggleLoading(false)
    }
  }

  // perform actual create request (called after confirmation)
  const performCreateAdmin = async (body: { email: string; nama: string }) => {
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

      // parse response safely
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

      setCreds({ email: json.email, password: json.password })
      setModalOpen(true)

      // refresh admin list
      const { data } = await supabase.from('admin_users').select('id,email,nama,role,is_active').order('created_at', { ascending: false })
      if (data) setAdmins(data as any)
      // clear inputs after successful creation
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
      showNotification({ title: 'Validasi', message: 'Email is required', color: 'yellow' })
      return
    }
    if (!namaInput.trim()) {
      showNotification({ title: 'Validasi', message: 'Username is required', color: 'yellow' })
      return
    }
    setPendingBody({ email: emailInput.trim(), nama: namaInput.trim() })
    setConfirmOpen(true)
  }

  if (adminUser?.role !== 'super_admin') {
    return (
      <Card>
        <Title order={3}>Access denied</Title>
        <Text>You do not have permission to view this page.</Text>
      </Card>
    )
  }

  return (
    <div>
      <Group mb="md" style={{ display: 'block' }}>
        <div>
          <Title order={2}>Manage Admin</Title>
          <Text c="dimmed">Page khusus super admin</Text>
        </div>
        <div style={{ width: '100%', marginTop: '1rem' }}>
          <Alert title="Form membuat admin baru" color="blue" variant="light">
            Form ini akan membuat akun admin baru. Lakukan dengan hati-hati — kredensial sementara hanya akan ditampilkan sekali.
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
                  // simple client-side validation
                  const ok = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v.trim())
                  setEmailError(v.trim() ? (ok ? null : 'Masukkan email yang valid') : 'Email diperlukan')
                }}
                error={emailError}
                style={{ flex: 1 }}
              />
              <TextInput placeholder="Username (required)" value={namaInput} onChange={(e) => setNamaInput(e.currentTarget.value)} style={{ width: 220 }} required />
              <Button color="blue" onClick={handleCreateClick} loading={createLoading} disabled={!emailInput.trim() || !namaInput.trim() || !!emailError}>
                Tambah Admin
              </Button>
            </Group>
          </Alert>
        </div>
      </Group>

      <div>
        {admins.length === 0 && <Text>No admin users found.</Text>}
        {/* Super Admin table - separate, minimal entries */}
        <Title order={5} mt="lg" mb="sm">Super Admin</Title>
        <Card shadow="sm" padding="md" radius="md" withBorder>
          {admins.filter(a => a.role === 'super_admin').length === 0 ? (
            <Text c="dimmed" ta="center">(none)</Text>
          ) : (
            <Table striped highlightOnHover>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Nama</Table.Th>
                  <Table.Th>Email</Table.Th>
                  <Table.Th>Role</Table.Th>
                  <Table.Th>Aktif</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                {admins.filter(a => a.role === 'super_admin').map((a) => (
                  <Table.Tr key={a.id}>
                    <Table.Td>
                      <Text fw={600}>{a.nama || a.email}</Text>
                    </Table.Td>
                    <Table.Td>{a.email}</Table.Td>
                    <Table.Td>
                      <Badge color="teal" variant="filled">{a.role}</Badge>
                    </Table.Td>
                    <Table.Td>
                      <Badge color={a.is_active ? 'green' : 'gray'} variant="light">{a.is_active ? 'Aktif' : 'Nonaktif'}</Badge>
                    </Table.Td>
                  </Table.Tr>
                ))}
              </Table.Tbody>
            </Table>
          )}
        </Card>

        {/* Admin Biasa with Search and Pagination */}

        <div style={{ marginTop: '1.5rem' }}>
          <SearchablePaginatedList
            data={admins.filter(a => a.role !== 'super_admin')}
            searchTitle="Cari Admin"
            searchPlaceholder="Cari admin berdasarkan nama atau email..."
            getSearchableText={(admin) => `${admin.nama} ${admin.email}`.toLowerCase()}
            isActive={(admin) => admin.is_active}
            activeSection={{
              title: 'Admin Aktif',
              emptyText: 'Tidak ada admin aktif',
              render: (items) => (
                <Table striped highlightOnHover>
                  <Table.Thead>
                    <Table.Tr>
                      <Table.Th>Nama</Table.Th>
                      <Table.Th>Email</Table.Th>
                      <Table.Th>Role</Table.Th>
                      <Table.Th>Status</Table.Th>
                      <Table.Th w={120}>Aksi</Table.Th>
                    </Table.Tr>
                  </Table.Thead>
                  <Table.Tbody>
                    {items.map((record) => (
                      <Table.Tr key={record.id}>
                        <Table.Td><Text fw={600}>{record.nama || record.email}</Text></Table.Td>
                        <Table.Td>{record.email}</Table.Td>
                        <Table.Td><Badge color="blue" variant="filled">{record.role}</Badge></Table.Td>
                        <Table.Td><Badge color="green" variant="light">Aktif</Badge></Table.Td>
                        <Table.Td onClick={(e) => e.stopPropagation()}>
                          <Menu withArrow position="left" shadow="sm">
                            <Menu.Target>
                              <ActionIcon variant="subtle" color="blue">
                                <IconEdit size={16} />
                              </ActionIcon>
                            </Menu.Target>
                            <Menu.Dropdown>
                              <Menu.Item
                                color="yellow"
                                onClick={() => {
                                  setResetTarget({ id: record.id, email: record.email })
                                  setResetConfirmOpen(true)
                                }}
                              >
                                Kirim email Reset Password
                              </Menu.Item>
                              <Menu.Item
                                color="red"
                                onClick={() => {
                                  setToggleTarget({ id: record.id, email: record.email, targetActive: false })
                                  setToggleModalOpen(true)
                                }}
                              >
                                Nonaktifkan Admin
                              </Menu.Item>
                            </Menu.Dropdown>
                          </Menu>
                        </Table.Td>
                      </Table.Tr>
                    ))}
                  </Table.Tbody>
                </Table>
              ),
            }}
            inactiveSection={{
              title: 'Admin Nonaktif',
              emptyText: 'Tidak ada admin nonaktif',
              render: (items) => (
                <Table striped highlightOnHover>
                  <Table.Thead>
                    <Table.Tr>
                      <Table.Th>Nama</Table.Th>
                      <Table.Th>Email</Table.Th>
                      <Table.Th>Role</Table.Th>
                      <Table.Th>Status</Table.Th>
                      <Table.Th w={120}>Aksi</Table.Th>
                    </Table.Tr>
                  </Table.Thead>
                  <Table.Tbody>
                    {items.map((record) => (
                      <Table.Tr key={record.id}>
                        <Table.Td><Text fw={600}>{record.nama || record.email}</Text></Table.Td>
                        <Table.Td>{record.email}</Table.Td>
                        <Table.Td><Badge color="blue" variant="filled">{record.role}</Badge></Table.Td>
                        <Table.Td><Badge color="gray" variant="light">Nonaktif</Badge></Table.Td>
                        <Table.Td onClick={(e) => e.stopPropagation()}>
                          <Menu withArrow position="left" shadow="sm">
                            <Menu.Target>
                              <ActionIcon variant="subtle" color="blue">
                                <IconEdit size={16} />
                              </ActionIcon>
                            </Menu.Target>
                            <Menu.Dropdown>
                              <Menu.Item
                                color="yellow"
                                onClick={() => {
                                  setResetTarget({ id: record.id, email: record.email })
                                  setResetConfirmOpen(true)
                                }}
                              >
                                Kirim email Reset Password
                              </Menu.Item>
                              <Menu.Item
                                color="green"
                                onClick={() => {
                                  setToggleTarget({ id: record.id, email: record.email, targetActive: true })
                                  setToggleModalOpen(true)
                                }}
                              >
                                Aktifkan Admin
                              </Menu.Item>
                            </Menu.Dropdown>
                          </Menu>
                        </Table.Td>
                      </Table.Tr>
                    ))}
                  </Table.Tbody>
                </Table>
              ),
            }}
          />
        </div>
      </div>

      <Modal opened={modalOpen} onClose={() => setModalOpen(false)} title="Temporary credentials" closeOnClickOutside={false} closeOnEscape={false}>
        {creds ? (
          <Stack>
            <div>
              <Text size="sm">Email (save now, shown only once)</Text>
              <Group >
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
              <Text size="sm">Password (save now)</Text>
              <Group >
                <Text fw={600}>{creds.password}</Text>
                <CopyButton value={creds.password} timeout={2000}>
                  {({ copied, copy }) => (
                    <ActionIcon color={copied ? 'teal' : 'blue'} onClick={copy}>
                      <IconCopy size={16} />
                    </ActionIcon>
                  )}
                </CopyButton>
              </Group>
            </div>

            <Text size="sm">Tell the admin to change password on first login.</Text>
            <Button onClick={() => setModalOpen(false)}>Done</Button>
          </Stack>
        ) : (
          <Text>Loading...</Text>
        )}
      </Modal>

      <Modal opened={confirmOpen} onClose={() => setConfirmOpen(false)} title="Konfirmasi pembuatan admin">
        <Stack>
          <Text>Anda akan membuat admin baru dengan email <b>{pendingBody?.email}</b> dan username <b>{pendingBody?.nama}</b>.</Text>
          <Text size="sm">Keterangan: kredensial sementara akan ditampilkan sekali setelah pembuatan.</Text>
          <Text size="sm" style={{ marginTop: 6, fontWeight: 600 }}>Pemberitahuan — Apa yang dapat dan tidak dapat dilakukan admin baru:</Text>
          <Text size="sm">• Dapat: masuk menggunakan email dan password sementara; mengelola konten sesuai izin role; memperbarui profil sendiri.</Text>
          <Text size="sm">• Tidak dapat: membuat/menjadikan user lain sebagai super_admin; mengakses kunci atau operasi level server (service role); melakukan tindakan yang hanya boleh dilakukan oleh super_admin.</Text>
          <Group>
            <Button variant="default" onClick={() => setConfirmOpen(false)}>Batal</Button>
            <Button color="red" onClick={async () => {
              if (!pendingBody) return
              setConfirmOpen(false)
              await performCreateAdmin(pendingBody)
              setPendingBody(null)
            }}>Ya, buat</Button>
          </Group>
        </Stack>
      </Modal>

      <Modal
        opened={toggleModalOpen}
        onClose={() => {
          setToggleModalOpen(false)
          setToggleTarget(null)
        }}
        title={toggleTarget?.targetActive ? 'Konfirmasi Aktifkan Admin' : 'Konfirmasi Nonaktifkan Admin'}
      >
        <Stack>
          <Text>
            {toggleTarget?.targetActive
              ? `Anda akan mengaktifkan kembali admin ${toggleTarget?.email}.`
              : `Anda akan menonaktifkan admin ${toggleTarget?.email}.`}
          </Text>
          <Group>
            <Button variant="default" onClick={() => { setToggleModalOpen(false); setToggleTarget(null) }}>Batal</Button>
            <Button
              color={toggleTarget?.targetActive ? 'green' : 'red'}
              loading={toggleLoading}
              onClick={async () => {
                if (!toggleTarget) return
                setToggleModalOpen(false)
                await toggleActiveAdmin(toggleTarget.id, toggleTarget.targetActive)
              }}
            >
              {toggleTarget?.targetActive ? 'Aktifkan' : 'Nonaktifkan'}
            </Button>
          </Group>
        </Stack>
      </Modal>

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
                // reuse shared helper
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
    </div>
  )
}
