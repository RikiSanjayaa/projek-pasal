export type PasalQualitySeverity = 'error' | 'warning'

export interface PasalQualityIssue {
  field: 'nomor' | 'judul' | 'isi' | 'penjelasan'
  severity: PasalQualitySeverity
  message: string
  suggestion?: string
}

export interface PasalQualityInput {
  nomor?: string | null
  judul?: string | null
  isi?: string | null
  penjelasan?: string | null
}

const TYPO_PATTERNS: Array<{ pattern: RegExp; label: string; replacement: string }> = [
  { pattern: /\bPTIESIDEN\b/gi, label: 'PTIESIDEN', replacement: 'PRESIDEN' },
  { pattern: /\bPRESID[BEFN]\b/gi, label: 'PRESIDEN typo', replacement: 'PRESIDEN' },
  { pattern: /\bREPUB[UI]K\b/gi, label: 'REPUBUK/REPUBIK', replacement: 'REPUBLIK' },
  { pattern: /\btqjuh\b|\btqiuh\b|\btqjuh\b/gi, label: 'tqjuh/tqiuh', replacement: 'tujuh' },
  { pattern: /\btahy\b|\btahur\b|\btatun\b/gi, label: 'tahy/tahur', replacement: 'tahun' },
  { pattern: /\btqiuan\b|\btqjuan\b/gi, label: 'tqiuan/tqjuan', replacement: 'tujuan' },
  { pattern: /\bKetenluan\b/gi, label: 'Ketenluan', replacement: 'Ketentuan' },
  { pattern: /\bUndang-\s+Undang\b/gi, label: 'Undang- Undang', replacement: 'Undang-Undang' },
  { pattern: /\bpaling\s+ba[ny]{1,3}ak\b/gi, label: 'paling banyak typo', replacement: 'paling banyak' },
  { pattern: /\bpaling\s+la[rm]a\b/gi, label: 'paling lama typo', replacement: 'paling lama' },
  { pattern: /\bl0(?=\s*%|\s*persen\b)/gi, label: 'l0 persen', replacement: '10' },
]

export function normalizePasalNumber(value?: string | null) {
  return String(value || '')
    .replace(/\s+/g, ' ')
    .replace(/^pasal\s+/i, '')
    .replace(/^nom[oe]r\s+/i, '')
    .replace(/\s+(bis|ter)$/i, ' $1')
    .replace(/^([0-9]{1,4})\s+([a-z])$/i, '$1$2')
    .replace(/[.,;:\s]+$/g, '')
    .trim()
}

export function applyCommonOcrCorrections(value?: string | null) {
  let text = String(value || '')

  TYPO_PATTERNS.forEach(({ pattern, replacement }) => {
    text = text.replace(pattern, replacement)
  })

  return text
}

export function normalizeLegalTextForStorage(value?: string | null) {
  const cleaned = applyCommonOcrCorrections(value)
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .replace(/\u00a0/g, ' ')
    .replace(/[|¦]/g, ' ')
    .replace(/[¢•·]/g, ' ')
    .replace(/\(\s*[Il]\s*\)/g, '(1)')
    .replace(/\s+([,.;:])/g, '$1')
    .replace(/([\(\[])\s+/g, '$1')
    .replace(/\s+([)\]])/g, '$1')
    .replace(/[ \t]+((?:\([0-9ivxlcdm]+[a-z]?\)|[0-9]+[a-z]?\.|\([a-z]\)|[a-z]\.)\s+)/gi, '\n$1')

  const lines = cleaned
    .split('\n')
    .map((line) => line.replace(/[ \t]+/g, ' ').trim())
    .filter((line) => {
      if (!line) return false
      if (/^[-*_]{2,}/.test(line)) return false
      if (/^PRESIDEN\s+REPUBLIK\s+INDONESIA$/i.test(line)) return false
      if (/^KUHP\s*\(Kitab\s+Undang-Undang\s+Hukum\s+Pidana\)/i.test(line)) return false
      if (/^\d+\s*$/.test(line)) return false
      return true
    })

  const blocks: string[] = []
  const startsNewBlock = (line: string) => (
    /^(Pasal|Nom[oe]r)\s+[0-9]/i.test(line) ||
    /^(Penjelasan|Pendapat\s+Ahli|Catatan\s+Ahli)\s*:?/i.test(line) ||
    /^(\([0-9ivxlcdm]+[a-z]?\)|[0-9]+[a-z]?\.|\([a-z]\)|[a-z]\.)\s+/i.test(line)
  )

  for (const line of lines) {
    if (blocks.length === 0 || startsNewBlock(line)) {
      blocks.push(line)
    } else {
      blocks[blocks.length - 1] = `${blocks[blocks.length - 1]} ${line}`.replace(/[ \t]+/g, ' ')
    }
  }

  return blocks.join('\n').replace(/\n{3,}/g, '\n\n').trim()
}

export function normalizePasalInput<T extends PasalQualityInput>(row: T): T {
  return {
    ...row,
    nomor: normalizePasalNumber(row.nomor),
    judul: applyCommonOcrCorrections(row.judul).replace(/\s+/g, ' ').trim() || undefined,
    isi: normalizeLegalTextForStorage(row.isi),
    penjelasan: normalizeLegalTextForStorage(row.penjelasan) || undefined,
  }
}

