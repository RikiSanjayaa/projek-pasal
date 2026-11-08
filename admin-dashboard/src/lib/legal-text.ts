/**
 * Susunan blok isi/penjelasan pasal, mengikuti formatter aplikasi mobile:
 * penanda ayat/butir punya kolom sendiri (hanging indent), butir bersarang menjorok,
 * label penjelasan ("Ayat (1)", "Huruf a", "Angka 2") jadi sub-judul.
 *
 * Blok menyimpan rentang karakter (bukan salinan teks) ke string hasil normalisasi,
 * supaya tampilan beda per kata (DiffText) bisa memakai tata letak yang sama.
 */
export type Range = [start: number, end: number]

export type LegalBlock =
  | { type: 'label'; label: Range }
  | { type: 'item'; marker: Range; text: Range[]; level: number }
  | { type: 'paragraph'; text: Range[] }

const MARKER = String.raw`(?:\(\d+[a-z]?\)|\d+[a-z]?\.|\([a-z]\)|[a-z]\.)`
const LABEL = String.raw`(?:Ayat\s+\(\d+[a-z]?\)|Huruf\s+[a-z]{1,2}|Angka\s+\d+[a-z]?)`

const ITEM_AT_START = new RegExp(`^(${MARKER})(\\s+)`, 'i')
const LABEL_AT_START = new RegExp(`^(${LABEL})(?=\\s|$)`, 'i')
// Penanda butir/label yang menempel di baris sebelumnya, setelah akhir kalimat/titik dua/titik koma.
// Rujukan seperti "pada ayat (2) diterapkan" tidak terpecah karena tidak didahului tanda baca.
const INLINE_ITEM = new RegExp(`([.:;])[ \\t]+(?=${MARKER}\\s)`, 'gi')
const INLINE_LABEL = new RegExp(`([.:;!?])[ \\t]+(?=${LABEL}\\s)`, 'g')

/** Pecah penanda yang menempel ke baris baru. Dipakai per potongan teks (juga potongan diff). */
export function normalizeLegalChunk(text: string): string {
  return text.replace(/\r\n?/g, '\n').replace(INLINE_LABEL, '$1\n').replace(INLINE_ITEM, '$1\n')
}

type Family = 'ayat' | 'huruf' | 'angka' | 'huruf-kurung'

function familyOf(marker: string): Family {
  if (/^\(\d/.test(marker)) return 'ayat'
  if (/^\d/.test(marker)) return 'angka'
  if (/^\(/.test(marker)) return 'huruf-kurung'
  return 'huruf'
}

/** Susun blok dari teks yang SUDAH dinormalisasi (lihat normalizeLegalChunk). */
export function parseLegalStructure(text: string): LegalBlock[] {
  const blocks: LegalBlock[] = []
  // Urutan jenis penanda di ayat yang sedang dibaca; posisinya = tingkat jorok.
  let stack: Family[] = []
  let lastText = ''

  let offset = 0
  for (const raw of text.split('\n')) {
    const lineStart = offset
    offset += raw.length + 1
    const lead = raw.length - raw.trimStart().length
    const line = raw.trim()
    if (!line) continue
    const start = lineStart + lead
    const end = start + line.length

    const label = line.match(LABEL_AT_START)
    if (label) {
      blocks.push({ type: 'label', label: [start, start + label[1].length] })
      stack = []
      const rest = line.slice(label[1].length)
      const restLead = rest.length - rest.trimStart().length
      if (rest.trim()) {
        blocks.push({ type: 'paragraph', text: [[start + label[1].length + restLead, end]] })
        lastText = rest.trim()
      } else {
        lastText = ''
      }
      continue
    }

    const item = line.match(ITEM_AT_START)
    if (item) {
      const family = familyOf(item[1])
      if (family === 'ayat') {
        stack = ['ayat']
      } else {
        const at = stack.indexOf(family)
        stack = at >= 0 ? stack.slice(0, at + 1) : [...stack, family]
      }
      const bodyStart = start + item[0].length
      blocks.push({ type: 'item', marker: [start, start + item[1].length], text: [[bodyStart, end]], level: stack.length - 1 })
      lastText = line
      continue
    }

    // Baris lanjutan: sambung ke blok sebelumnya kecuali kalimat sebelumnya sudah selesai.
    const previous = blocks[blocks.length - 1]
    const continues = previous && previous.type !== 'label' && !/[.:;]$/.test(lastText) && !/^[A-Z"“]/.test(line)
    if (continues) {
      previous.text.push([start, end])
    } else {
      blocks.push({ type: 'paragraph', text: [[start, end]] })
    }
    lastText = line
  }

  return blocks
}
