import { Badge, Loader } from '@mantine/core'
import type { ImportRunStatus } from '@/lib/database.types'
import { IMPORT_STATUS_META } from '@/lib/import-runs'

export function ImportStatusBadge({ status }: { status: ImportRunStatus }) {
  const meta = IMPORT_STATUS_META[status]
  const busy = status === 'queued' || status === 'running'
  return (
    <Badge color={meta.color} variant="light" leftSection={busy ? <Loader size={10} color={meta.color} /> : undefined}>
      {meta.label}
    </Badge>
  )
}
