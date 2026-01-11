import { Text } from '@mantine/core'
import type { AuditLog } from '@/lib/database.types'

interface AuditLogHintProps {
  log: AuditLog
  undangUndangData?: { id: string; nama: string }[]
  pasalData?: { id: string; nomor: string; undang_undang_id: string }[]
  maxLength?: number
  showFull?: boolean
}

export function AuditLogHint({
  log,
  undangUndangData = [],
  pasalData = [],
  maxLength,
  showFull = false
}: AuditLogHintProps) {
  const uuMap = new Map(undangUndangData.map(uu => [uu.id, uu.nama]))

  const getPasalString = (pasalId: string): string => {
    const pasal = pasalData.find(p => p.id === pasalId)
    if (!pasal) return pasalId
    const uuNama = uuMap.get(pasal.undang_undang_id) || pasal.undang_undang_id
    return `${uuNama} ${pasal.nomor}`
  }

  const getChangeHint = (): string => {
    const data = (log.new_data || log.old_data) as Record<string, unknown> | null
    if (!data || typeof data !== 'object') return '-'

    if (log.table_name === 'pasal') {
      const nomor = (data.nomor as string) || ''
      const judul = (data.judul as string) || ''
      const undangUndangId = data.undang_undang_id as string
      const undangUndangNama = undangUndangId ? uuMap.get(undangUndangId) || undangUndangId : ''
      return `Pasal ${nomor}${judul ? ` - ${judul}` : ''}${undangUndangNama ? ` (${undangUndangNama})` : ''}`
    }

    if (log.table_name === 'undang_undang') {
      const kode = (data.kode as string) || ''
      const nama = (data.nama as string) || ''
      return `${kode}${nama ? ` - ${nama}` : ''}`
    }

    if (log.table_name === 'pasal_links') {
      const sourceId = data.source_pasal_id as string
      const targetId = data.target_pasal_id as string
      const sourceStr = sourceId ? getPasalString(sourceId) : sourceId
      const targetStr = targetId ? getPasalString(targetId) : targetId
      return `Link Pasal (${sourceStr} -> ${targetStr})`
    }

    if (log.table_name === 'users') {
      const email = (data.email as string) || ''
      const nama = (data.nama as string) || ''
      const isActive = data.is_active as boolean | undefined

      // Determine what changed for UPDATE action
      if (log.action === 'UPDATE' && log.old_data && log.new_data) {
        const oldData = log.old_data as Record<string, unknown>
        const newData = log.new_data as Record<string, unknown>

        if (oldData.is_active !== newData.is_active) {
          const status = newData.is_active ? 'diaktifkan' : 'dinonaktifkan'
          return `User ${nama || email} ${status}`
        }
        if (oldData.expires_at !== newData.expires_at) {
          return `User ${nama || email} - masa aktif diperpanjang`
        }
        return `User ${nama || email} - data diperbarui`
      }

      if (log.action === 'CREATE') {
        return `User baru: ${nama || email}`
      }

      if (log.action === 'DELETE') {
        return `User dihapus: ${nama || email}`
      }

      return `User: ${nama || email}${isActive === false ? ' (nonaktif)' : ''}`
    }

    return '-'
  }

  const hint = getChangeHint()

  if (maxLength && hint.length > maxLength && !showFull) {
    return (
      <Text size="sm" lineClamp={1} title={hint}>
        {hint.substring(0, maxLength)}...
      </Text>
    )
  }

  return (
    <Text size="sm" lineClamp={showFull ? undefined : 1}>
      {hint}
    </Text>
  )
}