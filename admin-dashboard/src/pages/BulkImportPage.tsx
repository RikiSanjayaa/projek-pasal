import { useState, useCallback } from 'react'
import {
  Title,
  Text,
  Stack,
  Card,
  Group,
  Button,
  Select,
  Table,
  Badge,
  Alert,
  Progress,
  ScrollArea,
  Accordion,
} from '@mantine/core'
import { Dropzone } from '@mantine/dropzone'
import { notifications } from '@mantine/notifications'
import {
  IconUpload,

  IconX,
  IconCheck,
  IconAlertCircle,
  IconDownload,
  IconFileSpreadsheet,
} from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import * as XLSX from 'xlsx'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/contexts/AuthContext'
import { XlsxImportGuide } from '@/components/bulk-import/XlsxImportGuide'
import type { PasalInsert } from '@/lib/database.types'



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

export function BulkImportPage() {
  const queryClient = useQueryClient()
  const { user } = useAuth()
  const [selectedUU, setSelectedUU] = useState<string | null>(null)
  const [jsonData, setJsonData] = useState<ImportPasal[] | null>(null)
  const [fileName, setFileName] = useState<string>('')
  const [importResult, setImportResult] = useState<ImportResult | null>(null)
  const [progress, setProgress] = useState(0)
  const [currentPhase, setCurrentPhase] = useState<'pasal' | 'links'>('pasal')

  // Fetch undang-undang
  const { data: undangUndangList } = useQuery({
    queryKey: ['undang_undang', 'list'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('undang_undang')
        .select('id, kode, nama')
        .eq('is_active', true)
        .order('kode')

      if (error) throw error
      return data as { id: string; kode: string; nama: string }[]
    },
  })

  // Parse XLSX file to ImportPasal array
  const parseXlsxFile = useCallback((data: ArrayBuffer): ImportPasal[] => {
    const workbook = XLSX.read(data, { type: 'array' })
    const sheetName = workbook.SheetNames[0]
    const worksheet = workbook.Sheets[sheetName]

    // Convert to JSON with header row
    const rows = XLSX.utils.sheet_to_json<Record<string, any>>(worksheet, { defval: '' })

    if (rows.length === 0) {
      throw new Error('File XLSX kosong atau tidak memiliki data')
    }

    const validated: ImportPasal[] = rows.map((row, index) => {
      const rowNum = index + 2 // +2 because row 1 is header, data starts at row 2

      // Get basic fields (trim whitespace)
      const nomor = String(row['nomor'] || '').trim()
      const judul = String(row['judul'] || '').trim() || undefined
      const isi = String(row['isi'] || '').trim()
      const penjelasan = String(row['penjelasan'] || '').trim() || undefined
      const keywordsRaw = String(row['keywords'] || '').trim()

      // Validate required fields
      if (!nomor) {
        throw new Error(`Baris ${rowNum}: kolom "nomor" wajib diisi`)
      }
      if (!isi) {
        throw new Error(`Baris ${rowNum}: kolom "isi" wajib diisi`)
      }

      // Parse keywords (comma-separated)
      const keywords = keywordsRaw
        ? keywordsRaw.split(',').map((k: string) => k.trim()).filter((k: string) => k.length > 0)
        : []

      // Parse links from columns link1_targetUU, link1_targetNomor, link1_keterangan, etc.
      const links: PasalLink[] = []
      for (let i = 1; i <= MAX_LINKS_PER_PASAL; i++) {
        const targetUU = String(row[`link${i}_targetUU`] || '').trim()
        const targetNomor = String(row[`link${i}_targetNomor`] || '').trim()
        const keterangan = String(row[`link${i}_keterangan`] || '').trim() || undefined

        // Only add if both targetUU and targetNomor are provided
        if (targetUU && targetNomor) {
          links.push({ targetUU, targetNomor, keterangan })
        } else if (targetUU && !targetNomor) {
          throw new Error(`Baris ${rowNum}: link${i}_targetNomor wajib diisi jika link${i}_targetUU diisi`)
        } else if (!targetUU && targetNomor) {
          throw new Error(`Baris ${rowNum}: link${i}_targetUU wajib diisi jika link${i}_targetNomor diisi`)
        }
      }

      return {
        nomor,
        judul,
        isi,
        penjelasan,
        keywords,
        links: links.length > 0 ? links : undefined,
      }
    })

    return validated
  }, [])



  const handleFileDrop = useCallback((files: File[]) => {
    const file = files[0]
    if (!file) return

    setFileName(file.name)
    setImportResult(null)

    // Read as ArrayBuffer for XLSX
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const data = e.target?.result as ArrayBuffer
        const validated = parseXlsxFile(data)

        setJsonData(validated)
        notifications.show({
          title: 'File berhasil dibaca',
          message: `${validated.length} pasal siap diimport`,
          color: 'green',
        })
      } catch (error: any) {
        notifications.show({
          title: 'Format XLSX tidak valid',
          message: error.message,
          color: 'red',
        })
        setJsonData(null)
      }
    }
    reader.readAsArrayBuffer(file)
  }, [parseXlsxFile])

  // Import mutation
  const importMutation = useMutation({
    mutationFn: async () => {
      if (!selectedUU || !jsonData) {
        throw new Error('Pilih undang-undang dan upload file terlebih dahulu')
      }

      const result: ImportResult = {
        pasal: {
          success: 0,
          failed: 0,
          errors: [],
        },
        links: {
          success: 0,
          failed: 0,
          errors: [],
        },
      }

      // ===== PHASE 1: Create Pasal =====
      setCurrentPhase('pasal')
      const pasalIdMap = new Map<string, string>() // Map of "UU_kode|nomor" -> pasal_id
      const total = jsonData.length

      // Fetch all active undang-undang to build lookup
      const { data: allUU, error: uuError } = await supabase
        .from('undang_undang')
        .select('id, kode')
        .eq('is_active', true)

      if (uuError) throw uuError

      const uuMap = new Map(allUU?.map((uu: any) => [uu.kode, uu.id]) || [])

      for (let i = 0; i < jsonData.length; i++) {
        const item = jsonData[i]
        setProgress(Math.round(((i + 1) / total) * 100))

        const pasalData: PasalInsert = {
          undang_undang_id: selectedUU,
          nomor: item.nomor,
          judul: item.judul || null,
          isi: item.isi,
          penjelasan: item.penjelasan || null,
          keywords: item.keywords || [],
          created_by: user?.id,
          updated_by: user?.id,
        }

        const { data: insertedPasal, error } = await supabase
          .from('pasal')
          .insert(pasalData as never)
          .select('id')
          .single()

        if (error) {
          result.pasal.failed++
          result.pasal.errors.push({
            nomor: item.nomor,
            error: error.message,
          })
        } else if (insertedPasal) {
          result.pasal.success++
          pasalIdMap.set(`${selectedUU}|${item.nomor}`, (insertedPasal as any).id)
        }
      }

      // ===== PHASE 2: Create Links =====
      setCurrentPhase('links')
      const linksToCreate: Array<{ source_pasal_id: string; target_pasal_id: string; keterangan: string | null; created_by: string | undefined }> = []

      for (const item of jsonData) {
        if (!item.links || item.links.length === 0) continue

        const sourcePasalId = pasalIdMap.get(`${selectedUU}|${item.nomor}`)
        if (!sourcePasalId) continue // Skip if source pasal wasn't created

        for (const link of item.links) {
          const targetUUID = uuMap.get(link.targetUU)
          if (!targetUUID) {
            result.links.failed++
            result.links.errors.push({
              source: `${item.nomor}`,
              target: `${link.targetUU}|${link.targetNomor}`,
              error: `Undang-undang "${link.targetUU}" tidak ditemukan atau tidak aktif`,
            })
            continue
          }

          // Try to find target pasal in database
          const { data: targetPasal, error: findError } = await supabase
            .from('pasal')
            .select('id')
            .eq('undang_undang_id', targetUUID)
            .eq('nomor', link.targetNomor)
            .single()

          if (findError || !targetPasal) {
            result.links.failed++
            result.links.errors.push({
              source: `${item.nomor}`,
              target: `${link.targetUU}|${link.targetNomor}`,
              error: `Pasal "${link.targetNomor}" di ${link.targetUU} tidak ditemukan`,
            })
            continue
          }

          linksToCreate.push({
            source_pasal_id: sourcePasalId,
            target_pasal_id: (targetPasal as any).id as any,
            keterangan: link.keterangan || null,
            created_by: user?.id,
          })
        }
      }

      // Insert all resolved links in batches
      const linkBatchSize = 50
      for (let i = 0; i < linksToCreate.length; i += linkBatchSize) {
        const batch = linksToCreate.slice(i, i + linkBatchSize)
        setProgress(Math.round((i / linksToCreate.length) * 100))

        const { error: insertError } = await supabase.from('pasal_links').insert(batch as never)

        if (insertError) {
          result.links.failed += batch.length
          batch.forEach(() => {
            result.links.errors.push({
              source: '',
              target: '',
              error: insertError.message,
            })
          })
        } else {
          result.links.success += batch.length
        }
      }

      if (linksToCreate.length > 0) {
        setProgress(100)
      }

      return result
    },
    onSuccess: (result) => {
      setImportResult(result)
      queryClient.invalidateQueries({ queryKey: ['pasal'] })

      const totalFailed = result.pasal.failed + result.links.failed
      const totalSuccess = result.pasal.success + result.links.success

      if (totalFailed === 0) {
        notifications.show({
          title: 'Import Berhasil',
          message: `${result.pasal.success} pasal dan ${result.links.success} link berhasil diimport`,
          color: 'green',
        })
      } else {
        notifications.show({
          title: 'Import Selesai dengan Error',
          message: `${totalSuccess} berhasil, ${totalFailed} gagal`,
          color: 'orange',
        })
      }
    },
    onError: (error: Error) => {
      notifications.show({
        title: 'Import Gagal',
        message: error.message,
        color: 'red',
      })
    },
  })

  const handleImport = () => {
    setProgress(0)
    setImportResult(null)
    setCurrentPhase('pasal')
    importMutation.mutate()
  }



  const downloadXlsxTemplate = () => {
    // Create template data with example rows
    const templateData = [
      {
        nomor: '1',
        judul: 'Contoh Judul Pasal',
        isi: 'Isi lengkap pasal. Tuliskan seluruh isi pasal di kolom ini.',
        penjelasan: 'Penjelasan atau tafsir pasal (opsional)',
        keywords: 'keyword1, keyword2, keyword3',
        link1_targetUU: 'KUHAP',
        link1_targetNomor: '21',
        link1_keterangan: 'Lihat prosedur penyidikan',
        link2_targetUU: '',
        link2_targetNomor: '',
        link2_keterangan: '',
        link3_targetUU: '',
        link3_targetNomor: '',
        link3_keterangan: '',
        link4_targetUU: '',
        link4_targetNomor: '',
        link4_keterangan: '',
        link5_targetUU: '',
        link5_targetNomor: '',
        link5_keterangan: '',
      },
      {
        nomor: '2',
        judul: '',
        isi: 'Pasal tanpa judul. Kolom judul boleh dikosongkan.',
        penjelasan: '',
        keywords: 'pidana, hukum',
        link1_targetUU: 'KUHP',
        link1_targetNomor: '340',
        link1_keterangan: 'Pasal terkait',
        link2_targetUU: 'KUHAP',
        link2_targetNomor: '1',
        link2_keterangan: 'Definisi umum',
        link3_targetUU: '',
        link3_targetNomor: '',
        link3_keterangan: '',
        link4_targetUU: '',
        link4_targetNomor: '',
        link4_keterangan: '',
        link5_targetUU: '',
        link5_targetNomor: '',
        link5_keterangan: '',
      },
      {
        nomor: '3',
        judul: 'Pasal Tanpa Link',
        isi: 'Pasal ini tidak memiliki link ke pasal lain. Kosongkan semua kolom link.',
        penjelasan: 'Penjelasan singkat',
        keywords: '',
        link1_targetUU: '',
        link1_targetNomor: '',
        link1_keterangan: '',
        link2_targetUU: '',
        link2_targetNomor: '',
        link2_keterangan: '',
        link3_targetUU: '',
        link3_targetNomor: '',
        link3_keterangan: '',
        link4_targetUU: '',
        link4_targetNomor: '',
        link4_keterangan: '',
        link5_targetUU: '',
        link5_targetNomor: '',
        link5_keterangan: '',
      },
    ]

    // Create worksheet
    const ws = XLSX.utils.json_to_sheet(templateData)

    // Set column widths for better readability
    ws['!cols'] = [
      { wch: 10 },  // nomor
      { wch: 25 },  // judul
      { wch: 50 },  // isi
      { wch: 30 },  // penjelasan
      { wch: 25 },  // keywords
      { wch: 12 },  // link1_targetUU
      { wch: 15 },  // link1_targetNomor
      { wch: 25 },  // link1_keterangan
      { wch: 12 },  // link2_targetUU
      { wch: 15 },  // link2_targetNomor
      { wch: 25 },  // link2_keterangan
      { wch: 12 },  // link3_targetUU
      { wch: 15 },  // link3_targetNomor
      { wch: 25 },  // link3_keterangan
      { wch: 12 },  // link4_targetUU
      { wch: 15 },  // link4_targetNomor
      { wch: 25 },  // link4_keterangan
      { wch: 12 },  // link5_targetUU
      { wch: 15 },  // link5_targetNomor
      { wch: 25 },  // link5_keterangan
    ]

    // Create workbook
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, 'Data Pasal')

    // Download file
    XLSX.writeFile(wb, 'template-import-pasal.xlsx')
  }

  return (
    <Stack gap="lg">
      <Group justify="space-between" align="flex-end">
        <div>
          <Title order={2}>Import Data Pasal</Title>
          <Text c="dimmed">Import banyak pasal sekaligus menggunakan file Excel (XLSX)</Text>
        </div>
      </Group>

      {/* Template Download */}
      <Alert
        icon={<IconFileSpreadsheet size={16} />}
        title="Format File Excel (XLSX)"
        color="blue"
      >
        <Text size="sm" mb="sm">
          Download template Excel untuk melihat format kolom yang diperlukan. Buka dengan Microsoft Excel atau Google Sheets.
        </Text>
        <Button
          variant="light"
          size="xs"
          leftSection={<IconDownload size={14} />}
          onClick={downloadXlsxTemplate}
        >
          Download Template Excel
        </Button>
      </Alert>

      <Card shadow="sm" padding="lg" radius="md" withBorder>
        <Stack gap="md">
          <Select
            label="Pilih Undang-Undang"
            placeholder="Pasal akan diimport ke undang-undang ini"
            data={
              undangUndangList?.map((uu) => ({
                value: uu.id,
                label: `${uu.kode} - ${uu.nama}`,
              })) || []
            }
            value={selectedUU}
            onChange={setSelectedUU}
            required
          />

          <Dropzone
            onDrop={handleFileDrop}
            accept={{
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'],
              'application/vnd.ms-excel': ['.xls'],
            }}
            maxSize={5 * 1024 * 1024} // 5MB
            multiple={false}
            style={{
              border: '2px dashed var(--mantine-color-default-border)',
              backgroundColor: 'var(--mantine-color-body)',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center'
            }}
          >
            <Group justify="center" gap="md" mih={120} style={{ pointerEvents: 'none', flexDirection: 'column' }}>
              <Dropzone.Accept>
                <IconCheck size={40} color="var(--mantine-color-teal-6)" />
              </Dropzone.Accept>
              <Dropzone.Reject>
                <IconX size={40} color="var(--mantine-color-red-6)" />
              </Dropzone.Reject>
              <Dropzone.Idle>
                <IconUpload size={40} color="var(--mantine-color-dimmed)" />
              </Dropzone.Idle>

              <div style={{ textAlign: 'center' }}>
                <Text size="lg" inline>
                  Drag file Excel ke sini
                </Text>
                <Text size="sm" c="dimmed" inline mt={7}>
                  atau klik untuk browse (Max 5MB)
                </Text>
              </div>
            </Group>
          </Dropzone>

          {jsonData && (
            <Alert icon={<IconCheck size={16} />} color="green">
              <Text size="sm">
                File <strong>{fileName}</strong> berhasil dibaca.{' '}
                <strong>{jsonData.length}</strong> pasal siap diimport.
              </Text>
            </Alert>
          )}

          {/* Preview Data */}
          {jsonData && jsonData.length > 0 && (
            <Accordion>
              <Accordion.Item value="preview">
                <Accordion.Control>
                  Preview Data ({jsonData.length} pasal)
                </Accordion.Control>
                <Accordion.Panel>
                  <ScrollArea h={300}>
                    <Table striped>
                      <Table.Thead>
                        <Table.Tr>
                          <Table.Th>Nomor</Table.Th>
                          <Table.Th>Judul</Table.Th>
                          <Table.Th>Keywords</Table.Th>
                        </Table.Tr>
                      </Table.Thead>
                      <Table.Tbody>
                        {jsonData.map((item, idx) => (
                          <Table.Tr key={idx}>
                            <Table.Td>{item.nomor}</Table.Td>
                            <Table.Td>{item.judul || '-'}</Table.Td>
                            <Table.Td>
                              <Group gap={4}>
                                {item.keywords?.slice(0, 3).map((kw, i) => (
                                  <Badge key={i} size="xs" variant="outline">
                                    {kw}
                                  </Badge>
                                ))}
                              </Group>
                            </Table.Td>
                          </Table.Tr>
                        ))}
                      </Table.Tbody>
                    </Table>
                  </ScrollArea>
                </Accordion.Panel>
              </Accordion.Item>
            </Accordion>
          )}

          {/* Progress */}
          {importMutation.isPending && (
            <div>
              <Text size="sm" mb="xs">
                {currentPhase === 'pasal' ? 'Membuat pasal' : 'Membuat link antar pasal'}... {progress}%
              </Text>
              <Progress value={progress} animated />
            </div>
          )}

          {/* Results */}
          {importResult && (
            <Stack gap="sm">
              <Alert
                icon={(importResult.pasal.failed === 0 && importResult.links.failed === 0) ? <IconCheck size={16} /> : <IconAlertCircle size={16} />}
                color={(importResult.pasal.failed === 0 && importResult.links.failed === 0) ? 'green' : 'orange'}
                title="Hasil Import"
              >
                <Stack gap="xs">
                  <div>
                    <Text size="sm" fw={600}>Pasal:</Text>
                    <Text size="sm">
                      Berhasil: {importResult.pasal.success}
                      {importResult.pasal.failed > 0 && ` | Gagal: ${importResult.pasal.failed}`}
                    </Text>
                  </div>
                  {(importResult.links.success > 0 || importResult.links.failed > 0) && (
                    <div>
                      <Text size="sm" fw={600}>Link Pasal:</Text>
                      <Text size="sm">
                        Berhasil: {importResult.links.success}
                        {importResult.links.failed > 0 && ` | Gagal: ${importResult.links.failed}`}
                      </Text>
                    </div>
                  )}
                </Stack>
              </Alert>

              {importResult.pasal.errors.length > 0 && (
                <Accordion>
                  <Accordion.Item value="pasal-errors">
                    <Accordion.Control>
                      Error Pasal ({importResult.pasal.errors.length})
                    </Accordion.Control>
                    <Accordion.Panel>
                      <ScrollArea h={200}>
                        <Stack gap="xs">
                          {importResult.pasal.errors.map((err, idx) => (
                            <Alert key={idx} color="red" p="xs">
                              <Text size="sm">
                                Pasal {err.nomor}: {err.error}
                              </Text>
                            </Alert>
                          ))}
                        </Stack>
                      </ScrollArea>
                    </Accordion.Panel>
                  </Accordion.Item>
                </Accordion>
              )}

              {importResult.links.errors.length > 0 && (
                <Accordion>
                  <Accordion.Item value="link-errors">
                    <Accordion.Control>
                      Error Link ({importResult.links.errors.length})
                    </Accordion.Control>
                    <Accordion.Panel>
                      <ScrollArea h={200}>
                        <Stack gap="xs">
                          {importResult.links.errors.map((err, idx) => (
                            <Alert key={idx} color="red" p="xs">
                              <Text size="sm">
                                {err.source} {'->'} {err.target}: {err.error}
                              </Text>
                            </Alert>
                          ))}
                        </Stack>
                      </ScrollArea>
                    </Accordion.Panel>
                  </Accordion.Item>
                </Accordion>
              )}
            </Stack>
          )}

          <Group justify="flex-end">
            <Button
              onClick={handleImport}
              loading={importMutation.isPending}
              disabled={!selectedUU || !jsonData}
            >
              Import Data
            </Button>
          </Group>
        </Stack>
      </Card>

      <XlsxImportGuide />
    </Stack>
  )
}
