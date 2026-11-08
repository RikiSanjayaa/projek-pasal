import { useMemo } from 'react'
import { Text, type MantineSize } from '@mantine/core'
import { wordDiff } from '@/lib/word-diff'

interface DiffTextProps {
  before: string
  after: string
  size?: MantineSize
}

/** Rumusan baru dengan tanda perubahan: dihapus dicoret merah, ditambah disorot hijau. */
export function DiffText({ before, after, size = 'sm' }: DiffTextProps) {
  const segments = useMemo(() => wordDiff(before, after), [before, after])

  return (
    <Text size={size} style={{ whiteSpace: 'pre-wrap' }}>
      {segments.map((segment, index) => {
        if (segment.type === 'equal') return segment.text
        const removed = segment.type === 'removed'
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
            {segment.text}
          </Text>
        )
      })}
    </Text>
  )
}
