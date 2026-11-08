import { queryOptions } from '@tanstack/react-query'
import { api, toQueryString } from '@/lib/api'
import type {
  ImportItem,
  ImportItemCategory,
  ImportRun,
  ImportRunStatus,
  ImportSourcesResponse,
} from '@/lib/database.types'

export const IMPORT_POLL_MS = 3000

export interface ImportItemsPage {
  data: ImportItem[]
  current_page: number
  last_page: number
  per_page: number
  total: number
}

export const IMPORT_STATUS_META: Record<ImportRunStatus, { label: string; color: string }> = {
  queued: { label: 'Mengantre', color: 'gray' },
  running: { label: 'Berjalan', color: 'blue' },
  ready: { label: 'Siap ditinjau', color: 'orange' },
  applied: { label: 'Diterapkan', color: 'green' },
  failed: { label: 'Gagal', color: 'red' },
  discarded: { label: 'Dibuang', color: 'gray' },
  needs_config: { label: 'Perlu konfigurasi', color: 'yellow' },
}

export const IMPORT_CATEGORIES: { value: ImportItemCategory; label: string; hint: string; selectable: boolean }[] = [
  { value: 'baru', label: 'Baru', hint: 'Pasal ada di sumber tetapi belum ada di database. Akan dibuat dan ditandai perlu verifikasi.', selectable: true },
  { value: 'berubah', label: 'Berubah di sumber', hint: 'Sumber berubah sejak impor terakhir dan pasal di database belum pernah diedit admin.', selectable: true },
  { value: 'konflik', label: 'Konflik', hint: 'Sumber berubah dan pasal di database juga diedit admin. Terapkan hanya jika versi sumber lebih benar; edit admin akan tertimpa.', selectable: true },
  { value: 'diedit_admin', label: 'Diedit admin', hint: 'Sumber tidak berubah, tetapi admin pernah mengedit pasal ini. Hanya informasi, tidak ada yang diterapkan.', selectable: false },
  { value: 'hilang', label: 'Hilang dari sumber', hint: 'Pasal ada di database tetapi tidak ada di sumber. Tidak pernah dihapus otomatis; memilih hanya menandai sudah ditinjau.', selectable: true },
  { value: 'riwayat', label: 'Riwayat berubah', hint: 'Teks pasal sama, tetapi riwayat perubahan (versi) di sumber berbeda. Riwayat akan diganti.', selectable: true },
]

export const importSourcesQuery = (poll: boolean) =>
  queryOptions({
    queryKey: ['import', 'sources'],
    queryFn: () => api.get<ImportSourcesResponse>('/admin/import-sources'),
    refetchInterval: (query) => {
      if (!poll) return false
      const active = query.state.data?.sources.some((s) => s.active_run && ['queued', 'running'].includes(s.active_run.status))
      return active ? IMPORT_POLL_MS : false
    },
  })

export const importRunQuery = (id: string) =>
  queryOptions({
    queryKey: ['import', 'run', id],
    queryFn: () => api.get<ImportRun>(`/admin/import-runs/${id}`),
    refetchInterval: (query) => {
      const status = query.state.data?.status
      return status === 'queued' || status === 'running' ? IMPORT_POLL_MS : false
    },
  })

export const importItemsQuery = (id: string, category: ImportItemCategory, page: number, perPage = 20) =>
  queryOptions({
    queryKey: ['import', 'run', id, 'items', category, page, perPage],
    queryFn: () =>
      api.get<ImportItemsPage>(`/admin/import-runs/${id}/items${toQueryString({ category, page, per_page: perPage })}`),
    placeholderData: (prev) => prev,
  })

export const startImportRun = (slug: string) => api.post<ImportRun>(`/admin/import-sources/${slug}/runs`)

export const setImportSelection = (id: string, body: { ids: string[]; selected: boolean } | { category: ImportItemCategory; selected: boolean }) =>
  api.patch<{ updated: number }>(`/admin/import-runs/${id}/items`, body)

export const applyImportRun = (id: string, confirmLarge: boolean) =>
  api.post<ImportRun>(`/admin/import-runs/${id}/apply`, { confirm_large: confirmLarge })

export const discardImportRun = (id: string) => api.post<ImportRun>(`/admin/import-runs/${id}/discard`)
