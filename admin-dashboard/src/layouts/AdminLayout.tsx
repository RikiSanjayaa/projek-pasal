import { useEffect, type ComponentType } from 'react'
import { Outlet, useLocation, useNavigate } from 'react-router-dom'
import {
  ActionIcon,
  AppShell,
  Avatar,
  Badge,
  Box,
  Burger,
  Button,
  Divider,
  Drawer,
  Group,
  Menu,
  Modal,
  NavLink,
  ScrollArea,
  Stack,
  Text,
  Tooltip,
  UnstyledButton,
  useMantineColorScheme,
  type MantineColorScheme,
} from '@mantine/core'
import { showNotification } from '@mantine/notifications'
import { useDisclosure, useLocalStorage, useMediaQuery } from '@mantine/hooks'
import {
  IconBook,
  IconCheck,
  IconChecklist,
  IconDeviceDesktop,
  IconHistory,
  IconHome,
  IconKey,
  IconLayoutSidebarLeftCollapse,
  IconLayoutSidebarLeftExpand,
  IconLogout,
  IconMoon,
  IconScale,
  IconShieldCheck,
  IconSparkles,
  IconSun,
  IconUpload,
  IconUser,
  IconUsers,
} from '@tabler/icons-react'
import { useQuery } from '@tanstack/react-query'
import { useAuth } from '@/contexts/AuthContext'
import { requestPasswordRecovery } from '@/lib/auth'
import { pendingVerificationCount, verificationSummaryQuery } from '@/lib/verification'
import AdminActiveAlert from '@/components/AdminActiveAlert'
import { AppLogo } from '@/components/AppLogo'

interface NavItem {
  label: string
  icon: ComponentType<{ size?: number | string }>
  path: string
  superAdminOnly?: boolean
  /** Badge jumlah di samping label (contoh: pasal menunggu verifikasi). */
  count?: 'verification'
}

interface NavGroup {
  label: string | null
  items: NavItem[]
}

const NAV_GROUPS: NavGroup[] = [
  { label: null, items: [{ label: 'Dashboard', icon: IconHome, path: '/' }] },
  {
    label: 'Konten hukum',
    items: [
      { label: 'Pasal', icon: IconScale, path: '/pasal' },
      { label: 'Verifikasi', icon: IconChecklist, path: '/verifikasi', count: 'verification' },
      { label: 'Undang-Undang', icon: IconBook, path: '/undang-undang' },
      { label: 'Import Data', icon: IconUpload, path: '/bulk-import' },
      { label: 'Smart Search', icon: IconSparkles, path: '/smart-search', superAdminOnly: true },
    ],
  },
  {
    label: 'Pengguna',
    items: [
      { label: 'Pengguna Mobile', icon: IconUsers, path: '/manage-users' },
      { label: 'Akun Admin', icon: IconShieldCheck, path: '/manage-admin', superAdminOnly: true },
    ],
  },
  { label: 'Sistem', items: [{ label: 'Audit Log', icon: IconHistory, path: '/audit-log' }] },
]

const THEME_OPTIONS: { value: MantineColorScheme; label: string; icon: typeof IconSun }[] = [
  { value: 'light', label: 'Terang', icon: IconSun },
  { value: 'dark', label: 'Gelap', icon: IconMoon },
  { value: 'auto', label: 'Ikuti sistem', icon: IconDeviceDesktop },
]

function isActivePath(pathname: string, path: string) {
  return path === '/' ? pathname === '/' : pathname === path || pathname.startsWith(`${path}/`)
}

function Brand() {
  return (
    <Group gap="xs" wrap="nowrap">
      <AppLogo size={32} />
      <Text fw={700} size="lg" style={{ whiteSpace: 'nowrap' }}>
        CariPasal
      </Text>
      <Badge size="sm" variant="light">
        Admin
      </Badge>
    </Group>
  )
}

