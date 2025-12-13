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
} from '@mantine/core'
import { useDisclosure } from '@mantine/hooks'
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
} from '@tabler/icons-react'
import { useAuth } from '@/contexts/AuthContext'

const navItems = [
  { label: 'Dashboard', icon: IconHome, path: '/' },
  { label: 'Pasal', icon: IconScale, path: '/pasal' },
  { label: 'Undang-Undang', icon: IconBook, path: '/undang-undang' },
  { label: 'Import Data', icon: IconUpload, path: '/bulk-import' },
  { label: 'Audit Log', icon: IconHistory, path: '/audit-log' },
]

export function AdminLayout() {
  const [opened, { toggle }] = useDisclosure()
  const { colorScheme, toggleColorScheme } = useMantineColorScheme()
  const { adminUser, signOut } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()

  const handleLogout = async () => {
    await signOut()
    navigate('/login')
  }

  return (
    <AppShell
      header={{ height: 60 }}
      navbar={{
        width: 280,
        breakpoint: 'sm',
        collapsed: { mobile: !opened },
      }}
      padding="md"
    >
      <AppShell.Header>
        <Group h="100%" px="md" justify="space-between">
          <Group>
            <Burger opened={opened} onClick={toggle} hiddenFrom="sm" size="sm" />
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

            <Menu shadow="md" width={200}>
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
                <Menu.Item leftSection={<IconUser size={14} />}>
                  {adminUser?.email}
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

      <AppShell.Navbar p="md">
        <Text size="xs" fw={500} c="dimmed" mb="sm">
          MENU
        </Text>
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
      </AppShell.Navbar>

      <AppShell.Main>
        <Outlet />
      </AppShell.Main>
    </AppShell>
  )
}
