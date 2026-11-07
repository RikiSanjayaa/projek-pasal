export type DiffSegment = { type: 'equal' | 'inserted' | 'removed'; text: string }

// Kata, spasi (termasuk baris baru), atau satu tanda baca.
const TOKEN = /[\p{L}\p{N}]+|\s+|[^\p{L}\p{N}\s]/gu

/** Batas sel tabel LCS; di atas ini bagian tengah dianggap diganti utuh agar browser tidak macet. */
const MAX_CELLS = 4_000_000

function push(segments: DiffSegment[], type: DiffSegment['type'], text: string) {
  if (!text) return
  const last = segments[segments.length - 1]
  if (last && last.type === type) {
    last.text += text
  } else {
    segments.push({ type, text })
  }
}

/** Beda per kata antara dua rumusan pasal (LCS setelah awalan/akhiran yang sama dibuang). */
export function wordDiff(before: string, after: string): DiffSegment[] {
  const a = before.match(TOKEN) ?? []
  const b = after.match(TOKEN) ?? []

  let start = 0
  while (start < a.length && start < b.length && a[start] === b[start]) start++
  let endA = a.length
  let endB = b.length
  while (endA > start && endB > start && a[endA - 1] === b[endB - 1]) {
    endA--
    endB--
  }

  const segments: DiffSegment[] = []
  push(segments, 'equal', a.slice(0, start).join(''))

  const midA = a.slice(start, endA)
  const midB = b.slice(start, endB)
  if (midA.length * midB.length > MAX_CELLS) {
    push(segments, 'removed', midA.join(''))
    push(segments, 'inserted', midB.join(''))
  } else {
    // lcs[i][j] = panjang LCS midA[i..] dan midB[j..], disimpan datar.
    const cols = midB.length + 1
    const lcs = new Uint32Array((midA.length + 1) * cols)
    for (let i = midA.length - 1; i >= 0; i--) {
      for (let j = midB.length - 1; j >= 0; j--) {
        lcs[i * cols + j] =
          midA[i] === midB[j] ? lcs[(i + 1) * cols + j + 1] + 1 : Math.max(lcs[(i + 1) * cols + j], lcs[i * cols + j + 1])
      }
    }
    let i = 0
    let j = 0
    while (i < midA.length && j < midB.length) {
      if (midA[i] === midB[j]) {
        push(segments, 'equal', midA[i])
        i++
        j++
      } else if (lcs[(i + 1) * cols + j] >= lcs[i * cols + j + 1]) {
        push(segments, 'removed', midA[i++])
      } else {
        push(segments, 'inserted', midB[j++])
      }
    }
    push(segments, 'removed', midA.slice(i).join(''))
    push(segments, 'inserted', midB.slice(j).join(''))
  }

  push(segments, 'equal', a.slice(endA).join(''))
  return segments
}
