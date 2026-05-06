import { useCallback, useMemo, useState } from 'react'
import {
  ActionIcon,
  Alert,
  Badge,
  Box,
  Button,
  Card,
  Group,
  Progress,
  Select,
  SimpleGrid,
  Stack,
  Tabs,
  TagsInput,
  Text,
  Textarea,
  TextInput,
  Title,
} from '@mantine/core'
import { Dropzone } from '@mantine/dropzone'
import { notifications } from '@mantine/notifications'
import { useMediaQuery } from '@mantine/hooks'
import {
  IconAlertCircle,
  IconCamera,
  IconCheck,
  IconDownload,
  IconFileSpreadsheet,
  IconListCheck,
  IconPhotoScan,
  IconTrash,
  IconUpload,
  IconWand,
  IconX,
} from '@tabler/icons-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { recognize } from 'tesseract.js'
import * as XLSX from 'xlsx'
import { XlsxImportGuide } from '@/components/bulk-import/XlsxImportGuide'
import { api, type PaginatedResponse } from '@/lib/api'

const MAX_LINKS_PER_PASAL = 5

interface PasalLink {
  targetUU: string
  targetNomor: string
  keterangan?: string
}

interface ImportPasal {
  nomor: string
  judul?: string
  isi: string
  penjelasan?: string
  keywords?: string[]
  links?: PasalLink[]
}

interface OcrDraft extends ImportPasal {
  id: string
  source: string
}

interface ImportResult {
  pasal: {
    success: number
    failed: number
    errors: { nomor: string; error: string }[]
  }
  links: {
    success: number
    failed: number
    errors: { source: string; target: string; error: string }[]
  }
}

