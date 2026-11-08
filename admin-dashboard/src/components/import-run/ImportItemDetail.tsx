import { Box, SimpleGrid, Stack, Tabs, Text } from '@mantine/core'
import { DiffText } from '@/components/DiffText'
import { LegalText } from '@/components/LegalText'
import type { ImportItem, ImportRiwayatRow, ImportSnap } from '@/lib/database.types'

const FIELDS: { key: 'judul' | 'isi' | 'penjelasan'; label: string }[] = [
  { key: 'judul', label: 'Judul' },
  { key: 'isi', label: 'Isi' },
  { key: 'penjelasan', label: 'Penjelasan' },
]

const kw = (s: ImportSnap | null) => (s?.keywords ?? []).join(', ')
const txt = (s: ImportSnap | null, key: 'judul' | 'isi' | 'penjelasan') => s?.[key] ?? ''

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <Box>
      <Text size="xs" fw={700} c="dimmed" tt="uppercase" mb={4}>
        {label}
      </Text>
      {children}
    </Box>
  )
}

/** Diff semua field dari `before` ke `after`; field yang sama dilewati. */
function SnapDiff({ before, after }: { before: ImportSnap | null; after: ImportSnap | null }) {
  const rows = FIELDS.filter((f) => txt(before, f.key) !== txt(after, f.key))
  const kwChanged = kw(before) !== kw(after)
  if (rows.length === 0 && !kwChanged) return <Text size="sm" c="dimmed">Tidak ada perbedaan.</Text>
  return (
    <Stack gap="sm">
      {rows.map((f) => (
        <Section key={f.key} label={f.label}>
          <DiffText before={txt(before, f.key)} after={txt(after, f.key)} />
        </Section>
      ))}
      {kwChanged && (
        <Section label="Kata kunci">
          <DiffText before={kw(before)} after={kw(after)} />
        </Section>
      )}
    </Stack>
  )
}

function SnapText({ snap }: { snap: ImportSnap | null }) {
  if (!snap) return <Text size="sm" c="dimmed">Tidak ada data.</Text>
  return (
    <Stack gap="sm">
      {snap.judul && <Section label="Judul"><Text size="sm">{snap.judul}</Text></Section>}
      {snap.isi && <Section label="Isi"><LegalText text={snap.isi} size="sm" /></Section>}
      {snap.penjelasan && <Section label="Penjelasan"><LegalText text={snap.penjelasan} size="sm" /></Section>}
      {snap.keywords.length > 0 && <Section label="Kata kunci"><Text size="sm">{kw(snap)}</Text></Section>}
    </Stack>
  )
}

function riwayatKey(r: ImportRiwayatRow) {
  return JSON.stringify([r.status, r.sumber, r.judul_sumber, r.diundangkan, r.berlaku_sejak, r.naskah_resmi, r.isi, r.penjelasan])
}

function RiwayatList({ title, rows, other }: { title: string; rows: ImportRiwayatRow[]; other: ImportRiwayatRow[] }) {
  const otherKeys = new Set(other.map(riwayatKey))
  return (
    <Stack gap="xs">
      <Text fw={600} size="sm">{title} ({rows.length})</Text>
      {rows.length === 0 && <Text size="sm" c="dimmed">Tidak ada riwayat.</Text>}
      {rows.map((r) => {
        const differs = !otherKeys.has(riwayatKey(r))
        const counterpart = other.find((o) => o.urutan === r.urutan)
        return (
          <Box
            key={r.urutan}
            p="xs"
            style={{
              border: '1px solid var(--mantine-color-default-border)',
              borderRadius: 6,
              background: differs ? 'var(--mantine-color-yellow-light)' : undefined,
            }}
          >
            <Text size="xs" fw={700} c="dimmed">
              #{r.urutan} · {r.status} · {r.sumber}
              {r.berlaku_sejak ? ` · berlaku ${r.berlaku_sejak}` : ''}
            </Text>
            {differs && counterpart ? <DiffText before={counterpart.isi} after={r.isi} size="xs" /> : <Text size="xs" style={{ whiteSpace: 'pre-wrap' }}>{r.isi}</Text>}
          </Box>
        )
      })}
    </Stack>
  )
}

export function ImportItemDetail({ item }: { item: ImportItem }) {
  switch (item.category) {
    case 'baru':
      return <SnapText snap={item.incoming} />
    case 'hilang':
      return <SnapText snap={item.current} />
    case 'berubah':
      return (
        <Stack gap="xs">
          <Text size="xs" c="dimmed">Data sekarang → sumber baru</Text>
          <SnapDiff before={item.current} after={item.incoming} />
        </Stack>
      )
    case 'diedit_admin':
      return (
        <Stack gap="xs">
          <Text size="xs" c="dimmed">Snapshot sumber → data sekarang (edit admin)</Text>
          <SnapDiff before={item.base} after={item.current} />
        </Stack>
      )
    case 'konflik':
      return (
        <Tabs defaultValue="sumber">
          <Tabs.List mb="sm">
            <Tabs.Tab value="sumber">Perubahan sumber (lama → baru)</Tabs.Tab>
            <Tabs.Tab value="admin">Perubahan admin (lama → sekarang)</Tabs.Tab>
            <Tabs.Tab value="sejajar">Sejajar</Tabs.Tab>
          </Tabs.List>
          <Tabs.Panel value="sumber"><SnapDiff before={item.base} after={item.incoming} /></Tabs.Panel>
          <Tabs.Panel value="admin"><SnapDiff before={item.base} after={item.current} /></Tabs.Panel>
          <Tabs.Panel value="sejajar">
            <SimpleGrid cols={{ base: 1, md: 3 }}>
              <Stack gap="xs"><Text fw={600} size="sm">Snapshot sumber lama</Text><SnapText snap={item.base} /></Stack>
              <Stack gap="xs"><Text fw={600} size="sm">Data sekarang</Text><SnapText snap={item.current} /></Stack>
              <Stack gap="xs"><Text fw={600} size="sm">Sumber baru</Text><SnapText snap={item.incoming} /></Stack>
            </SimpleGrid>
          </Tabs.Panel>
        </Tabs>
      )
    case 'riwayat': {
      const cur = item.current_riwayat ?? []
      const inc = item.incoming_riwayat ?? []
      return (
        <SimpleGrid cols={{ base: 1, md: 2 }}>
          <RiwayatList title="Riwayat sekarang" rows={cur} other={inc} />
          <RiwayatList title="Riwayat dari sumber" rows={inc} other={cur} />
        </SimpleGrid>
      )
    }
  }
}
