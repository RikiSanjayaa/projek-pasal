export function formatPasalLabel(nomor?: string | null) {
  const value = String(nomor || '').trim()
  if (!value) return 'Pasal -'
  return /^pasal\b/i.test(value) ? value.replace(/^pasal\b/i, 'Pasal') : `Pasal ${value}`
}