export function AdminLayout() {
  const [drawerOpened, drawer] = useDisclosure()
  const [collapsed, setCollapsed] = useLocalStorage({ key: 'caripasal_sidebar_collapsed', defaultValue: false })
  const [resetModalOpened, resetModal] = useDisclosure(false)
  const { colorScheme, setColorScheme } = useMantineColorScheme()
  const { adminUser, signOut } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const isMobile = useMediaQuery('(max-width: 768px)')
  const isSuperAdmin = adminUser?.role === 'super_admin'

  const { data: verificationSummary } = useQuery(verificationSummaryQuery)
  const counts = {
    verification: pendingVerificationCount(verificationSummary),
  }

  useEffect(() => {
    if (!isMobile && drawerOpened) drawer.close()
  }, [isMobile, drawerOpened, drawer])

  const groups = NAV_GROUPS.map((group) => ({
    ...group,
    items: group.items.filter((item) => !item.superAdminOnly || isSuperAdmin),
  })).filter((group) => group.items.length > 0)

  const go = (path: string) => {
    navigate(path)
    drawer.close()
  }

  const handleLogout = async () => {
    await signOut()
    navigate('/login')
  }

  const handleRequestPasswordReset = async () => {
    const email = adminUser?.email
    if (!email) {
      showNotification({ title: 'Email tidak tersedia', message: 'Email akun tidak ditemukan.', color: 'yellow' })
      return
    }
    try {
      await requestPasswordRecovery(email)
      showNotification({ title: 'Terkirim', message: 'Permintaan reset password terkirim. Periksa email untuk instruksi.', color: 'green' })
      resetModal.close()
    } catch (err: unknown) {
      showNotification({ title: 'Gagal', message: err instanceof Error ? err.message : String(err), color: 'red' })
    }
  }

  const renderCount = (item: NavItem) => {
    const value = item.count ? counts[item.count] : 0
    return value > 0 ? (
      <Badge size="sm" variant="light" color="yellow">
        {value}
      </Badge>
    ) : null
  }

  const fullNav = (
    <Stack gap="md">
      {groups.map((group) => (
        <Box key={group.label ?? 'utama'}>
          {group.label && (
            <Text size="xs" fw={700} c="dimmed" tt="uppercase" px="sm" mb={4} style={{ letterSpacing: 0.4 }}>
              {group.label}
            </Text>
          )}
          {group.items.map((item) => (
            <NavLink
              key={item.path}
              label={item.label}
              leftSection={<item.icon size={18} />}
              rightSection={renderCount(item)}
              active={isActivePath(location.pathname, item.path)}
              onClick={() => go(item.path)}
              mb={2}
              style={{ borderRadius: 'var(--mantine-radius-md)' }}
            />
          ))}
        </Box>
      ))}
    </Stack>
  )

  const compactNav = (
    <Stack gap={4} align="center">
      {groups.map((group, index) => (
        <Stack key={group.label ?? 'utama'} gap={4} align="center" w="100%">
          {index > 0 && <Divider w="60%" my={4} />}
          {group.items.map((item) => {
            const active = isActivePath(location.pathname, item.path)
            const count = item.count ? counts[item.count] : 0
            return (
              <Tooltip key={item.path} label={count > 0 ? `${item.label} (${count})` : item.label} position="right">
                <ActionIcon
                  variant={active ? 'light' : 'subtle'}
                  color={active ? 'blue' : 'gray'}
                  size={42}
                  aria-label={item.label}
                  onClick={() => go(item.path)}
                  pos="relative"
                >
                  <item.icon size={20} />
                  {count > 0 && (
                    <Box
                      pos="absolute"
                      top={7}
                      right={7}
                      w={8}
                      h={8}
                      bg="yellow.6"
                      style={{ borderRadius: '50%' }}
                    />
                  )}
                </ActionIcon>
              </Tooltip>
            )
          })}
        </Stack>
      ))}
    </Stack>
  )

  const ThemeIcon = THEME_OPTIONS.find((option) => option.value === colorScheme)?.icon ?? IconDeviceDesktop

  return (
    <AppShell
      header={{ height: 60 }}
      navbar={{ width: collapsed ? 72 : 260, breakpoint: 'sm', collapsed: { mobile: true } }}
      padding={isMobile ? 'xs' : 'md'}
    >
      <AppShell.Header>
        <Group h="100%" px="md" justify="space-between" wrap="nowrap">
          <Group gap="sm" wrap="nowrap" style={{ minWidth: 0 }}>
            <Burger opened={drawerOpened} onClick={drawer.toggle} hiddenFrom="sm" size="sm" aria-label="Buka menu" />
            <Tooltip label={collapsed ? 'Lebarkan sidebar' : 'Ciutkan sidebar'}>
              <ActionIcon
                variant="subtle"
                color="gray"
                size="lg"
                onClick={() => setCollapsed((value) => !value)}
                visibleFrom="sm"
                aria-label={collapsed ? 'Lebarkan sidebar' : 'Ciutkan sidebar'}
              >
                {collapsed ? <IconLayoutSidebarLeftExpand size={20} /> : <IconLayoutSidebarLeftCollapse size={20} />}
              </ActionIcon>
            </Tooltip>
            <UnstyledButton onClick={() => navigate('/')} aria-label="Ke dashboard">
              <Brand />
            </UnstyledButton>
          </Group>

          <Group gap="xs" wrap="nowrap">
            <Menu shadow="sm" position="bottom-end">
              <Menu.Target>
                <ActionIcon variant="default" size="lg" aria-label="Tema tampilan">
                  <ThemeIcon size={18} />
                </ActionIcon>
              </Menu.Target>
              <Menu.Dropdown>
                <Menu.Label>Tema</Menu.Label>
                {THEME_OPTIONS.map((option) => (
                  <Menu.Item
                    key={option.value}
                    leftSection={<option.icon size={14} />}
                    rightSection={colorScheme === option.value ? <IconCheck size={14} /> : null}
                    onClick={() => setColorScheme(option.value)}
                  >
                    {option.label}
                  </Menu.Item>
                ))}
              </Menu.Dropdown>
            </Menu>

            <Menu shadow="sm" position="bottom-end">
              <Menu.Target>
                <UnstyledButton aria-label="Menu akun">
                  <Group gap="xs" wrap="nowrap">
                    <Avatar color="blue" radius="xl" size="sm">
                      {adminUser?.nama?.charAt(0).toUpperCase() || 'A'}
                    </Avatar>
                    <Box visibleFrom="sm">
                      <Text size="sm" fw={500} lh={1.2}>
                        {adminUser?.nama || 'Admin'}
                      </Text>
                      <Text size="xs" c="dimmed" lh={1.2}>
                        {isSuperAdmin ? 'Super admin' : 'Admin'}
                      </Text>
                    </Box>
                  </Group>
                </UnstyledButton>
              </Menu.Target>
              <Menu.Dropdown>
                <Menu.Label>Akun</Menu.Label>
                <Menu.Item leftSection={<IconUser size={14} />} disabled style={{ cursor: 'default', opacity: 1 }}>
                  {adminUser?.email}
                </Menu.Item>
                <Menu.Item leftSection={<IconKey size={14} />} onClick={resetModal.open}>
                  Reset Password
                </Menu.Item>
                <Divider />
                <Menu.Item color="red" leftSection={<IconLogout size={14} />} onClick={handleLogout}>
                  Keluar
                </Menu.Item>
              </Menu.Dropdown>
            </Menu>
          </Group>
        </Group>
      </AppShell.Header>

      <AppShell.Navbar p={collapsed ? 'xs' : 'sm'}>
        <AppShell.Section grow component={ScrollArea} scrollbarSize={6}>
          {collapsed ? compactNav : fullNav}
        </AppShell.Section>
      </AppShell.Navbar>

      <AppShell.Main>
        <AdminActiveAlert />
        <Outlet />
      </AppShell.Main>

      <Drawer opened={drawerOpened && !!isMobile} onClose={drawer.close} size={280} padding="md" title={<Brand />}>
        {fullNav}
      </Drawer>

      <Modal opened={resetModalOpened} onClose={resetModal.close} title="Konfirmasi Reset Password" centered>
        <Text>
          Link reset password akan dikirim ke email{' '}
          <Text span fw={500}>
            {adminUser?.email}
          </Text>
          .
        </Text>
        <Text size="sm" c="dimmed" mt="sm">
          Pastikan email tersebut dapat diakses untuk menerima instruksi reset password.
        </Text>
        <Group justify="flex-end" mt="xl">
          <Button variant="default" onClick={resetModal.close}>
            Batal
          </Button>
          <Button onClick={handleRequestPasswordReset}>Kirim Link Reset</Button>
        </Group>
      </Modal>
    </AppShell>
  )
}
