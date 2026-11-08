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

type VersiTahun = { diundangkan?: string | null; berlaku_sejak?: string | null; sumber: string }

/** Tahun versi: tahun diundangkan, lalu berlaku sejak, lalu tahun 4 digit pertama (1800-2099) di sumber. */
export function versionYear(versi: VersiTahun): number | null {
  const fromDate = versi.diundangkan || versi.berlaku_sejak
  if (fromDate) {
    const year = Number.parseInt(fromDate.slice(0, 4), 10)
    if (Number.isFinite(year)) return year
  }
  const match = versi.sumber.match(/(?:18|19|20)\d\d/)
  return match ? Number(match[0]) : null
}

/** Label "Diubah X"/"Dihapus X" disembunyikan untuk perubahan kolonial (sebelum 1945) selain penghapusan. */
export function shouldShowRiwayatBadge(latest: VersiTahun & { status: PasalVersiStatus }): boolean {
  if (latest.status === 'dihapus') return true
  const year = versionYear(latest)
  return year === null || year >= 1945
}

export function formatTanggal(value: string | null): string | null {
  if (!value) return null
  return new Date(`${value}T00:00:00`).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })
}
