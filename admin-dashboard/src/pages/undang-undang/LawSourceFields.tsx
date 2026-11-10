import { useState } from 'react'
import { Accordion, Alert, Anchor, Button, Checkbox, FileInput, Group, NumberInput, Stack, Text, TextInput } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import { getAuthToken } from '@/lib/api'
import type { LawDocument, LawImportConfig, UndangUndangInsert, UndangUndangUpdate } from '@/lib/database.types'

interface Props {
  pdfUrl: string
  file: File | null
  document?: LawDocument | null
  remove: boolean
  config: LawImportConfig
  onPdfUrl: (value: string) => void
  onFile: (file: File | null) => void
  onRemove: (value: boolean) => void
  onConfig: (config: LawImportConfig) => void
}

export function lawFormData(values: UndangUndangInsert | UndangUndangUpdate): FormData {
  const body = new FormData()
  for (const [key, value] of Object.entries(values)) {
    if (key === 'official_document') {
      if (value instanceof File) body.append(key, value)
    } else if (key === 'import_config') {
      body.append(key, JSON.stringify(value ?? {}))
    } else if (value !== undefined) {
      body.append(key, value === null ? '' : typeof value === 'boolean' ? (value ? '1' : '0') : String(value))
    }
  }
  return body
}

export function LawSourceFields({ pdfUrl, file, document, remove, config, onPdfUrl, onFile, onRemove, onConfig }: Props) {
  const [downloading, setDownloading] = useState(false)
  const set = <K extends keyof LawImportConfig>(key: K, value: LawImportConfig[K]) => onConfig({ ...config, [key]: value })
  const download = async () => {
    if (!document) return
    setDownloading(true)
    try {
      const base = (import.meta.env.VITE_API_BASE_URL || '/api').replace(/\/$/, '')
      const response = await fetch(`${base}${document.download_url}`, { headers: { Authorization: `Bearer ${getAuthToken()}` } })
      if (!response.ok) throw new Error('Dokumen asli gagal diunduh.')
      const href = URL.createObjectURL(await response.blob())
      const link = window.document.createElement('a')
      link.href = href
      link.download = document.name
      link.click()
      setTimeout(() => URL.revokeObjectURL(href), 1000)
    } catch (error) {
      notifications.show({ title: 'Gagal', message: (error as Error).message, color: 'red' })
    } finally {
      setDownloading(false)
    }
  }
  return (
    <Stack gap="md">
      <Alert color="blue">Sumber otomatis terdaftar di Sumber Data saat UU disimpan. Penyimpanan tidak mengunduh sumber atau mengubah pasal. Kosongkan sumber teks untuk pengisian manual.</Alert>
      <TextInput label="URL PDF asli" description="Tautan langsung PDF dari BPK, peraturan.go.id, atau JDIH Setneg. Berbeda dari link halaman naskah resmi." placeholder="https://peraturan.bpk.go.id/Download/...pdf" value={pdfUrl} onChange={event => onPdfUrl(event.currentTarget.value)} />
      <FileInput label="Unggah PDF asli" description="PDF maksimal 20 MiB. Unggahan digunakan sebagai pembanding menggantikan URL PDF; bukan jaminan teks sudah benar." accept="application/pdf,.pdf" clearable value={file} onChange={onFile} />
      {document && <Stack gap="xs">
        <Group justify="space-between"><Text size="sm">{document.name} ({Math.ceil(document.size / 1024)} KB)</Text><Button size="xs" variant="subtle" loading={downloading} onClick={() => void download()}>Unduh dokumen tersimpan</Button></Group>
        <Checkbox label="Lepaskan dokumen dari UU ini" description="Salinan yang sudah dipakai draf impor tetap dipertahankan." checked={remove} onChange={event => onRemove(event.currentTarget.checked)} />
      </Stack>}
      <Accordion variant="contained">
        <Accordion.Item value="configuration">
          <Accordion.Control>Pengaturan parser dan pembanding PDF</Accordion.Control>
          <Accordion.Panel><Stack gap="md">
            <Text size="sm" c="dimmed">Konfigurasi lengkap berarti sumber dapat diperiksa, bukan berarti parsing sudah berhasil. Penanda versi asli dideteksi dari HTML saat pemeriksaan. Struktur khusus tetap perlu ditinjau pengelola teknis.</Text>
            <TextInput label="Label sumber" placeholder="Contoh: UU 12/2024" value={config.label ?? ''} onChange={event => set('label', event.currentTarget.value)} />
            <TextInput label="Penanda versi asli" description="Override opsional, misalnya uu-122024. Kosongkan agar versi asli dideteksi otomatis dari HTML saat pemeriksaan; isi hanya untuk mengganti hasil deteksi dengan penanda yang sudah diketahui." value={config.doc_class ?? ''} onChange={event => set('doc_class', event.currentTarget.value)} />
            <TextInput type="date" label="Tanggal diundangkan" value={config.diundangkan ?? ''} onChange={event => set('diundangkan', event.currentTarget.value)} />
            <TextInput type="date" label="Mulai berlaku" value={config.berlaku_sejak ?? ''} onChange={event => set('berlaku_sejak', event.currentTarget.value)} />
            {(['body_pages', 'penjelasan_pages'] as const).map(key => (
              <Group key={key} grow align="flex-start">
                <NumberInput label={`${key === 'body_pages' ? 'Batang tubuh' : 'Penjelasan'}: halaman awal`} min={0} max={10000} value={config[key]?.[0] ?? 0} onChange={value => set(key, [Number(value), config[key]?.[1] ?? 0])} />
                <NumberInput label={`${key === 'body_pages' ? 'Batang tubuh' : 'Penjelasan'}: halaman akhir`} min={0} max={10000} value={config[key]?.[1] ?? 0} onChange={value => set(key, [config[key]?.[0] ?? 0, Number(value)])} />
              </Group>
            ))}
            <Text size="xs" c="dimmed">Nomor halaman PDF dimulai dari 1. Batang tubuh 0–0 berarti seluruh PDF; penjelasan 0–0 berarti rentang belum ditentukan. Hasil pembandingan tetap perlu ditinjau.</Text>
            <Anchor href="/sumber-data" size="sm">Buka Sumber Data</Anchor>
          </Stack></Accordion.Panel>
        </Accordion.Item>
      </Accordion>
    </Stack>
  )
}
