import { Box, Stack, Text, type MantineSize } from '@mantine/core'

// Penjelasan memakai label seperti "Ayat (1)", "Huruf a", "Angka 3" di awal baris.
const SECTION_LABEL = /^((?:Ayat|Huruf|Angka)\s+(?:\(\d+[a-z]?\)|[a-z]{1,2}\b|\d+[a-z]?\b))\s*(.*)$/i
// Butir daftar huruf/angka: "a. ...", "1. ...", "1) ...".
const LIST_ITEM = /^(?:[a-z]{1,2}|\d+[a-z]?)[.)]\s/i

interface LegalTextProps {
  text: string
  size?: MantineSize
}

/** Isi dan penjelasan pasal dengan format yang sama: ayat rata kiri, butir huruf/angka menjorok, label penjelasan tebal. */
export function LegalText({ text, size = 'md' }: LegalTextProps) {
  const lines = text.split('\n').map((line) => line.trim()).filter(Boolean)

  return (
    <Stack gap={6}>
      {lines.map((line, index) => {
        const label = line.match(SECTION_LABEL)
        if (label) {
          return (
            <Box key={index} mt={index === 0 ? 0 : 'xs'}>
              <Text size="xs" fw={700} c="dimmed" tt="uppercase" style={{ letterSpacing: 0.4 }}>
                {label[1]}
              </Text>
              {label[2] && <Text size={size}>{label[2]}</Text>}
            </Box>
          )
        }
        return (
          <Text key={index} size={size} pl={LIST_ITEM.test(line) ? 'lg' : 0}>
            {line}
          </Text>
        )
      })}
    </Stack>
  )
}
