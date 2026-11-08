import { useMemo } from 'react'
import { Box, Text, type MantineSize } from '@mantine/core'
import { parseLegalText } from '@/lib/legal-text'

interface LegalTextProps {
  text: string
  size?: MantineSize
}

const INDENT = '1.6em'
const MARKER_WIDTH = '2.1em'

/** Isi dan penjelasan pasal dengan tata letak yang sama seperti di aplikasi mobile. */
export function LegalText({ text, size = 'md' }: LegalTextProps) {
  const blocks = useMemo(() => parseLegalText(text), [text])

  return (
    <Box style={{ lineHeight: 1.7 }}>
      {blocks.map((block, index) => {
        const first = index === 0
        if (block.type === 'label') {
          return (
            <Text key={index} size="sm" fw={700} c="var(--mantine-primary-color-filled)" mt={first ? 0 : 'md'} mb={2}>
              {block.text}
            </Text>
          )
        }
        if (block.type === 'paragraph') {
          return (
            <Text key={index} size={size} lh="inherit" mt={first ? 0 : 8}>
              {block.text}
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
              {block.marker}
            </Text>
            <Text size={size} lh="inherit" style={{ flex: 1, minWidth: 0 }}>
              {block.text}
            </Text>
          </Box>
        )
      })}
    </Box>
  )
}
