import type { PasalVersiStatus, PasalWithUndangUndang } from '@/lib/database.types'

export const VERSI_STATUS: Record<PasalVersiStatus, { label: string; color: string }> = {
  asli: { label: 'Rumusan asli', color: 'gray' },
  diubah: { label: 'Diubah', color: 'blue' },
  disisipkan: { label: 'Disisipkan', color: 'teal' },
  dihapus: { label: 'Dihapus', color: 'red' },
}

/**
 * Naskah resmi pembanding rumusan yang berlaku. Pasal yang diubah UU lain dicocokkan dengan
 * naskah UU pengubahnya (contoh: UU 1/2026), bukan naskah UU awal.
 */
export function officialSourceFor(pasal: PasalWithUndangUndang): { href: string; label: string } | null {
  const versi = pasal.versi_terakhir
  if (versi?.naskah_resmi) {
    return { href: versi.naskah_resmi, label: `Naskah resmi ${versi.sumber}` }
  }
  if (pasal.undang_undang?.official_url) {
    return { href: pasal.undang_undang.official_url, label: 'Naskah resmi' }
  }
  return null
}

/** Pasal yang rumusan berlakunya berasal dari UU perubahan (bukan rumusan asli). */
export function isAmended(pasal: PasalWithUndangUndang): boolean {
  return !!pasal.versi_terakhir && pasal.versi_terakhir.status !== 'asli'
}

export function formatTanggal(value: string | null): string | null {
  if (!value) return null
  return new Date(`${value}T00:00:00`).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })
}
