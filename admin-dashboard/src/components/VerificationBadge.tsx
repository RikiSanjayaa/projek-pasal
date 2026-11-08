import { Badge, Tooltip } from '@mantine/core'
import { IconAlertTriangle, IconCircleCheck } from '@tabler/icons-react'
import type { VerificationStatus } from '@/lib/database.types'

export const VERIFICATION_OPTIONS: { value: VerificationStatus; label: string }[] = [
  { value: 'perlu_verifikasi', label: 'Perlu verifikasi' },
  { value: 'terverifikasi', label: 'Terverifikasi' },
]

interface VerificationBadgeProps {
  status: VerificationStatus
  verifiedAt?: string | null
  verifierName?: string | null
  size?: 'xs' | 'sm' | 'md'
}

export function VerificationBadge({ status, verifiedAt, verifierName, size = 'sm' }: VerificationBadgeProps) {
  if (status === 'terverifikasi') {
    const when = verifiedAt ? new Date(verifiedAt).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' }) : null
    const detail = [verifierName && `oleh ${verifierName}`, when && `pada ${when}`].filter(Boolean).join(' ')
    return (
      <Tooltip label={detail ? `Dicek terhadap naskah resmi ${detail}` : 'Dicek terhadap naskah resmi'}>
        <Badge color="green" variant="light" size={size} leftSection={<IconCircleCheck size={12} />}>
          Terverifikasi
        </Badge>
      </Tooltip>
    )
  }

  return (
    <Tooltip label="Teks belum dicocokkan dengan naskah resmi. Tetap tampil di mobile dengan label peringatan.">
      <Badge color="yellow" variant="light" size={size} leftSection={<IconAlertTriangle size={12} />}>
        Perlu verifikasi
      </Badge>
    </Tooltip>
  )
}