export function getPasalQualityIssues(
  row: PasalQualityInput,
  options: { hasExistingDuplicate?: boolean; duplicateInBatch?: boolean } = {},
): PasalQualityIssue[] {
  const issues: PasalQualityIssue[] = []
  const nomor = String(row.nomor || '').trim()
  const isi = String(row.isi || '')
  const penjelasan = String(row.penjelasan || '')
  const combined = [row.nomor, row.judul, row.isi, row.penjelasan].filter(Boolean).join('\n')

  if (!nomor) {
    issues.push({ field: 'nomor', severity: 'error', message: 'Nomor pasal wajib diisi.' })
  }

  if (!isi.trim()) {
    issues.push({ field: 'isi', severity: 'error', message: 'Isi pasal wajib diisi.' })
  }

  if (options.hasExistingDuplicate) {
    issues.push({
      field: 'nomor',
      severity: 'error',
      message: 'Nomor pasal ini sudah ada pada undang-undang yang dipilih.',
      suggestion: 'Gunakan menu edit jika ingin memperbarui pasal yang sudah ada.',
    })
  }

  if (options.duplicateInBatch) {
    issues.push({
      field: 'nomor',
      severity: 'error',
      message: 'Nomor pasal duplikat dalam draft import.',
    })
  }

  if (/^pasal\s+pasal\b/i.test(`Pasal ${nomor}`) || /^pasal\s+/i.test(nomor)) {
    issues.push({
      field: 'nomor',
      severity: 'warning',
      message: 'Nomor masih memuat kata "Pasal", sehingga label bisa tampil ganda.',
      suggestion: 'Simpan nomor saja, contoh: 121 atau 479b.',
    })
  }

  TYPO_PATTERNS.forEach(({ pattern, label, replacement }) => {
    pattern.lastIndex = 0
    if (pattern.test(combined)) {
      issues.push({
        field: 'isi',
        severity: 'warning',
        message: `Terdeteksi typo OCR "${label}".`,
        suggestion: `Kemungkinan perlu diganti menjadi "${replacement}".`,
      })
    }
  })

  if (/[|¦¢•·]/.test(combined)) {
    issues.push({
      field: 'isi',
      severity: 'warning',
      message: 'Ada karakter sisa OCR yang biasanya bukan bagian dari teks pasal.',
      suggestion: 'Klik Rapikan Teks atau hapus karakter asing sebelum simpan.',
    })
  }

  if (/[ \t]{3,}/.test(combined)) {
    issues.push({
      field: 'isi',
      severity: 'warning',
      message: 'Ada spasi berlebih yang membuat tampilan mobile terlihat renggang.',
      suggestion: 'Klik Rapikan Teks untuk meratakan spasi.',
    })
  }

  if (/\(\s*[Il]\s*\)/.test(combined) || /(?:^|\n)\s*[A-Za-z]\s+(?=(Barangsiapa|Setiap|Dengan|Dalam|Jika|Ketentuan)\b)/i.test(combined)) {
    issues.push({
      field: 'isi',
      severity: 'warning',
      message: 'Format ayat atau awal baris terlihat berantakan.',
      suggestion: 'Pastikan ayat seperti (1), (2), a., b. berada di awal baris yang benar.',
    })
  }

  if (/(PRESIDEN\s+REPUBLIK\s+INDONESIA|KUHP\s*\(|\*{2,})/i.test(combined)) {
    issues.push({
      field: 'isi',
      severity: 'warning',
      message: 'Ada header/footer halaman yang ikut terbaca.',
      suggestion: 'Hapus bagian judul halaman, nomor halaman, atau footer buku.',
    })
  }

  if (/\([0-9]+\)[^\n]{160,}\s+\([0-9]+\)/.test(isi) || /[a-z]\.[^\n]{160,}\s+[a-z]\./i.test(isi)) {
    issues.push({
      field: 'isi',
      severity: 'warning',
      message: 'Beberapa ayat/butir kemungkinan masih menyatu dalam satu paragraf.',
      suggestion: 'Pisahkan tiap ayat atau butir ke baris baru agar mudah dibaca.',
    })
  }

  if (penjelasan.length > 0 && penjelasan.length < 8) {
    issues.push({
      field: 'penjelasan',
      severity: 'warning',
      message: 'Penjelasan terlalu pendek dan mungkin hasil OCR tidak lengkap.',
    })
  }

  return dedupeIssues(issues)
}

export function summarizeQualityIssues(issues: PasalQualityIssue[]) {
  const errors = issues.filter((issue) => issue.severity === 'error').length
  const warnings = issues.length - errors
  if (errors > 0) return `${errors} wajib diperbaiki, ${warnings} perlu dicek`
  if (warnings > 0) return `${warnings} perlu dicek`
  return 'Rapi'
}

function dedupeIssues(issues: PasalQualityIssue[]) {
  const seen = new Set<string>()
  return issues.filter((issue) => {
    const key = `${issue.severity}:${issue.field}:${issue.message}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}
