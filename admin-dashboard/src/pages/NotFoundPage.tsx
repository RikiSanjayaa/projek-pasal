import { useNavigate } from 'react-router-dom'
import {
  Container,
  Title,
  Text,
  Button,
  Stack,
  Group,
  Card,
  Center,
} from '@mantine/core'
import { IconHome, IconArrowLeft } from '@tabler/icons-react'

export function NotFoundPage() {
  const navigate = useNavigate()

  return (
    <Container size="md" py="xl">
      <Center h="70vh">
        <Card shadow="sm" padding="xl" radius="md" withBorder style={{ maxWidth: 500 }}>
          <Stack gap="lg" align="center">
            <div style={{ textAlign: 'center' }}>
              <Title order={1} size={120} c="blue" style={{ lineHeight: 1 }}>
                404
              </Title>
              <Title order={2} c="dimmed" mt="md">
                Halaman Tidak Ditemukan
              </Title>
              <Text c="dimmed" mt="sm" size="lg">
                Maaf, halaman yang Anda cari tidak ada atau telah dipindahkan.
              </Text>
            </div>

            <Group gap="sm" mt="lg">
              <Button
                variant="light"
                leftSection={<IconArrowLeft size={18} />}
                onClick={() => navigate(-1)}
              >
                Kembali
              </Button>
              <Button
                leftSection={<IconHome size={18} />}
                onClick={() => navigate('/')}
              >
                Beranda
              </Button>
            </Group>
          </Stack>
        </Card>
      </Center>
    </Container>
  )
}