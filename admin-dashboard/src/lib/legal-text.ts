/**
 * Susunan blok isi/penjelasan pasal, mengikuti formatter aplikasi mobile:
 * penanda ayat/butir punya kolom sendiri (hanging indent), butir bersarang menjorok,
 * label penjelasan ("Ayat (1)", "Huruf a", "Angka 2") jadi sub-judul.
 */
export type LegalBlock =
  | { type: 'label'; text: string }
  | { type: 'item'; marker: string; text: string; level: number }
  | { type: 'paragraph'; text: string }

const MARKER = String.raw`(?:\(\d+[a-z]?\)|\d+[a-z]?\.|\([a-z]\)|[a-z]\.)`
const LABEL = String.raw`(?:Ayat\s+\(\d+[a-z]?\)|Huruf\s+[a-z]{1,2}|Angka\s+\d+[a-z]?)`

const ITEM_AT_START = new RegExp(`^(${MARKER})\\s+(.*)$`, 'i')
const LABEL_AT_START = new RegExp(`^(${LABEL})(?=\\s|$)\\s*(.*)$`, 'i')
// Penanda butir yang menempel di baris sebelumnya, setelah akhir kalimat/titik dua/titik koma.
// Rujukan seperti "pada ayat (2) diterapkan" tidak terpecah karena tidak didahului tanda baca.
const INLINE_ITEM = new RegExp(`([.:;])[ \\t]+(?=${MARKER}\\s)`, 'gi')
const INLINE_LABEL = new RegExp(`([.:;!?])[ \\t]+(?=${LABEL}\\s)`, 'g')

type Family = 'ayat' | 'huruf' | 'angka' | 'huruf-kurung'

function familyOf(marker: string): Family {
  if (/^\(\d/.test(marker)) return 'ayat'
  if (/^\d/.test(marker)) return 'angka'
  if (/^\(/.test(marker)) return 'huruf-kurung'
  return 'huruf'
}

export function parseLegalText(text: string): LegalBlock[] {
  const lines = text
    .replace(/\r\n?/g, '\n')
    .replace(INLINE_LABEL, '$1\n')
    .replace(INLINE_ITEM, '$1\n')
    .split('\n')
    .map((line) => line.replace(/[ \t]+/g, ' ').trim())
    .filter(Boolean)

  const blocks: LegalBlock[] = []
  // Urutan jenis penanda di ayat yang sedang dibaca; posisinya = tingkat jorok.
  let stack: Family[] = []

  for (const line of lines) {
    const label = line.match(LABEL_AT_START)
    if (label) {
      blocks.push({ type: 'label', text: label[1].replace(/\s+/g, ' ') })
      stack = []
      if (label[2]) blocks.push({ type: 'paragraph', text: label[2] })
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
      blocks.push({ type: 'item', marker: item[1], text: item[2], level: stack.length - 1 })
      continue
    }

    // Baris lanjutan: sambung ke blok sebelumnya kecuali kalimat sebelumnya sudah selesai.
    const previous = blocks[blocks.length - 1]
    const continues = previous && previous.type !== 'label' && !/[.:;]$/.test(previous.text) && !/^[A-Z"“]/.test(line)
    if (continues) {
      previous.text = `${previous.text} ${line}`
    } else {
      blocks.push({ type: 'paragraph', text: line })
    }
  }

  return blocks
}
