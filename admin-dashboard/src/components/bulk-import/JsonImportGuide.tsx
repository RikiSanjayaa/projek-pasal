import {
  Card,
  Title,
  Text,
  Stack,
  Group,
  Table,
  Badge,
  Code,
  ScrollArea,
  List,
  ThemeIcon,
  Alert,
} from '@mantine/core'
import {
  IconFileCode,
  IconCircleCheck,
  IconInfoCircle,
} from '@tabler/icons-react'

export function JsonImportGuide() {
  return (
    <Card shadow="sm" padding="lg" radius="md" withBorder>
      <Title order={4} mb="md">
        <Group gap="xs">
          <IconFileCode size={20} />
          Panduan Import JSON
        </Group>
      </Title>

      <Stack gap="md">
        {/* Step by step guide */}
        <div>
          <Text fw={600} mb="xs">Langkah-langkah Import:</Text>
          <List spacing="xs" size="sm">
            <List.Item icon={
              <ThemeIcon color="blue" size={20} radius="xl">
                <Text size="xs" fw={700}>1</Text>
              </ThemeIcon>
            }>
              <Text><strong>Download template</strong> - Klik tombol "Download Template JSON" di atas</Text>
            </List.Item>
            <List.Item icon={
              <ThemeIcon color="blue" size={20} radius="xl">
                <Text size="xs" fw={700}>2</Text>
              </ThemeIcon>
            }>
              <Text><strong>Buka file</strong> - Buka template menggunakan text editor (Notepad, VS Code, dll)</Text>
            </List.Item>
            <List.Item icon={
              <ThemeIcon color="blue" size={20} radius="xl">
                <Text size="xs" fw={700}>3</Text>
              </ThemeIcon>
            }>
              <Text><strong>Edit data</strong> - Ubah contoh data dengan data pasal Anda. Pastikan format JSON tetap valid</Text>
            </List.Item>
            <List.Item icon={
              <ThemeIcon color="blue" size={20} radius="xl">
                <Text size="xs" fw={700}>4</Text>
              </ThemeIcon>
            }>
              <Text><strong>Simpan file</strong> - Simpan dengan ekstensi .json</Text>
            </List.Item>
            <List.Item icon={
              <ThemeIcon color="blue" size={20} radius="xl">
                <Text size="xs" fw={700}>5</Text>
              </ThemeIcon>
            }>
              <Text><strong>Upload file</strong> - Pilih undang-undang tujuan, lalu drag & drop file ke area upload</Text>
            </List.Item>
          </List>
        </div>

        {/* JSON Structure */}
        <div>
          <Text fw={600} mb="xs">Struktur JSON:</Text>
          <Code block>
            {`[
  {
    "nomor": "340",
    "judul": "Pembunuhan Berencana",
    "isi": "Barang siapa dengan sengaja...",
    "penjelasan": "Penjelasan pasal...",
    "keywords": ["pembunuhan", "berencana"],
    "links": [
      {
        "targetUU": "KUHAP",
        "targetNomor": "21",
        "keterangan": "Prosedur penyidikan"
      }
    ]
  }
]`}
          </Code>
        </div>

        {/* Field explanation */}
        <div>
          <Text fw={600} mb="xs">Penjelasan Field:</Text>
          <ScrollArea>
            <Table striped withTableBorder withColumnBorders>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Field</Table.Th>
                  <Table.Th>Tipe</Table.Th>
                  <Table.Th>Wajib?</Table.Th>
                  <Table.Th>Keterangan</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                <Table.Tr>
                  <Table.Td><Code>nomor</Code></Table.Td>
                  <Table.Td>string</Table.Td>
                  <Table.Td><Badge color="red" size="xs">Wajib</Badge></Table.Td>
                  <Table.Td>Nomor pasal (contoh: "340", "27 ayat (3)")</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>judul</Code></Table.Td>
                  <Table.Td>string</Table.Td>
                  <Table.Td><Badge color="gray" size="xs">Opsional</Badge></Table.Td>
                  <Table.Td>Judul pasal jika ada</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>isi</Code></Table.Td>
                  <Table.Td>string</Table.Td>
                  <Table.Td><Badge color="red" size="xs">Wajib</Badge></Table.Td>
                  <Table.Td>Isi lengkap pasal</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>penjelasan</Code></Table.Td>
                  <Table.Td>string</Table.Td>
                  <Table.Td><Badge color="gray" size="xs">Opsional</Badge></Table.Td>
                  <Table.Td>Penjelasan atau tafsir pasal</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>keywords</Code></Table.Td>
                  <Table.Td>array</Table.Td>
                  <Table.Td><Badge color="gray" size="xs">Opsional</Badge></Table.Td>
                  <Table.Td>Array kata kunci: ["kata1", "kata2"]</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>links</Code></Table.Td>
                  <Table.Td>array</Table.Td>
                  <Table.Td><Badge color="gray" size="xs">Opsional</Badge></Table.Td>
                  <Table.Td>Array link ke pasal lain</Table.Td>
                </Table.Tr>
              </Table.Tbody>
            </Table>
          </ScrollArea>
        </div>

        {/* Link structure explanation */}
        <div>
          <Text fw={600} mb="xs">Struktur Link:</Text>
          <Text size="sm" c="dimmed" mb="sm">
            Setiap pasal dapat memiliki banyak link ke pasal lain. Field links bersifat opsional.
          </Text>
          <ScrollArea>
            <Table striped withTableBorder withColumnBorders>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Field</Table.Th>
                  <Table.Th>Wajib?</Table.Th>
                  <Table.Th>Keterangan</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                <Table.Tr>
                  <Table.Td><Code>targetUU</Code></Table.Td>
                  <Table.Td><Badge color="red" size="xs">Wajib</Badge></Table.Td>
                  <Table.Td>Kode undang-undang tujuan (contoh: "KUHAP", "KUHP")</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>targetNomor</Code></Table.Td>
                  <Table.Td><Badge color="red" size="xs">Wajib</Badge></Table.Td>
                  <Table.Td>Nomor pasal tujuan (contoh: "21", "340")</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>keterangan</Code></Table.Td>
                  <Table.Td><Badge color="gray" size="xs">Opsional</Badge></Table.Td>
                  <Table.Td>Keterangan hubungan antar pasal</Table.Td>
                </Table.Tr>
              </Table.Tbody>
            </Table>
          </ScrollArea>
        </div>

        {/* Tips */}
        <Alert icon={<IconInfoCircle size={16} />} color="yellow" title="Tips Penting">
          <List size="sm" spacing="xs">
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              File harus berupa array JSON yang valid (diawali <Code>[</Code> dan diakhiri <Code>]</Code>)
            </List.Item>
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Gunakan tanda kutip ganda (") untuk semua string, bukan kutip tunggal (')
            </List.Item>
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Pisahkan setiap objek pasal dengan koma, kecuali objek terakhir
            </List.Item>
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Keywords harus berupa array: <Code>["kata1", "kata2"]</Code>, bukan string biasa
            </List.Item>
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Pasal tujuan link harus sudah ada di database sebelum import
            </List.Item>
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Gunakan validator JSON online jika tidak yakin format sudah benar
            </List.Item>
          </List>
        </Alert>
      </Stack>
    </Card>
  )
}
