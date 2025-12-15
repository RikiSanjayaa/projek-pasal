import { useParams, useNavigate } from 'react-router-dom'
import {
  Title,
  Text,
  Stack,
  Card,
  Group,
  Button,
  Badge,
  Grid,
  Loader,
  Alert,
} from '@mantine/core'
import { useQuery } from '@tanstack/react-query'
import { IconArrowLeft, IconEdit, IconTrash } from '@tabler/icons-react'
import { supabase } from '@/lib/supabase'
import { PasalLinksSidebar } from '@/components/PasalLinksSidebar'
import type { PasalWithUndangUndang } from '@/lib/database.types'

export function PasalDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

  if (!id) {
    return (
      <Stack gap="lg">
        <Group>
          <Button
            variant="subtle"
            leftSection={<IconArrowLeft size={18} />}
            onClick={() => navigate('/pasal')}
          >
            Kembali
          </Button>
        </Group>
        <Card shadow="sm" padding="lg" radius="md" withBorder>
          <Text ta="center" c="dimmed">ID pasal tidak valid</Text>
        </Card>
      </Stack>
    )
  }

  // Fetch pasal detail (including deleted ones)
  const { data: pasal, isLoading } = useQuery({
    queryKey: ['pasal', 'detail', id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('pasal')
        .select('*, undang_undang(*)')
        .eq('id', id)
        .single()

      if (error) throw error
      return data as PasalWithUndangUndang
    },
  })

  if (isLoading) {
    return (
      <Stack gap="lg" align="center" justify="center" h="50vh">
        <Loader size="lg" />
        <Text c="dimmed">Memuat detail pasal...</Text>
      </Stack>
    )
  }

  if (!pasal) {
    return (
      <Stack gap="lg">
        <Group>
          <Button
            variant="subtle"
            leftSection={<IconArrowLeft size={18} />}
            onClick={() => navigate('/pasal')}
          >
            Kembali
          </Button>
        </Group>
        <Card shadow="sm" padding="lg" radius="md" withBorder>
          <Text ta="center" c="dimmed">Pasal tidak ditemukan</Text>
        </Card>
      </Stack>
    )
  }

  return (
    <Stack gap="lg">
      <Group justify="space-between" align="center">
        <Group>
          <Button
            variant="subtle"
            leftSection={<IconArrowLeft size={18} />}
            onClick={() => navigate('/pasal')}
          >
            Kembali
          </Button>
        </Group>
        {pasal.is_active === true && (
          <Button
            leftSection={<IconEdit size={16} />}
            onClick={() => navigate(`/pasal/${pasal.id}/edit`)}
          >
            Edit Pasal
          </Button>
        )}
      </Group>
      <div>
        <Title order={2}>
          <Group gap="xs">
            <Badge color="blue" variant="light">
              {pasal.undang_undang?.kode}
            </Badge>
            Pasal {pasal.nomor}
          </Group>
        </Title>
        <Text c="dimmed">Detail pasal</Text>
      </div>

      {pasal.is_active === false && (
        <Alert icon={<IconTrash size={16} />} color="red" variant="light">
          <Text fw={500}>Pasal ini telah dihapus</Text>
          <Text size="sm">
            Pasal ini sudah tidak aktif dan akan dihapus permanen dalam waktu dekat.
            Anda masih dapat melihat detailnya, namun tidak dapat mengeditnya.
          </Text>
        </Alert>
      )}

      <Grid>
        <Grid.Col span={{ base: 12, md: 8 }}>
          <Card shadow="sm" padding="lg" radius="md" withBorder>
            <Stack gap="md">
              {pasal.judul && (
                <div>
                  <Text size="sm" c="dimmed" mb={4}>Judul</Text>
                  <Text fw={500}>{pasal.judul}</Text>
                </div>
              )}

              <div>
                <Text size="sm" c="dimmed" mb={4}>Isi Pasal</Text>
                <Card withBorder padding="sm" bg="var(--mantine-color-default-hover)">
                  <Text style={{ whiteSpace: 'pre-wrap' }}>{pasal.isi}</Text>
                </Card>
              </div>

              {pasal.penjelasan && (
                <div>
                  <Text size="sm" c="dimmed" mb={4}>Penjelasan</Text>
                  <Card withBorder padding="sm" bg="var(--mantine-color-blue-light)">
                    <Text size="sm" style={{ whiteSpace: 'pre-wrap' }}>{pasal.penjelasan}</Text>
                  </Card>
                </div>
              )}

              {pasal.keywords && pasal.keywords.length > 0 && (
                <div>
                  <Text size="sm" c="dimmed" mb={4}>Keywords</Text>
                  <Group gap={4}>
                    {pasal.keywords.map((kw, idx) => (
                      <Badge key={idx} variant="outline" size="sm">
                        {kw}
                      </Badge>
                    ))}
                  </Group>
                </div>
              )}
            </Stack>
          </Card>
        </Grid.Col>

        <Grid.Col span={{ base: 12, md: 4 }}>
          <PasalLinksSidebar pasalId={pasal.id} />
        </Grid.Col>
      </Grid>
    </Stack>
  )
}