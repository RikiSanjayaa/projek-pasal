import { queryOptions } from '@tanstack/react-query'
import { api } from '@/lib/api'
import type { VerificationSummaryRow } from '@/lib/database.types'

/** Ringkasan verifikasi per UU. Dipakai dashboard, antrean, dan badge sidebar; satu cache bersama. */
export const verificationSummaryQuery = queryOptions({
  queryKey: ['pasal', 'verification-summary'],
  queryFn: async () => (await api.get<{ data: VerificationSummaryRow[] }>('/admin/pasal-verification-summary')).data,
  staleTime: 30 * 1000,
})

export function pendingVerificationCount(rows: VerificationSummaryRow[] | undefined): number {
  return rows?.reduce((total, row) => total + row.total - row.verified, 0) ?? 0
}
