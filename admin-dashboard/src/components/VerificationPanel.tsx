import { Alert, Anchor, Button, Group, Stack, Text } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import { IconAlertTriangle, IconCircleCheck, IconExternalLink } from '@tabler/icons-react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '@/lib/api'
import type { PasalWithUndangUndang } from '@/lib/database.types'
import { isAmended, officialSourceFor, VERSI_STATUS } from '@/lib/pasal-versi'
import { invalidatePasalData } from '@/lib/query-invalidation'

interface VerificationPanelProps {
  pasal: PasalWithUndangUndang
}

/** Status verifikasi satu pasal + tombol untuk menandai sudah/belum dicek terhadap naskah resmi. */
export function VerificationPanel({ pasal }: VerificationPanelProps) {
  const queryClient = useQueryClient()
  const verified = pasal.verification_status === 'terverifikasi'

  const mutation = useMutation({
    mutationFn: (action: 'verify' | 'unverify') => api.post(`/admin/pasal/${pasal.id}/${action}`),
    onSuccess: async (_, action) => {
      await invalidatePasalData(queryClient)
      notifications.show({
        title: action === 'verify' ? 'Pasal terverifikasi' : 'Dikembalikan ke antrean',
        message: action === 'verify' ? 'Pasal ditandai sesuai naskah resmi.' : 'Pasal perlu dicek ulang.',
        color: action === 'verify' ? 'green' : 'yellow',
      })
    },
    onError: (error: Error) => notifications.show({ title: 'Gagal', message: error.message, color: 'red' }),
  })

  const verifiedAt = pasal.verified_at
    ? new Date(pasal.verified_at).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' })
    : null
  const official = officialSourceFor(pasal)
  const links = [
    official,
    pasal.undang_undang?.source_url && { href: pasal.undang_undang.source_url, label: 'Sumber teks' },
  ].filter(Boolean) as { href: string; label: string }[]
  const versi = pasal.versi_terakhir

  return (
    <Alert
      color={verified ? 'green' : 'yellow'}
      variant="light"
      icon={verified ? <IconCircleCheck size={18} /> : <IconAlertTriangle size={18} />}
      title={verified ? 'Terverifikasi' : 'Perlu verifikasi'}
    >
      <Stack gap="xs">
        <Text size="sm">
          {verified
            ? `Dicek terhadap naskah resmi${pasal.verifier?.nama ? ` oleh ${pasal.verifier.nama}` : ''}${verifiedAt ? ` pada ${verifiedAt}` : ''}.`
            : 'Teks berasal dari import dan belum dicocokkan dengan naskah resmi. Pasal tetap tampil di mobile dengan label "Belum diverifikasi admin".'}
        </Text>
        {versi && isAmended(pasal) && (
          <Text size="sm" fw={500}>
            Rumusan ini {VERSI_STATUS[versi.status].label.toLowerCase()} oleh {versi.judul_sumber ?? versi.sumber}. Cocokkan
            dengan naskah {versi.sumber}, bukan naskah awal {pasal.undang_undang?.kode}.
          </Text>
        )}
        {links.length > 0 && (
          <Group gap="md">
            {links.map((link) => (
              <Anchor key={link.href} href={link.href} target="_blank" rel="noreferrer" size="sm">
                <Group gap={4}>
                  <IconExternalLink size={14} />
                  {link.label}
                </Group>
              </Anchor>
            ))}
          </Group>
        )}
        {pasal.is_active && (
          <Group>
            {verified ? (
              <Button size="xs" variant="light" color="yellow" loading={mutation.isPending} onClick={() => mutation.mutate('unverify')}>
                Tandai perlu dicek ulang
              </Button>
            ) : (
              <Button size="xs" color="green" loading={mutation.isPending} onClick={() => mutation.mutate('verify')}>
                Sesuai naskah resmi, verifikasi
              </Button>
            )}
          </Group>
        )}
      </Stack>
    </Alert>
  )
}
