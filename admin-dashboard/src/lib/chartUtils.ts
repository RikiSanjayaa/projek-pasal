import { subDays, startOfDay, format } from 'date-fns'

/**
 * Aggregate audit logs by date and action type
 */
export function aggregateAuditByDate(
  logs: any[],
  daysBack: number = 30,
): {
  date: string
  CREATE: number
  UPDATE: number
  DELETE: number
}[] {
  const result: Record<string, { CREATE: number; UPDATE: number; DELETE: number }> = {}

  // Initialize all dates in range
  for (let i = daysBack - 1; i >= 0; i--) {
    const date = startOfDay(subDays(new Date(), i))
    const dateStr = format(date, 'MMM dd')
    result[dateStr] = { CREATE: 0, UPDATE: 0, DELETE: 0 }
  }

  // Aggregate logs by date
  logs.forEach((log) => {
    const logDate = startOfDay(new Date(log.created_at))
    const dateStr = format(logDate, 'MMM dd')
    if (result[dateStr]) {
      result[dateStr][log.action as 'CREATE' | 'UPDATE' | 'DELETE']++
    }
  })

  // Convert to array format
  return Object.entries(result).map(([date, counts]) => ({
    date,
    ...counts,
  }))
}

/**
 * Aggregate admin contributions
 */
export function aggregateAdminContributions(
  logs: any[],
): {
  email: string
  total: number
  creates: number
  updates: number
  deletes: number
}[] {
  const result: Record<
    string,
    { email: string; total: number; creates: number; updates: number; deletes: number }
  > = {}

  logs.forEach((log) => {
    if (!result[log.admin_email]) {
      result[log.admin_email] = {
        email: log.admin_email,
        total: 0,
        creates: 0,
        updates: 0,
        deletes: 0,
      }
    }

    result[log.admin_email].total++
    result[log.admin_email][
      (log.action.toLowerCase() + 's') as 'creates' | 'updates' | 'deletes'
    ]++
  })

  return Object.values(result).sort((a, b) => b.total - a.total)
}

/**
 * Get admin activity by day/hour for heatmap-like data
 */
export function aggregateAdminActivityByTime(
  logs: any[],
  daysBack: number = 7,
): {
  date: string
  count: number
}[] {
  const result: Record<string, number> = {}

  // Initialize all dates
  for (let i = daysBack - 1; i >= 0; i--) {
    const date = startOfDay(subDays(new Date(), i))
    const dateStr = format(date, 'MMM dd')
    result[dateStr] = 0
  }

  // Count by date
  logs.forEach((log) => {
    const logDate = startOfDay(new Date(log.created_at))
    const dateStr = format(logDate, 'MMM dd')
    if (result[dateStr] !== undefined) {
      result[dateStr]++
    }
  })

  return Object.entries(result).map(([date, count]) => ({ date, count }))
}

/**
 * Get orphaned links (links pointing to deleted/non-existent pasal)
 */
export function getOrphanedLinks(
  links: any[],
  pasalMap: Map<string, any>,
): {
  linkId: string
  sourcePasalId: string
  targetPasalId: string
  sourcePasal?: any
}[] {
  return links
    .filter(
      (link) => !pasalMap.has(link.target_pasal_id) || !pasalMap.has(link.source_pasal_id),
    )
    .map((link) => ({
      linkId: link.id,
      sourcePasalId: link.source_pasal_id,
      targetPasalId: link.target_pasal_id,
      sourcePasal: pasalMap.get(link.source_pasal_id),
    }))
    .sort((a, b) => (a.sourcePasal?.nomor || '').localeCompare(b.sourcePasal?.nomor || ''))
}
