import type { MouseEvent, ReactNode } from 'react'
import { ActionIcon, Tooltip, type MantineColor } from '@mantine/core'

interface IconActionProps {
  /** Teks tooltip sekaligus aria-label; wajib supaya tombol ikon tetap bisa dipahami. */
  label: string
  icon: ReactNode
  color?: MantineColor
  onClick?: (event: MouseEvent<HTMLButtonElement>) => void
  loading?: boolean
  disabled?: boolean
}

/** Tombol aksi baris tabel: ikon saja, label di tooltip. */
export function IconAction({ label, icon, color = 'gray', onClick, loading, disabled }: IconActionProps) {
  return (
    <Tooltip label={label} withArrow openDelay={250}>
      <ActionIcon
        variant="subtle"
        color={color}
        size="lg"
        aria-label={label}
        onClick={onClick}
        loading={loading}
        disabled={disabled}
      >
        {icon}
      </ActionIcon>
    </Tooltip>
  )
}
