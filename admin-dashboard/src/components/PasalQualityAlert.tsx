import { Alert, List, Text } from '@mantine/core'
import { IconAlertTriangle, IconCircleCheck } from '@tabler/icons-react'
import type { PasalQualityIssue } from '@/lib/pasal-quality'

interface PasalQualityAlertProps {
  issues: PasalQualityIssue[]
  title?: string
  compact?: boolean
}

export function PasalQualityAlert({ issues, title = 'Quality check pasal', compact = false }: PasalQualityAlertProps) {
  const errors = issues.filter((issue) => issue.severity === 'error')
  const warnings = issues.filter((issue) => issue.severity === 'warning')

  if (issues.length === 0) {
    return (
      <Alert color="green" variant="light" icon={<IconCircleCheck size={16} />} title={title}>
        <Text size="sm">Data pasal terlihat rapi dan siap disimpan.</Text>
      </Alert>
    )
  }

  return (
    <Alert
      color={errors.length > 0 ? 'red' : 'yellow'}
      variant="light"
      icon={<IconAlertTriangle size={16} />}
      title={errors.length > 0 ? `${title}: ada yang wajib diperbaiki` : `${title}: perlu dicek`}
    >
      <List size="sm" spacing={compact ? 2 : 6}>
        {[...errors, ...warnings].map((issue, index) => (
          <List.Item key={`${issue.field}-${issue.message}-${index}`}>
            <Text span fw={issue.severity === 'error' ? 700 : 500}>
              {issue.message}
            </Text>
            {issue.suggestion && (
              <Text span c="dimmed">
                {' '}
                {issue.suggestion}
              </Text>
            )}
          </List.Item>
        ))}
      </List>
    </Alert>
  )
}
