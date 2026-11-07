import { Anchor, Badge, Box, Card, Group, Loader, Spoiler, Stack, Text, Timeline, Title } from '@mantine/core'
import { IconExternalLink, IconHistory } from '@tabler/icons-react'
import { useQuery } from '@tanstack/react-query'
import { LegalText } from '@/components/LegalText'
import { api } from '@/lib/api'
import type { PasalVersi } from '@/lib/database.types'
import { formatTanggal, VERSI_STATUS } from '@/lib/pasal-versi'

interface PasalHistoryProps {
  pasalId: string
}

/** Riwayat rumusan pasal karena perubahan undang-undang, dari versi paling lama ke yang berlaku. */
export function PasalHistory({ pasalId }: PasalHistoryProps) {
  const { data: versions = [], isLoading } = useQuery({
    queryKey: ['pasal', 'riwayat', pasalId],
    queryFn: () => api.get<PasalVersi[]>(`/admin/pasal/${pasalId}/riwayat`),
  })

  return (
    <Card padding="lg">
      <Group gap="xs" mb="md">
        <IconHistory size={20} />
        <Title order={4}>Riwayat perubahan</Title>
      </Group>

      {isLoading ? (
        <Loader size="sm" />
      ) : versions.length === 0 ? (
        <Text size="sm" c="dimmed">
          Belum ada perubahan tercatat. Rumusan ini masih rumusan asli undang-undangnya.
        </Text>
      ) : (
        <Timeline active={versions.length - 1} bulletSize={20} lineWidth={2}>
          {versions.map((versi, index) => {
            const status = VERSI_STATUS[versi.status]
            const current = index === versions.length - 1
            const diundangkan = formatTanggal(versi.diundangkan)
            const berlaku = formatTanggal(versi.berlaku_sejak)
            return (
              <Timeline.Item
                key={versi.id}
                title={
                  <Group gap="xs">
                    <Badge color={status.color} variant="light">
                      {status.label}
                    </Badge>
                    <Text fw={600}>{versi.sumber}</Text>
                    {current && (
                      <Badge color="green" variant="dot">
                        Berlaku
                      </Badge>
                    )}
                  </Group>
                }
              >
                <Stack gap={6} mt={4}>
                  {versi.judul_sumber && (
                    <Text size="sm" c="dimmed">
                      {versi.judul_sumber}
                    </Text>
                  )}
                  {(diundangkan || berlaku) && (
                    <Text size="xs" c="dimmed">
                      {[diundangkan && `Diundangkan ${diundangkan}`, berlaku && `berlaku ${berlaku}`].filter(Boolean).join(', ')}
                    </Text>
                  )}
                  {versi.naskah_resmi && (
                    <Anchor href={versi.naskah_resmi} target="_blank" rel="noreferrer" size="sm">
                      <Group gap={4}>
                        <IconExternalLink size={14} />
                        Naskah resmi {versi.sumber}
                      </Group>
                    </Anchor>
                  )}
                  <Spoiler maxHeight={current ? 0 : 140} showLabel={current ? 'Lihat rumusan' : 'Lihat rumusan lengkap'} hideLabel="Sembunyikan">
                    <Box p="sm" bg="var(--mantine-color-default-hover)" style={{ borderRadius: 'var(--mantine-radius-md)' }}>
                      <LegalText text={versi.isi} size="sm" />
                      {versi.penjelasan && (
                        <Box mt="sm">
                          <Text size="xs" fw={700} c="dimmed" tt="uppercase" mb={4}>
                            Penjelasan
                          </Text>
                          <LegalText text={versi.penjelasan} size="sm" />
                        </Box>
                      )}
                    </Box>
                  </Spoiler>
                </Stack>
              </Timeline.Item>
            )
          })}
        </Timeline>
      )}
    </Card>
  )
}
