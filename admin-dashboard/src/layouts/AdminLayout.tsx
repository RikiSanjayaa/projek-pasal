import React from 'react'
import { Outlet, useNavigate, useLocation } from 'react-router-dom'
import {
  AppShell,
  Burger,
  Group,
  NavLink,
  Title,
  ActionIcon,
  useMantineColorScheme,
  Menu,
  Text,
  Avatar,
  Divider,
  Box,
  Transition,
  Drawer,
} from '@mantine/core'
import { showNotification } from '@mantine/notifications'
import { useDisclosure, useMediaQuery } from '@mantine/hooks'
import {
  IconHome,
  IconScale,
  IconBook,
  IconUpload,
  IconHistory,
  IconSun,
  IconMoon,
  IconLogout,
  IconUser,
  IconKey,
  IconChevronLeft,
  IconChevronRight,
  IconShieldCheck,
} from '@tabler/icons-react'
import { useAuth } from '@/contexts/AuthContext'
import { requestPasswordRecovery } from '@/lib/auth'
import AdminActiveAlert from '@/components/AdminActiveAlert'

const navItems = [
  { label: 'Dashboard', icon: IconHome, path: '/' },
  { label: 'Pasal', icon: IconScale, path: '/pasal' },
  { label: 'Undang-Undang', icon: IconBook, path: '/undang-undang' },
  { label: 'Import Data', icon: IconUpload, path: '/bulk-import' },
  { label: 'Audit Log', icon: IconHistory, path: '/audit-log' },
]

