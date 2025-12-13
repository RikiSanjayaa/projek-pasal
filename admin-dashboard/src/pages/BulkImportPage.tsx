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
  Code,
  ScrollArea,
  Accordion,
} from '@mantine/core'
import { Dropzone } from '@mantine/dropzone'
import { notifications } from '@mantine/notifications'
import {
  IconUpload,
  IconFileCode,
  IconX,
  IconCheck,
  IconAlertCircle,
  IconDownload,
} from '@tabler/icons-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/contexts/AuthContext'
import type { PasalInsert } from '@/lib/database.types'

interface ImportPasal {
  nomor: string
  judul?: string
  isi: string
  penjelasan?: string
  keywords?: string[]
}

interface ImportResult {
  success: number
  failed: number
  errors: { nomor: string; error: string }[]
}

export function BulkImportPage() {
  const queryClient = useQueryClient()
  const { user } = useAuth()
  const [selectedUU, setSelectedUU] = useState<string | null>(null)
  const [jsonData, setJsonData] = useState<ImportPasal[] | null>(null)
  const [fileName, setFileName] = useState<string>('')
  const [importResult, setImportResult] = useState<ImportResult | null>(null)
  const [progress, setProgress] = useState(0)

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

  const handleFileDrop = useCallback((files: File[]) => {
    const file = files[0]
    if (!file) return

    setFileName(file.name)
    setImportResult(null)

    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const content = e.target?.result as string
        const parsed = JSON.parse(content)

        // Validate structure
        if (!Array.isArray(parsed)) {
          throw new Error('JSON harus berupa array')
        }

        // Validate each item
        const validated: ImportPasal[] = parsed.map((item: any, index: number) => {
          if (!item.nomor) {
            throw new Error(`Item ${index + 1}: field "nomor" wajib diisi`)
          }
          if (!item.isi) {
            throw new Error(`Item ${index + 1}: field "isi" wajib diisi`)
          }
          return {
            nomor: String(item.nomor),
            judul: item.judul || null,
            isi: item.isi,
            penjelasan: item.penjelasan || null,
            keywords: Array.isArray(item.keywords) ? item.keywords : [],
          }
        })

        setJsonData(validated)
        notifications.show({
          title: 'File berhasil dibaca',
          message: `${validated.length} pasal siap diimport`,
          color: 'green',
        })
      } catch (error: any) {
        notifications.show({
          title: 'Format JSON tidak valid',
          message: error.message,
          color: 'red',
        })
        setJsonData(null)
      }
    }

    reader.readAsText(file)
  }, [])

  // Import mutation
  const importMutation = useMutation({
    mutationFn: async () => {
      if (!selectedUU || !jsonData) {
        throw new Error('Pilih undang-undang dan upload file terlebih dahulu')
      }

      const result: ImportResult = {
        success: 0,
        failed: 0,
        errors: [],
      }

      const total = jsonData.length

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

        const { error } = await supabase.from('pasal').insert(pasalData as never)

        if (error) {
          result.failed++
          result.errors.push({
            nomor: item.nomor,
            error: error.message,
          })
        } else {
          result.success++
        }
      }

      return result
    },
    onSuccess: (result) => {
      setImportResult(result)
      queryClient.invalidateQueries({ queryKey: ['pasal'] })

      if (result.failed === 0) {
        notifications.show({
          title: 'Import Berhasil',
          message: `${result.success} pasal berhasil diimport`,
          color: 'green',
        })
      } else {
        notifications.show({
          title: 'Import Selesai dengan Error',
          message: `${result.success} berhasil, ${result.failed} gagal`,
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
    importMutation.mutate()
  }

  const downloadTemplate = () => {
    const template: ImportPasal[] = [
      {
        nomor: "1",
        judul: "Contoh Judul Pasal",
        isi: "Isi lengkap pasal...",
        penjelasan: "Penjelasan atau tafsir pasal (opsional)",
        keywords: ["keyword1", "keyword2"]
      },
      {
        nomor: "2",
        isi: "Pasal tanpa judul...",
        keywords: []
      }
    ]

    const blob = new Blob([JSON.stringify(template, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'template-import-pasal.json'
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  return (
    <Stack gap="lg">
      <div>
        <Title order={2}>Import Data Pasal</Title>
        <Text c="dimmed">Import banyak pasal sekaligus menggunakan file JSON</Text>
      </div>

      {/* Template Download */}
      <Alert
        icon={<IconFileCode size={16} />}
        title="Format File JSON"
        color="blue"
      >
        <Text size="sm" mb="sm">
          Download template JSON untuk melihat format yang diperlukan.
        </Text>
        <Button
          variant="light"
          size="xs"
          leftSection={<IconDownload size={14} />}
          onClick={downloadTemplate}
        >
          Download Template
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
            accept={['application/json']}
            maxSize={5 * 1024 * 1024} // 5MB
            multiple={false}
          >
            <Group justify="center" gap="xl" mih={120} style={{ pointerEvents: 'none' }}>
              <Dropzone.Accept>
                <IconCheck size={50} color="green" />
              </Dropzone.Accept>
              <Dropzone.Reject>
                <IconX size={50} color="red" />
              </Dropzone.Reject>
              <Dropzone.Idle>
                <IconUpload size={50} color="gray" />
              </Dropzone.Idle>

              <div>
                <Text size="lg" inline>
                  Drag file JSON ke sini atau klik untuk upload
                </Text>
                <Text size="sm" c="dimmed" inline mt={7}>
                  Maksimal ukuran file 5MB
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
                Mengimport data... {progress}%
              </Text>
              <Progress value={progress} animated />
            </div>
          )}

          {/* Results */}
          {importResult && (
            <Stack gap="sm">
              <Alert
                icon={importResult.failed === 0 ? <IconCheck size={16} /> : <IconAlertCircle size={16} />}
                color={importResult.failed === 0 ? 'green' : 'orange'}
                title="Hasil Import"
              >
                <Text size="sm">
                  Berhasil import: {importResult.success} pasal
                </Text>
                {importResult.failed > 0 && (
                  <Text size="sm">
                    Gagal import: {importResult.failed} pasal
                  </Text>
                )}
              </Alert>

              {importResult.errors.length > 0 && (
                <Accordion>
                  <Accordion.Item value="errors">
                    <Accordion.Control>
                      Lihat Error ({importResult.errors.length})
                    </Accordion.Control>
                    <Accordion.Panel>
                      <ScrollArea h={200}>
                        <Stack gap="xs">
                          {importResult.errors.map((err, idx) => (
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

      {/* JSON Format Reference */}
      <Card shadow="sm" padding="lg" radius="md" withBorder>
        <Title order={4} mb="md">
          Format JSON
        </Title>
        <Code block>
          {`[
  {
    "nomor": "340",
    "judul": "Pembunuhan Berencana",
    "isi": "Barang siapa dengan sengaja...",
    "penjelasan": "Penjelasan pasal...",
    "keywords": ["pembunuhan", "berencana", "pidana mati"]
  },
  {
    "nomor": "341",
    "isi": "Isi pasal tanpa judul...",
    "keywords": []
  }
]`}
        </Code>
        <Text size="sm" c="dimmed" mt="md">
          Field wajib: <Code>nomor</Code>, <Code>isi</Code>
          <br />
          Field opsional: <Code>judul</Code>, <Code>penjelasan</Code>, <Code>keywords</Code>
        </Text>
      </Card>
    </Stack>
  )
}
