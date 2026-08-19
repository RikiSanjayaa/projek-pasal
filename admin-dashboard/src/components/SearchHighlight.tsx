import { Text, type TextProps } from '@mantine/core'
import { expandSearchTerms, extractContextSnippet } from '@/lib/smart-search'

interface SearchHighlightProps extends TextProps {
  text: string
  query: string
  extraTerms?: string[]
  autoSnippet?: boolean
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

export function SearchHighlight({ text, query, extraTerms = [], autoSnippet = false, ...props }: SearchHighlightProps) {
  const displayText = autoSnippet ? extractContextSnippet(text, query, extraTerms) : text
  const terms = expandSearchTerms(query, extraTerms)

  if (!query.trim() || terms.length === 0) {
    return <Text {...props}>{displayText}</Text>
  }

  const pattern = new RegExp(`(${terms.map(escapeRegExp).join('|')})`, 'gi')
  const parts = displayText.split(pattern)

  return (
    <Text {...props}>
      {parts.map((part, index) => {
        const matched = terms.some((term) => part.toLowerCase() === term.toLowerCase())
        if (!matched) return <span key={`${part}-${index}`}>{part}</span>

        return (
          <mark
            key={`${part}-${index}`}
            style={{
              background: 'var(--mantine-color-yellow-2)',
              color: 'var(--mantine-color-dark-8)',
              borderRadius: 3,
              padding: '0 2px',
              fontWeight: 700,
            }}
          >
            {part}
          </mark>
        )
      })}
    </Text>
  )
}