export function AdminLayout() {
  const [opened, { toggle, close }] = useDisclosure()
  const [sidebarCollapsed, { toggle: toggleSidebar }] = useDisclosure(false)
  const { colorScheme, toggleColorScheme } = useMantineColorScheme()
  const { adminUser, signOut } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const isMobile = useMediaQuery('(max-width: 768px)')

  // Close drawer when switching to desktop
  React.useEffect(() => {
    if (!isMobile && opened) {
      close()
    }
  }, [isMobile, opened, close])

  const handleLogout = async () => {
    await signOut()
    navigate('/login')
  }

  const handleRequestPasswordReset = async () => {
    const email = adminUser?.email
    if (!email) {
      showNotification({ title: 'Email tidak tersedia', message: 'Email tidak tersedia', color: 'yellow' })
      return
    }
    try {
      await requestPasswordRecovery(email)
      showNotification({ title: 'Terkirim', message: 'Permintaan reset password terkirim. Periksa email untuk instruksi.', color: 'green' })
    } catch (err: any) {
      console.error('Failed to request password reset', err)
      showNotification({ title: 'Error', message: String(err?.message || err), color: 'red' })
    }
  }

  return (
    <AppShell
      header={{ height: 60 }}
      navbar={{
        width: sidebarCollapsed ? 70 : 280,
        breakpoint: 'sm',
        collapsed: { mobile: true },
      }}
      padding="md"
    >
      <AppShell.Header>
        <Group h="100%" px="md" justify="space-between">
          <Group>
            <Burger opened={opened} onClick={toggle} hiddenFrom="sm" size="sm" />
            <ActionIcon
              variant="subtle"
              size="lg"
              onClick={toggleSidebar}
              visibleFrom="sm"
              aria-label="Toggle sidebar"
            >
              {sidebarCollapsed ? <IconChevronRight size={18} /> : <IconChevronLeft size={18} />}
            </ActionIcon>
            <Title order={3} c="blue">
              CariPasal Admin
            </Title>
          </Group>

          <Group>
            <ActionIcon
              variant="default"
              size="lg"
              onClick={() => toggleColorScheme()}
              aria-label="Toggle color scheme"
            >
              {colorScheme === 'dark' ? <IconSun size={18} /> : <IconMoon size={18} />}
            </ActionIcon>

            <Menu shadow="md">
              <Menu.Target>
                <Box style={{ cursor: 'pointer' }}>
                  <Group gap="xs">
                    <Avatar color="blue" radius="xl" size="sm">
                      {adminUser?.nama?.charAt(0).toUpperCase() || 'A'}
                    </Avatar>
                    <Text size="sm" fw={500} visibleFrom="sm">
                      {adminUser?.nama || 'Admin'}
                    </Text>
                  </Group>
                </Box>
              </Menu.Target>

              <Menu.Dropdown>
                <Menu.Label>Akun</Menu.Label>
                <Menu.Item
                  leftSection={<IconUser size={14} />}
                  // keep it non-interactive / not hoverable while preserving text color
                  disabled
                  style={{
                    cursor: 'default',
                    '&[dataDisabled]': { opacity: 1 },
                    '&:hover': { backgroundColor: 'transparent' },
                  }}
                >
                  {adminUser?.email}
                </Menu.Item>
                <Menu.Item leftSection={<IconKey size={14} />} onClick={handleRequestPasswordReset}>
                  Reset Password
                </Menu.Item>
                <Divider />
                <Menu.Item
                  color="red"
                  leftSection={<IconLogout size={14} />}
                  onClick={handleLogout}
                >
                  Keluar
                </Menu.Item>
              </Menu.Dropdown>
            </Menu>
          </Group>
        </Group>
      </AppShell.Header>

      <AppShell.Navbar p={sidebarCollapsed ? "xs" : "md"}>
        <Group justify="space-between" mb="sm" wrap="nowrap">
          {!sidebarCollapsed && (
            <Text size="xs" fw={500} c="dimmed">
              MENU
            </Text>
          )}
        </Group>

        <Box style={{ position: 'relative', minHeight: '200px' }}>
          <Transition
            mounted={!sidebarCollapsed}
            transition="fade"
            duration={300}
            timingFunction="ease-in-out"
          >
            {(styles) => (
              <Box style={{ ...styles, position: 'absolute', width: '100%' }}>
                {navItems.map((item) => (
                  <NavLink
                    key={item.path}
                    label={item.label}
                    leftSection={<item.icon size={18} />}
                    active={location.pathname === item.path}
                    onClick={() => {
                      navigate(item.path)
                      toggle()
                    }}
                    mb={4}
                    style={{ borderRadius: 8 }}
                  />
                ))}
                {adminUser?.role === 'super_admin' && (
                  <NavLink
                    label="Manage Admin"
                    leftSection={<IconShieldCheck size={18} />}
                    active={location.pathname === '/manage-admin'}
                    onClick={() => {
                      navigate('/manage-admin')
                      toggle()
                    }}
                    mb={4}
                    style={{ borderRadius: 8 }}
                  />
                )}
              </Box>
            )}
          </Transition>

          <Transition
            mounted={sidebarCollapsed}
            transition="fade"
            duration={300}
            timingFunction="ease-in-out"
          >
            {(styles) => (
              <Box style={{ ...styles, position: 'absolute', width: '100%' }}>
                {navItems.map((item) => {
                  const isActive = location.pathname === item.path
                  const isDark = colorScheme === 'dark'

                  return (
                    <Box
                      key={item.path}
                      component="a"
                      href="#"
                      onClick={(e) => {
                        e.preventDefault()
                        navigate(item.path)
                        toggle()
                      }}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        padding: '12px 12px',
                        minHeight: '48px',
                        borderRadius: '8px',
                        marginBottom: '4px',
                        textDecoration: 'none',
                        color: isActive
                          ? (isDark ? '#6BBAF9' : '#6BBAF9') // blue-6 for both themes
                          : (isDark ? '#a6a7ab' : '#495057'), // gray-6 for dark, gray-7 for light
                        backgroundColor: isActive
                          ? (isDark ? 'rgba(34, 139, 230, 0.1)' : 'rgba(34, 139, 230, 0.1)') // subtle blue background
                          : 'transparent',
                        cursor: 'pointer',
                        transition: 'all 0.1s ease',
                      }}
                      onMouseEnter={(e) => {
                        if (!isActive) {
                          e.currentTarget.style.backgroundColor = isDark
                            ? 'rgba(255, 255, 255, 0.05)'
                            : 'rgba(0, 0, 0, 0.05)'
                        }
                      }}
                      onMouseLeave={(e) => {
                        if (!isActive) {
                          e.currentTarget.style.backgroundColor = 'transparent'
                        }
                      }}
                      title={item.label}
                    >
                      <item.icon size={18} />
                    </Box>
                  )
                })}
                {sidebarCollapsed && adminUser?.role === 'super_admin' && (() => {
                  const isActive = location.pathname === '/manage-admin'
                  const isDark = colorScheme === 'dark'

                  return (
                    <Box
                      key="/manage-admin"
                      component="a"
                      href="#"
                      onClick={(e) => {
                        e.preventDefault()
                        navigate('/manage-admin')
                        toggle()
                      }}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        padding: '12px 12px',
                        minHeight: '48px',
                        borderRadius: '8px',
                        marginBottom: '4px',
                        textDecoration: 'none',
                        color: isActive
                          ? (isDark ? '#6BBAF9' : '#6BBAF9') // blue-6 for both themes
                          : (isDark ? '#a6a7ab' : '#495057'), // gray-6 for dark, gray-7 for light
                        backgroundColor: isActive
                          ? (isDark ? 'rgba(34, 139, 230, 0.1)' : 'rgba(34, 139, 230, 0.1)') // subtle blue background
                          : 'transparent',
                        cursor: 'pointer',
                        transition: 'all 0.1s ease',
                      }}
                      onMouseEnter={(e) => {
                        if (!isActive) {
                          e.currentTarget.style.backgroundColor = isDark
                            ? 'rgba(255, 255, 255, 0.05)'
                            : 'rgba(0, 0, 0, 0.05)'
                        }
                      }}
                      onMouseLeave={(e) => {
                        if (!isActive) {
                          e.currentTarget.style.backgroundColor = 'transparent'
                        }
                      }}
                      title="Manage Admin"
                    >
                      <IconShieldCheck size={18} />
                    </Box>
                  )
                })()}
              </Box>
            )}
          </Transition>
        </Box>
      </AppShell.Navbar>

      <AppShell.Main>
        <AdminActiveAlert />
        <Outlet />
      </AppShell.Main>

      {opened && isMobile && (
        <Drawer
          opened={opened}
          onClose={toggle}
          size="280px"
          padding="md"
          title="Menu"
        >
          <Box mt="md">
            {navItems.map((item) => (
              <NavLink
                key={item.path}
                label={item.label}
                leftSection={<item.icon size={18} />}
                active={location.pathname === item.path}
                onClick={() => {
                  navigate(item.path)
                  toggle()
                }}
                mb={4}
                style={{ borderRadius: 8 }}
              />
            ))}
            {adminUser?.role === 'super_admin' && (
              <NavLink
                label="Manage Admin"
                leftSection={<IconShieldCheck size={18} />}
                active={location.pathname === '/manage-admin'}
                onClick={() => {
                  navigate('/manage-admin')
                  toggle()
                }}
                mb={4}
                style={{ borderRadius: 8 }}
              />
            )}
          </Box>
        </Drawer>
      )}
    </AppShell>
  )
}