function cleanOcrText(text: string) {
  return text
    .replace(/\r/g, '')
    .split('\n')
    .map((line) => line
      .replace(/\|/g, ' ')
      .replace(/[¢•·]/g, ' ')
      .replace(/\(\s*[Il]\s*\)/g, '(1)')
      .replace(/^®\s+(?=[A-Z])/g, '(3) ')
      .replace(/^[A-Za-z]\s*\)\s+(?=[A-Z])/g, '(2) ')
      .replace(/^[^\w(]*(?=\(\s*[0-9IVXLCDM]+\))/i, '')
      .replace(/[ \t]+/g, ' ')
      .replace(/^[\s.,;:_!Il-]+(?=(Pasal|Nom[oe]r)\b)/i, '')
      .replace(/^(?:[0-9A-Za-z]|il)\s+(?=(\([0-9IVXIl]+\)|[a-z]))/i, '')
      .replace(/^[A-Za-z]\.\s+(?=[a-z])/i, '')
      .replace(/^[a-z]{1,2}\s+(?=[A-Z])/i, '')
      .replace(/\s+$/g, '')
      .trim()
    )
    .filter((line) => !/^---.*---$/.test(line) && !/KUHP\s*\(/i.test(line) && !/\*{2,}/.test(line))
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

function normalizeLegalTextForStorage(text?: string | null) {
  const lines = String(text || '')
    .replace(/\r/g, '')
    .replace(/\b[a-z]\s+(?=[0-9]+[a-z]?\.\s+)/gi, '')
    .replace(/[ \t]+((?:\([0-9ivxlcdm]+[a-z]?\)|[0-9]+[a-z]?\.|\([a-z]\)|[a-z]\.)\s+)/gi, '\n$1')
    .split('\n')
    .map((line) => line.replace(/[ \t]+/g, ' ').trim())
    .filter(Boolean)

  const blocks: string[] = []
  const startsNewBlock = (line: string) => (
    /^(Pasal|Nom[oe]r)\s+[0-9]/i.test(line) ||
    /^(Penjelasan|Pendapat\s+Ahli|Catatan\s+Ahli)\s*:?/i.test(line) ||
    /^(\([0-9ivxlcdm]+[a-z]?\)|[0-9]+[a-z]?\.|\([a-z]\)|[a-z]\.)\s+/i.test(line)
  )

  for (const line of lines) {
    if (blocks.length === 0 || startsNewBlock(line)) {
      blocks.push(line)
    } else {
      blocks[blocks.length - 1] = `${blocks[blocks.length - 1]} ${line}`.replace(/[ \t]+/g, ' ')
    }
  }

  return blocks.join('\n').replace(/\n{3,}/g, '\n\n').trim()
}

function normalizeImportPasal(row: ImportPasal): ImportPasal {
  return {
    ...row,
    nomor: row.nomor.trim(),
    judul: row.judul?.trim() || undefined,
    isi: normalizeLegalTextForStorage(row.isi),
    penjelasan: normalizeLegalTextForStorage(row.penjelasan) || undefined,
    keywords: row.keywords?.map((keyword) => keyword.trim()).filter(Boolean) || [],
  }
}

function createDraftId() {
  if (typeof globalThis.crypto?.randomUUID === 'function') {
    return globalThis.crypto.randomUUID()
  }

  return `draft-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
}

function splitExplanation(content: string) {
  const marker = content.match(/\n\s*(Penjelasan|Pendapat\s+Ahli|Catatan\s+Ahli)\s*:?\s*/i)
  if (!marker || marker.index === undefined) {
    return { isi: content.trim(), penjelasan: '' }
  }

  const isi = content.slice(0, marker.index).trim()
  const label = marker[1].replace(/\s+/g, ' ')
  const note = content.slice(marker.index + marker[0].length).trim()

  return {
    isi,
    penjelasan: note ? `${label}:\n${note}` : '',
  }
}

function parsePasalHeader(header: string) {
  const normalized = header
    .replace(/\|/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/^(Pasal|Nom[oe]r)\s+/i, '')
    .trim()
  const [nomorPart, ...titleParts] = normalized.split(/\s[-–—:]\s|[-–—:]\s/)
  return {
    nomor: nomorPart.trim(),
    judul: titleParts.join(' - ').trim(),
  }
}

function parseInlinePasalHeader(header: string) {
  const normalized = header
    .replace(/\|/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/^(Pasal|Nom[oe]r)\s+/i, '')
    .trim()
  const match = normalized.match(/^([0-9]{1,4}(?:[a-z]|\s+(?:bis|ter))?)\b\s*(.*)$/i)

  if (!match) {
    return { ...parsePasalHeader(header), trailingText: '' }
  }

  return {
    nomor: match[1].replace(/\s+/g, ' ').trim(),
    judul: '',
    trailingText: match[2].replace(/^[-:.,\s]+/, '').trim(),
  }
}

function parseOcrTextToDrafts(text: string, source = 'Teks manual'): OcrDraft[] {
  const cleaned = cleanOcrText(text)
  if (!cleaned) return []

  const pasalHeaderPattern = /(^|[\n.;:!?]\s*)(Pasal\s+[0-9]{1,4}(?:[a-z]|\s+(?:bis|ter))?\b\s*[-:.,]?\s*)/gi
  let matches = [...cleaned.matchAll(pasalHeaderPattern)]

  if (matches.length === 0) {
    matches = [...cleaned.matchAll(/(?:^|\n)\s*(?:(?:Pasal|Nom[oe]r)\s+)?([0-9]{1,4}(?:[a-z]|\s+(?:bis|ter))?(?:\s[-:]\s[^\n]+)?)\s*(?=\n|$)/gi)]
  }

  if (matches.length === 0) {
    return [{
      id: createDraftId(),
      source,
      nomor: '',
      judul: '',
      isi: normalizeLegalTextForStorage(cleaned),
      penjelasan: '',
      keywords: [],
    }]
  }

  return matches.map((match, index) => {
    const next = matches[index + 1]
    const segmentStart = (match.index ?? 0) + match[0].length
    const segmentEnd = next?.index ?? cleaned.length
    const rawHeader = match[2] || match[1] || ''
    const { nomor, judul, trailingText } = parseInlinePasalHeader(rawHeader)
    const segmentText = [trailingText, cleaned.slice(segmentStart, segmentEnd)]
      .filter(Boolean)
      .join(' ')
      .replace(/^\s*[a-z]\s+(?=(Diancam|Barangsiapa|Setiap|Perbuatan|Dengan|Dalam|Jika|Ketentuan)\b)/i, '')
      .replace(/^\s*[A-Za-z]{1,8}\s*:\s+(?=(Diancam|Barangsiapa|Setiap|Perbuatan|Dengan|Dalam|Jika|Ketentuan)\b)/i, '')
      .replace(/\s+[!;:\s&.,-]*BAB\s+[IVXLCDM0-9]+.*$/i, '')
    const { isi, penjelasan } = splitExplanation(segmentText)

    return {
      id: createDraftId(),
      source,
      nomor,
      judul,
      isi: normalizeLegalTextForStorage(isi),
      penjelasan: normalizeLegalTextForStorage(penjelasan),
      keywords: [],
    }
  })
}

function draftErrors(draft: OcrDraft, drafts: OcrDraft[]) {
  const errors: string[] = []
  if (!draft.nomor.trim()) errors.push('Nomor wajib diisi')
  if (!draft.isi.trim()) errors.push('Isi wajib diisi')
  if (draft.nomor.trim() && drafts.filter((item) => item.nomor.trim().toLowerCase() === draft.nomor.trim().toLowerCase()).length > 1) {
    errors.push('Nomor duplikat dalam batch')
  }
  return errors
}

async function prepareImageForOcr(file: File): Promise<File | Blob> {
  const image = await createImageBitmap(file)
  const longestSide = Math.max(image.width, image.height)
  const scale = longestSide > 2400 ? 2400 / longestSide : Math.max(1, 1400 / Math.max(1, image.width))
  const width = Math.round(image.width * scale)
  const height = Math.round(image.height * scale)

  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height

  const context = canvas.getContext('2d')
  if (!context) return file

  context.drawImage(image, 0, 0, width, height)
  image.close()

  const imageData = context.getImageData(0, 0, width, height)
  const pixels = imageData.data

  for (let i = 0; i < pixels.length; i += 4) {
    const luminance = pixels[i] * 0.299 + pixels[i + 1] * 0.587 + pixels[i + 2] * 0.114
    const contrasted = Math.max(0, Math.min(255, (luminance - 128) * 1.45 + 128))
    pixels[i] = contrasted
    pixels[i + 1] = contrasted
    pixels[i + 2] = contrasted
  }

  context.putImageData(imageData, 0, 0)

  return new Promise((resolve) => {
    canvas.toBlob((blob) => resolve(blob || file), 'image/png')
  })
}

export function BulkImportPage() {
  const queryClient = useQueryClient()
  const isMobile = useMediaQuery('(max-width: 48em)')
  const [mode, setMode] = useState<string | null>('ocr')
  const [selectedUU, setSelectedUU] = useState<string | null>(null)
  const [excelRows, setExcelRows] = useState<ImportPasal[] | null>(null)
  const [fileName, setFileName] = useState<string>('')
  const [importResult, setImportResult] = useState<ImportResult | null>(null)
  const [progress, setProgress] = useState(0)
  const [currentPhase, setCurrentPhase] = useState<'pasal' | 'links'>('pasal')
  const [ocrDrafts, setOcrDrafts] = useState<OcrDraft[]>([])
  const [ocrRawText, setOcrRawText] = useState('')
  const [ocrProgress, setOcrProgress] = useState(0)
  const [ocrPhase, setOcrPhase] = useState('')
  const [isOcrProcessing, setIsOcrProcessing] = useState(false)
  const [showOcrRawText, setShowOcrRawText] = useState(false)

  const { data: undangUndangList } = useQuery({
    queryKey: ['undang_undang', 'list'],
    queryFn: async () => {
      const response = await api.get<PaginatedResponse<{ id: string; kode: string; nama: string }>>(
        '/admin/undang-undang?is_active=1&per_page=200'
      )
      return response.data
    },
  })

  const ocrInvalidCount = useMemo(
    () => ocrDrafts.filter((draft) => draftErrors(draft, ocrDrafts).length > 0).length,
    [ocrDrafts]
  )

  const parseXlsxFile = useCallback((data: ArrayBuffer): ImportPasal[] => {
    const workbook = XLSX.read(data, { type: 'array' })
    const worksheet = workbook.Sheets[workbook.SheetNames[0]]
    const rows = XLSX.utils.sheet_to_json<Record<string, unknown>>(worksheet, { defval: '' })

    if (rows.length === 0) {
      throw new Error('File XLSX kosong atau tidak memiliki data')
    }

    return rows.map((row, index) => {
      const rowNum = index + 2
      const nomor = String(row.nomor || '').trim()
      const judul = String(row.judul || '').trim() || undefined
      const isi = String(row.isi || '').trim()
      const penjelasan = String(row.penjelasan || '').trim() || undefined
      const keywordsRaw = String(row.keywords || '').trim()

      if (!nomor) throw new Error(`Baris ${rowNum}: kolom "nomor" wajib diisi`)
      if (!isi) throw new Error(`Baris ${rowNum}: kolom "isi" wajib diisi`)

      const keywords = keywordsRaw
        ? keywordsRaw.split(',').map((keyword) => keyword.trim()).filter(Boolean)
        : []

      const links: PasalLink[] = []
      for (let i = 1; i <= MAX_LINKS_PER_PASAL; i++) {
        const targetUU = String(row[`link${i}_targetUU`] || '').trim()
        const targetNomor = String(row[`link${i}_targetNomor`] || '').trim()
        const keterangan = String(row[`link${i}_keterangan`] || '').trim() || undefined

        if (targetUU && targetNomor) {
          links.push({ targetUU, targetNomor, keterangan })
        } else if (targetUU && !targetNomor) {
          throw new Error(`Baris ${rowNum}: link${i}_targetNomor wajib diisi jika link${i}_targetUU diisi`)
        } else if (!targetUU && targetNomor) {
          throw new Error(`Baris ${rowNum}: link${i}_targetUU wajib diisi jika link${i}_targetNomor diisi`)
        }
      }

      return normalizeImportPasal({ nomor, judul, isi, penjelasan, keywords, links: links.length > 0 ? links : undefined })
    })
  }, [])

  const handleFileDrop = useCallback((files: File[]) => {
    const file = files[0]
    if (!file) return

    setFileName(file.name)
    setImportResult(null)

    const reader = new FileReader()
    reader.onload = (event) => {
      try {
        const validated = parseXlsxFile(event.target?.result as ArrayBuffer)
        setExcelRows(validated)
        notifications.show({
          title: 'File berhasil dibaca',
          message: `${validated.length} pasal siap diimport`,
          color: 'green',
        })
      } catch (error) {
        notifications.show({
          title: 'Format XLSX tidak valid',
          message: error instanceof Error ? error.message : 'File tidak bisa dibaca',
          color: 'red',
        })
        setExcelRows(null)
      }
    }
    reader.readAsArrayBuffer(file)
  }, [parseXlsxFile])

  const processOcrFiles = async (files: FileList | File[]) => {
    const images = Array.from(files).filter((file) => file.type.startsWith('image/'))
    if (images.length === 0) return

    setIsOcrProcessing(true)
    setOcrProgress(0)
    setOcrPhase('Menyiapkan pembaca teks')
    setImportResult(null)

    try {
      const pageTexts: string[] = []

      for (const [index, file] of images.entries()) {
        setOcrPhase(`Menyiapkan foto ${index + 1}/${images.length}: ${file.name}`)
        const preparedImage = await prepareImageForOcr(file)
        setOcrPhase(`Membaca foto ${index + 1}/${images.length}: ${file.name}`)
        const result = await recognize(preparedImage, 'ind+eng', {
          logger: (message) => {
            if (message.status === 'recognizing text') {
              const pageProgress = message.progress || 0
              setOcrProgress(Math.round(((index + pageProgress) / images.length) * 100))
            }
          },
        })
        pageTexts.push(`--- ${file.name} ---\n${result.data.text}`)
      }

      const rawText = cleanOcrText(pageTexts.join('\n\n'))
      const drafts = parseOcrTextToDrafts(rawText, images.length > 1 ? `${images.length} foto` : images[0].name)
      setOcrRawText(rawText)
      setOcrDrafts(drafts)
      setShowOcrRawText(false)
      setOcrProgress(100)
      notifications.show({
        title: 'OCR selesai',
        message: `${drafts.length} draft pasal ditemukan. Periksa dulu sebelum import.`,
        color: 'green',
      })
    } catch (error) {
      notifications.show({
        title: 'OCR gagal',
        message: error instanceof Error ? error.message : 'Foto tidak bisa dibaca.',
        color: 'red',
      })
    } finally {
      setIsOcrProcessing(false)
      setOcrPhase('')
    }
  }

  const reparseOcrText = () => {
    const cleaned = cleanOcrText(ocrRawText)
    const drafts = parseOcrTextToDrafts(cleaned)
    setOcrRawText(cleaned)
    setOcrDrafts(drafts)
    notifications.show({
      title: 'Teks diparse ulang',
      message: `${drafts.length} draft pasal ditemukan.`,
      color: drafts.length ? 'blue' : 'orange',
    })
  }

  const updateDraft = (id: string, patch: Partial<OcrDraft>) => {
    setOcrDrafts((drafts) => drafts.map((draft) => (draft.id === id ? { ...draft, ...patch } : draft)))
  }

  const removeDraft = (id: string) => {
    setOcrDrafts((drafts) => drafts.filter((draft) => draft.id !== id))
  }

  const rowsForImport = () => {
    if (mode === 'ocr') {
      if (ocrDrafts.length === 0) throw new Error('Belum ada draft OCR untuk diimport')
      if (ocrInvalidCount > 0) throw new Error('Perbaiki draft OCR yang masih invalid sebelum import')
      return ocrDrafts.map(({ id: _id, source: _source, ...draft }) => normalizeImportPasal(draft))
    }

    if (!excelRows || excelRows.length === 0) throw new Error('Upload file Excel terlebih dahulu')
    return excelRows.map(normalizeImportPasal)
  }

  const importMutation = useMutation({
    mutationFn: async () => {
      if (!selectedUU) throw new Error('Pilih undang-undang terlebih dahulu')

      const sourceRows = rowsForImport()
      setCurrentPhase('pasal')
      setProgress(40)
      const response = await api.post<{
        created: number
        updated: number
        errors: { row: number; message: string }[]
        links?: { created: number; errors: { source: string; target: string; message: string }[] }
      }>('/admin/pasal/bulk-import', {
        rows: sourceRows.map((item) => ({ ...item, undang_undang_id: selectedUU })),
      })

      setCurrentPhase('links')
      setProgress(100)

      return {
        pasal: {
          success: response.created + response.updated,
          failed: response.errors.length,
          errors: response.errors.map((error) => ({ nomor: `Baris ${error.row}`, error: error.message })),
        },
        links: {
          success: response.links?.created || 0,
          failed: response.links?.errors.length || 0,
          errors: response.links?.errors.map((error) => ({
            source: error.source,
            target: error.target,
            error: error.message,
          })) || [],
        },
      }
    },
    onSuccess: (result) => {
      setImportResult(result)
      queryClient.invalidateQueries({ queryKey: ['pasal'] })

      const totalFailed = result.pasal.failed + result.links.failed
      const totalSuccess = result.pasal.success + result.links.success
      notifications.show({
        title: totalFailed === 0 ? 'Import Berhasil' : 'Import Selesai dengan Error',
        message: totalFailed === 0
          ? `${result.pasal.success} pasal dan ${result.links.success} link berhasil diimport`
          : `${totalSuccess} berhasil, ${totalFailed} gagal`,
        color: totalFailed === 0 ? 'green' : 'orange',
      })
    },
    onError: (error: Error) => {
      notifications.show({ title: 'Import Gagal', message: error.message, color: 'red' })
    },
  })

  const handleImport = () => {
    setProgress(0)
    setImportResult(null)
    setCurrentPhase('pasal')
    importMutation.mutate()
  }

  const downloadXlsxTemplate = () => {
    const templateData = [
      {
        nomor: '1',
        judul: 'Contoh Judul Pasal',
        isi: 'Isi lengkap pasal. Tuliskan seluruh isi pasal di kolom ini.',
        penjelasan: 'Penjelasan, tafsir, atau pendapat ahli (opsional)',
        keywords: 'keyword1, keyword2, keyword3',
        link1_targetUU: 'KUHAP',
        link1_targetNomor: '21',
        link1_keterangan: 'Lihat prosedur penyidikan',
      },
    ]

    const ws = XLSX.utils.json_to_sheet(templateData)
    ws['!cols'] = [
      { wch: 10 },
      { wch: 25 },
      { wch: 50 },
      { wch: 35 },
      { wch: 25 },
      { wch: 12 },
      { wch: 15 },
      { wch: 25 },
    ]
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, 'Data Pasal')
    XLSX.writeFile(wb, 'template-import-pasal.xlsx')
  }

  const canImport = selectedUU && (mode === 'ocr' ? ocrDrafts.length > 0 && ocrInvalidCount === 0 : Boolean(excelRows?.length))
  const ocrValidCount = Math.max(0, ocrDrafts.length - ocrInvalidCount)
  const hasOcrSession = mode === 'ocr' && (isOcrProcessing || ocrRawText.trim().length > 0 || ocrDrafts.length > 0)
  const selectedUULabel = selectedUU
    ? undangUndangList?.find((uu) => uu.id === selectedUU)
    : null

  return (
    <Stack gap="lg">
      <Group justify="space-between" align="flex-end" wrap="wrap">
        <div>
          <Title order={2}>Import Data Pasal</Title>
          <Text c="dimmed">Import banyak pasal dari Excel atau foto halaman buku hukum</Text>
        </div>
      </Group>

      <Card shadow="sm" padding="lg" radius="md" withBorder className="bulk-import-tool">
        <Stack gap="lg">
          {hasOcrSession && (
            <Group gap="xs" wrap="wrap">
              <Badge variant="light" color="blue">
                Target: {selectedUULabel ? selectedUULabel.kode : 'Belum dipilih'}
              </Badge>
              <Badge variant="light" color="teal">
                {ocrDrafts.length} draft pasal
              </Badge>
              <Badge variant="light" color={ocrInvalidCount > 0 ? 'red' : 'green'}>
                {ocrValidCount} valid, {ocrInvalidCount} perlu dicek
              </Badge>
            </Group>
          )}

          <Select
            label="Pilih Undang-Undang"
            description="Semua draft yang diimport akan masuk ke undang-undang ini."
            placeholder="Cari kode atau nama undang-undang"
            data={undangUndangList?.map((uu) => ({ value: uu.id, label: `${uu.kode} - ${uu.nama}` })) || []}
            value={selectedUU}
            onChange={setSelectedUU}
            searchable
            required
          />

          <Tabs value={mode} onChange={setMode}>
            <Tabs.List>
              <Tabs.Tab value="ocr" leftSection={<IconPhotoScan size={16} />}>Foto OCR</Tabs.Tab>
              <Tabs.Tab value="excel" leftSection={<IconFileSpreadsheet size={16} />}>Excel</Tabs.Tab>
            </Tabs.List>

            <Tabs.Panel value="ocr" pt="md">
              <Stack gap="lg">
                <Card withBorder radius="md" padding="md">
                  <Group justify="space-between" align="flex-start" mb="md" wrap="wrap">
                    <div>
                      <Group gap="xs" mb={4}>
                        <IconPhotoScan size={18} />
                        <Text fw={700}>Foto halaman buku hukum</Text>
                      </Group>
                      <Text c="dimmed" size="sm">
                        Ambil foto atau upload gambar, lalu periksa draft pasal sebelum disimpan.
                      </Text>
                    </div>
                    <Badge color="blue" variant="light">Utama</Badge>
                  </Group>

                  <Group grow={isMobile}>
                    <Button component="label" leftSection={<IconCamera size={16} />} loading={isOcrProcessing}>
                      Ambil / Upload Foto
                      <input
                        hidden
                        type="file"
                        accept="image/*"
                        capture="environment"
                        multiple
                        onChange={(event) => {
                          if (event.currentTarget.files) void processOcrFiles(event.currentTarget.files)
                          event.currentTarget.value = ''
                        }}
                      />
                    </Button>
                    <Button variant="light" leftSection={<IconWand size={16} />} onClick={reparseOcrText} disabled={!ocrRawText || isOcrProcessing}>
                      Rapikan Teks
                    </Button>
                  </Group>
                </Card>

                {isOcrProcessing && (
                  <Card withBorder radius="md" padding="md">
                    <Group justify="space-between" mb="xs">
                      <Text size="sm" fw={700}>{ocrPhase || 'Memproses OCR'}</Text>
                      <Text size="sm" c="dimmed">{ocrProgress}%</Text>
                    </Group>
                    <Progress value={ocrProgress} animated />
                  </Card>
                )}

                <SimpleGrid cols={{ base: 1, md: showOcrRawText ? 2 : 1 }} spacing="md">
                  <Card withBorder radius="md" padding="md">
                    <Group gap="xs" mb="sm">
                      <IconListCheck size={16} />
                      <Text fw={700}>Agar hasil lebih rapi</Text>
                    </Group>
                    <Stack gap={6}>
                      <Text size="sm">Gunakan cahaya rata dan hindari bayangan tangan.</Text>
                      <Text size="sm">Pastikan halaman lurus, tidak miring, dan teks memenuhi frame.</Text>
                      <Text size="sm">Periksa kembali hasil bacaan sebelum disimpan.</Text>
                    </Stack>
                    <Button
                      mt="sm"
                      variant="subtle"
                      size="xs"
                      leftSection={<IconWand size={14} />}
                      onClick={() => setShowOcrRawText((visible) => !visible)}
                    >
                      {showOcrRawText ? 'Sembunyikan teks mentah' : 'Tampilkan teks mentah / paste manual'}
                    </Button>
                  </Card>
                  {showOcrRawText && (
                    <Card withBorder radius="md" padding="md">
                      <Textarea
                        label="Teks mentah"
                        description="Pakai ini hanya jika perlu memperbaiki hasil bacaan sebelum dibuat draft."
                        minRows={9}
                        autosize
                        value={ocrRawText}
                        onChange={(event) => setOcrRawText(event.currentTarget.value)}
                      />
                    </Card>
                  )}
                </SimpleGrid>

                {ocrDrafts.length > 0 && (
                  <Card withBorder radius="md" padding="md">
                    <Group justify="space-between" align="center" mb="md">
                      <div>
                        <Text fw={800}>Periksa Draft Pasal</Text>
                        <Text size="sm" c="dimmed">{ocrDrafts.length} pasal ditemukan. Edit teks sebelum disimpan.</Text>
                      </div>
                      {ocrInvalidCount > 0 && <Badge color="red">{ocrInvalidCount} perlu diperbaiki</Badge>}
                      {ocrInvalidCount === 0 && <Badge color="green">{ocrDrafts.length} siap diimport</Badge>}
                    </Group>
                    <Stack gap="md" hiddenFrom="sm">
                      {ocrDrafts.map((draft) => {
                        const errors = draftErrors(draft, ocrDrafts)
                        return (
                          <Card key={draft.id} withBorder padding="sm" radius="md">
                            <Stack gap="sm">
                              <Group justify="space-between" align="center" wrap="nowrap">
                                <div>
                                  <Text size="xs" c="dimmed" tt="uppercase" fw={700}>Draft OCR</Text>
                                  <Text size="xs" c="dimmed">{draft.source}</Text>
                                </div>
                                <ActionIcon color="red" variant="subtle" onClick={() => removeDraft(draft.id)}>
                                  <IconTrash size={16} />
                                </ActionIcon>
                              </Group>

                              <TextInput
                                label="Nomor"
                                value={draft.nomor}
                                onChange={(event) => updateDraft(draft.id, { nomor: event.currentTarget.value })}
                              />
                              <TextInput
                                label="Judul"
                                value={draft.judul || ''}
                                onChange={(event) => updateDraft(draft.id, { judul: event.currentTarget.value })}
                              />
                              <Textarea
                                label="Isi"
                                value={draft.isi}
                                onChange={(event) => updateDraft(draft.id, { isi: event.currentTarget.value })}
                                minRows={5}
                                autosize
                              />
                              <Textarea
                                label="Penjelasan / Pendapat Ahli"
                                value={draft.penjelasan || ''}
                                onChange={(event) => updateDraft(draft.id, { penjelasan: event.currentTarget.value })}
                                minRows={4}
                                autosize
                              />
                              <TagsInput
                                label="Keywords"
                                value={draft.keywords || []}
                                onChange={(keywords) => updateDraft(draft.id, { keywords })}
                              />
                              {errors.length === 0 ? <Badge color="green">Valid</Badge> : <Badge color="red">{errors.join(', ')}</Badge>}
                            </Stack>
                          </Card>
                        )
                      })}
                    </Stack>

                    <Stack gap="md" visibleFrom="sm">
                      {ocrDrafts.map((draft) => {
                        const errors = draftErrors(draft, ocrDrafts)
                        return (
                          <Card key={draft.id} withBorder radius="md" padding="md">
                            <Group justify="space-between" align="flex-start" mb="md" wrap="nowrap">
                              <div>
                                <Text size="xs" c="dimmed" tt="uppercase" fw={700}>Draft Pasal</Text>
                                <Text size="sm" c="dimmed">{draft.source}</Text>
                              </div>
                              <Group gap="xs" wrap="nowrap">
                                {errors.length === 0 ? <Badge color="green">Valid</Badge> : <Badge color="red">{errors.join(', ')}</Badge>}
                                <ActionIcon color="red" variant="subtle" onClick={() => removeDraft(draft.id)}>
                                  <IconTrash size={16} />
                                </ActionIcon>
                              </Group>
                            </Group>

                            <Box className="ocr-draft-desktop-grid">
                              <Box className="ocr-field-number">
                                <TextInput
                                  label="Nomor"
                                  value={draft.nomor}
                                  onChange={(event) => updateDraft(draft.id, { nomor: event.currentTarget.value })}
                                />
                              </Box>
                              <Box className="ocr-field-title">
                                <TextInput
                                  label="Judul"
                                  value={draft.judul || ''}
                                  onChange={(event) => updateDraft(draft.id, { judul: event.currentTarget.value })}
                                />
                              </Box>
                              <Box className="ocr-field-keywords">
                                <TagsInput
                                  label="Keywords"
                                  value={draft.keywords || []}
                                  onChange={(keywords) => updateDraft(draft.id, { keywords })}
                                />
                              </Box>
                              <Box className="ocr-field-body">
                                <Textarea
                                  label="Isi Pasal"
                                  value={draft.isi}
                                  onChange={(event) => updateDraft(draft.id, { isi: event.currentTarget.value })}
                                  minRows={6}
                                  autosize
                                />
                              </Box>
                              <Box className="ocr-field-note">
                                <Textarea
                                  label="Penjelasan / Pendapat Ahli"
                                  value={draft.penjelasan || ''}
                                  onChange={(event) => updateDraft(draft.id, { penjelasan: event.currentTarget.value })}
                                  minRows={6}
                                  autosize
                                />
                              </Box>
                            </Box>
                          </Card>
                        )
                      })}
                    </Stack>
                  </Card>
                )}
              </Stack>
            </Tabs.Panel>

            <Tabs.Panel value="excel" pt="md">
              <Stack gap="md">
                <Alert icon={<IconFileSpreadsheet size={16} />} title="Format File Excel (XLSX)" color="blue">
                  <Text size="sm" mb="sm">
                    Download template Excel untuk melihat format kolom yang diperlukan.
                  </Text>
                  <Button variant="light" size="xs" leftSection={<IconDownload size={14} />} onClick={downloadXlsxTemplate}>
                    Download Template Excel
                  </Button>
                </Alert>

                <Dropzone
                  onDrop={handleFileDrop}
                  accept={{
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'],
                    'application/vnd.ms-excel': ['.xls'],
                  }}
                  maxSize={5 * 1024 * 1024}
                  multiple={false}
                >
                  <Group justify="center" gap="md" mih={120} style={{ pointerEvents: 'none', flexDirection: 'column' }}>
                    <Dropzone.Accept><IconCheck size={40} /></Dropzone.Accept>
                    <Dropzone.Reject><IconX size={40} /></Dropzone.Reject>
                    <Dropzone.Idle><IconUpload size={40} /></Dropzone.Idle>
                    <div style={{ textAlign: 'center' }}>
                      <Text size="lg">Drag file Excel ke sini</Text>
                      <Text size="sm" c="dimmed">atau klik untuk browse (Max 5MB)</Text>
                    </div>
                  </Group>
                </Dropzone>

                {excelRows && (
                  <Alert icon={<IconCheck size={16} />} color="green">
                    File <strong>{fileName}</strong> berhasil dibaca. <strong>{excelRows.length}</strong> pasal siap diimport.
                  </Alert>
                )}
              </Stack>
            </Tabs.Panel>
          </Tabs>

          {importMutation.isPending && (
            <div>
              <Text size="sm" mb="xs">
                {currentPhase === 'pasal' ? 'Membuat pasal' : 'Membuat link antar pasal'}... {progress}%
              </Text>
              <Progress value={progress} animated />
            </div>
          )}

          {importResult && (
            <Alert
              icon={(importResult.pasal.failed === 0 && importResult.links.failed === 0) ? <IconCheck size={16} /> : <IconAlertCircle size={16} />}
              color={(importResult.pasal.failed === 0 && importResult.links.failed === 0) ? 'green' : 'orange'}
              title="Hasil Import"
            >
              <Text size="sm">
                Pasal berhasil: {importResult.pasal.success}
                {importResult.pasal.failed > 0 && ` | Pasal gagal: ${importResult.pasal.failed}`}
                {` | Link berhasil: ${importResult.links.success}`}
                {importResult.links.failed > 0 && ` | Link gagal: ${importResult.links.failed}`}
              </Text>
            </Alert>
          )}

          <Group justify="flex-end">
            <Button onClick={handleImport} loading={importMutation.isPending} disabled={!canImport} fullWidth={isMobile}>
              Import Data
            </Button>
          </Group>
        </Stack>
      </Card>

      {mode === 'excel' && <XlsxImportGuide />}
    </Stack>
  )
}
