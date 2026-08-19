const DEFAULT_ALIASES: Record<string, string[]> = {
  maling: ['pencurian', 'mencuri', 'mengambil barang'],
  curi: ['pencurian', 'mencuri', 'mengambil barang'],
  nyuri: ['pencurian', 'mencuri', 'mengambil barang'],
  'barang curian': ['penadahan', 'hasil kejahatan'],
  penadah: ['penadahan', 'hasil kejahatan'],
  tipu: ['penipuan', 'tipu muslihat', 'perbuatan curang'],
  bohong: ['penipuan', 'keterangan palsu', 'berita bohong'],
  ancam: ['pengancaman', 'ancaman kekerasan'],
  aniaya: ['penganiayaan', 'kekerasan'],
  bunuh: ['pembunuhan', 'menghilangkan nyawa'],
  narkoba: ['narkotika', 'psikotropika'],
  sabu: ['narkotika', 'psikotropika'],
  ganja: ['narkotika'],
  judi: ['perjudian'],
  'judi online': ['perjudian', 'transaksi elektronik'],
  korupsi: ['tindak pidana korupsi', 'merugikan keuangan negara'],
  suap: ['gratifikasi', 'korupsi'],
  fitnah: ['pencemaran nama baik', 'penghinaan'],
  hoax: ['berita bohong', 'kabar bohong'],
  palsu: ['pemalsuan', 'surat palsu', 'keterangan palsu'],
  gelap: ['penggelapan'],
  rampas: ['perampasan', 'kekerasan'],
  paksa: ['pemaksaan', 'kekerasan'],
  rusak: ['perusakan', 'merusak'],
}

const STOP_WORDS = new Set(['dan', 'atau', 'yang', 'di', 'ke', 'dari', 'dengan', 'untuk', 'pada', 'dalam', 'pasal'])

export function normalizeSearchText(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function expandSearchTerms(query: string, extraTerms: string[] = []) {
  const normalized = normalizeSearchText(query)
  const terms = new Set<string>()
  if (normalized) terms.add(normalized)

  const tokens = normalized.split(' ').filter((token) => token.length > 1 && !STOP_WORDS.has(token))
  tokens.forEach((token) => {
    terms.add(token)
    DEFAULT_ALIASES[token]?.forEach((alias) => terms.add(normalizeSearchText(alias)))
  })

  Object.entries(DEFAULT_ALIASES).forEach(([term, aliases]) => {
    if (normalized.includes(term)) aliases.forEach((alias) => terms.add(normalizeSearchText(alias)))
  })

  extraTerms.forEach((term) => {
    const normalizedTerm = normalizeSearchText(term)
    if (normalizedTerm.length > 1 && !STOP_WORDS.has(normalizedTerm)) terms.add(normalizedTerm)
  })

  return [...terms]
    .filter((term) => term.length > 1)
    .sort((a, b) => b.length - a.length)
}

export function defaultSearchSuggestions(query: string) {
  const normalized = normalizeSearchText(query)
  if (!normalized) return []

  const suggestions = new Set<string>()
  Object.entries(DEFAULT_ALIASES).forEach(([term, aliases]) => {
    if (normalized.includes(term) || term.includes(normalized)) {
      aliases.forEach((alias) => suggestions.add(alias))
    }
  })

  return [...suggestions].slice(0, 6)
}

export function extractContextSnippet(
  text: string,
  query: string,
  extraTerms: string[] = [],
  leadingChars = 40,
  totalChars = 160
): string {
  const cleanText = text.replace(/\s+/g, ' ').trim()
  if (!cleanText || !query.trim()) return cleanText

  const terms = expandSearchTerms(query, extraTerms)
  if (terms.length === 0 || cleanText.length <= totalChars) return cleanText

  const lowerText = cleanText.toLowerCase()
  let bestIndex = -1
  let bestTerm = ''

  for (const term of terms) {
    const idx = lowerText.indexOf(term.toLowerCase())
    if (idx === -1) continue
    if (bestIndex === -1 || term.length > bestTerm.length || (term.length === bestTerm.length && idx < bestIndex)) {
      bestIndex = idx
      bestTerm = term
    }
  }

  if (bestIndex === -1) return cleanText

  if (bestIndex <= leadingChars + 10) {
    let end = Math.min(totalChars, cleanText.length)
    if (end < cleanText.length) {
      const spaceIdx = cleanText.indexOf(' ', end)
      if (spaceIdx !== -1 && spaceIdx - end <= 25) {
        end = spaceIdx
      }
      return `${cleanText.substring(0, end).trim()}...`
    }
    return cleanText
  }

  let start = Math.max(0, bestIndex - leadingChars)
  const spaceBefore = cleanText.indexOf(' ', start)
  if (spaceBefore !== -1 && spaceBefore < bestIndex) {
    start = spaceBefore + 1
  }

  let end = Math.min(cleanText.length, start + totalChars)
  if (end < cleanText.length) {
    const spaceAfter = cleanText.indexOf(' ', end)
    if (spaceAfter !== -1 && spaceAfter - end <= 25) {
      end = spaceAfter
    }
    return `... ${cleanText.substring(start, end).trim()}...`
  }

  return `... ${cleanText.substring(start).trim()}`
}

