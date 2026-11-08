import { useMemo, type ReactNode } from 'react'
import { Box, Text, type MantineSize } from '@mantine/core'
import { normalizeLegalChunk, parseLegalStructure, type Range } from '@/lib/legal-text'

const INDENT = '1.6em'
const MARKER_WIDTH = '2.1em'

interface LegalLayoutProps {
  /** Teks yang sudah dinormalisasi; rentang blok menunjuk ke string ini. */
  text: string
  size?: MantineSize
  /** Cara menampilkan satu rentang teks (polos atau dengan tanda perubahan). */
  renderRange: (range: Range) => ReactNode
}

function joinRanges(ranges: Range[], renderRange: (range: Range) => ReactNode) {
  return ranges.map((range, index) => (
    <span key={index}>
      {index > 0 && ' '}
      {renderRange(range)}
    </span>
  ))
}

/** Tata letak isi/penjelasan seperti di aplikasi mobile: penanda di kolom sendiri, butir menjorok, label sub-judul. */
export function LegalLayout({ text, size = 'md', renderRange }: LegalLayoutProps) {
  const blocks = useMemo(() => parseLegalStructure(text), [text])

  return (
    <Box style={{ lineHeight: 1.7 }}>
      {blocks.map((block, index) => {
        const first = index === 0
        if (block.type === 'label') {
          return (
            <Text key={index} size="sm" fw={700} c="var(--mantine-primary-color-filled)" mt={first ? 0 : 'md'} mb={2}>
              {renderRange(block.label)}
            </Text>
          )
        }
        if (block.type === 'paragraph') {
          return (
            <Text key={index} size={size} lh="inherit" mt={first ? 0 : 8}>
              {joinRanges(block.text, renderRange)}
            </Text>
          )
        }
        return (
          <Box
            key={index}
            mt={first ? 0 : block.level === 0 ? 10 : 6}
            pl={`calc(${INDENT} * ${block.level})`}
            style={{ display: 'flex', alignItems: 'baseline' }}
          >
            <Text size={size} lh="inherit" style={{ flex: `0 0 ${MARKER_WIDTH}`, fontVariantNumeric: 'tabular-nums' }}>
              {renderRange(block.marker)}
            </Text>
            <Text size={size} lh="inherit" style={{ flex: 1, minWidth: 0 }}>
              {joinRanges(block.text, renderRange)}
            </Text>
          </Box>
        )
      })}
    </Box>
  )
}

interface LegalTextProps {
  text: string
  size?: MantineSize
}

/** Isi atau penjelasan pasal dengan format yang sama seperti di aplikasi mobile. */
export function LegalText({ text, size = 'md' }: LegalTextProps) {
  const normalized = useMemo(() => normalizeLegalChunk(text), [text])
  return <LegalLayout text={normalized} size={size} renderRange={([start, end]) => normalized.slice(start, end)} />
}
