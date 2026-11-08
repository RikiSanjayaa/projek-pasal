import { useMemo } from 'react'
import { Text, type MantineSize } from '@mantine/core'
import { LegalLayout } from '@/components/LegalText'
import { normalizeLegalChunk, type Range } from '@/lib/legal-text'
import { wordDiff, type DiffSegment } from '@/lib/word-diff'

interface DiffTextProps {
  before: string
  after: string
  size?: MantineSize
}

type Kind = DiffSegment['type']

/**
 * Rumusan baru dengan tanda perubahan (dihapus dicoret merah, ditambah disorot hijau),
 * memakai tata letak isi pasal yang sama dengan LegalText.
 */
export function DiffText({ before, after, size = 'sm' }: DiffTextProps) {
  const { text, kinds } = useMemo(() => {
    // Gabungan semua potongan (sama + dihapus + ditambah) beserta jenis tiap karakternya.
    let merged = ''
    const charKinds: Kind[] = []
    for (const segment of wordDiff(before, after)) {
      const chunk = normalizeLegalChunk(segment.text)
      merged += chunk
      for (let i = 0; i < chunk.length; i++) charKinds.push(segment.type)
    }
    return { text: merged, kinds: charKinds }
  }, [before, after])

  const renderRange = ([start, end]: Range) => {
    const parts: { kind: Kind; text: string }[] = []
    for (let i = start; i < end; i++) {
      const last = parts[parts.length - 1]
      if (last && last.kind === kinds[i]) last.text += text[i]
      else parts.push({ kind: kinds[i], text: text[i] })
    }
    return parts.map((part, index) => {
      if (part.kind === 'equal') return <span key={index}>{part.text}</span>
      const removed = part.kind === 'removed'
      return (
        <Text
          key={index}
          span
          inherit
          td={removed ? 'line-through' : undefined}
          c={removed ? 'var(--mantine-color-red-text)' : 'var(--mantine-color-green-text)'}
          bg={removed ? 'var(--mantine-color-red-light)' : 'var(--mantine-color-green-light)'}
          style={{ borderRadius: 3, padding: '0 1px', marginRight: removed ? 2 : 0 }}
          title={removed ? 'Dihapus' : 'Ditambahkan'}
        >
          {part.text}
        </Text>
      )
    })
  }

  return <LegalLayout text={text} size={size} renderRange={renderRange} />
}
