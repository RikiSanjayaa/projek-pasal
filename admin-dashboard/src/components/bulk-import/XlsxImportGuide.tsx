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
  IconFileSpreadsheet,
  IconCircleCheck,
  IconInfoCircle,
} from '@tabler/icons-react'

export function XlsxImportGuide() {
  return (
    <Card shadow="sm" padding="lg" radius="md" withBorder>
      <Title order={4} mb="md">
        <Group gap="xs">
          <IconFileSpreadsheet size={20} />
          Panduan Import Excel (XLSX)
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
              <Text><strong>Download template</strong> - Klik tombol "Download Template Excel" di atas</Text>
            </List.Item>
            <List.Item icon={
              <ThemeIcon color="blue" size={20} radius="xl">
                <Text size="xs" fw={700}>2</Text>
              </ThemeIcon>
            }>
              <Text><strong>Buka file</strong> - Buka template menggunakan Microsoft Excel atau Google Sheets</Text>
            </List.Item>
            <List.Item icon={
              <ThemeIcon color="blue" size={20} radius="xl">
                <Text size="xs" fw={700}>3</Text>
              </ThemeIcon>
            }>
              <Text><strong>Isi data</strong> - Hapus contoh data, lalu isi dengan data pasal Anda. Satu baris = satu pasal</Text>
            </List.Item>
            <List.Item icon={
              <ThemeIcon color="blue" size={20} radius="xl">
                <Text size="xs" fw={700}>4</Text>
              </ThemeIcon>
            }>
              <Text><strong>Simpan sebagai .xlsx</strong> - Pastikan menyimpan dengan format Excel (.xlsx)</Text>
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

        {/* Column explanation */}
        <div>
          <Text fw={600} mb="xs">Penjelasan Kolom:</Text>
          <ScrollArea>
            <Table striped withTableBorder withColumnBorders>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Kolom</Table.Th>
                  <Table.Th>Wajib?</Table.Th>
                  <Table.Th>Keterangan</Table.Th>
                  <Table.Th>Contoh</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                <Table.Tr>
                  <Table.Td><Code>nomor</Code></Table.Td>
                  <Table.Td><Badge color="red" size="xs">Wajib</Badge></Table.Td>
                  <Table.Td>Nomor pasal</Table.Td>
                  <Table.Td>340, 27 ayat (3)</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>judul</Code></Table.Td>
                  <Table.Td><Badge color="gray" size="xs">Opsional</Badge></Table.Td>
                  <Table.Td>Judul pasal (jika ada)</Table.Td>
                  <Table.Td>Pembunuhan Berencana</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>isi</Code></Table.Td>
                  <Table.Td><Badge color="red" size="xs">Wajib</Badge></Table.Td>
                  <Table.Td>Isi lengkap pasal</Table.Td>
                  <Table.Td>Barang siapa dengan sengaja...</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>penjelasan</Code></Table.Td>
                  <Table.Td><Badge color="gray" size="xs">Opsional</Badge></Table.Td>
                  <Table.Td>Penjelasan atau tafsir pasal</Table.Td>
                  <Table.Td>Penjelasan dari UU...</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>keywords</Code></Table.Td>
                  <Table.Td><Badge color="gray" size="xs">Opsional</Badge></Table.Td>
                  <Table.Td>Kata kunci, pisahkan dengan koma</Table.Td>
                  <Table.Td>pembunuhan, berencana, pidana</Table.Td>
                </Table.Tr>
              </Table.Tbody>
            </Table>
          </ScrollArea>
        </div>

        {/* Link columns explanation */}
        <div>
          <Text fw={600} mb="xs">Kolom Link (Menghubungkan ke Pasal Lain):</Text>
          <Text size="sm" c="dimmed" mb="sm">
            Setiap pasal dapat memiliki hingga 5 link ke pasal lain. Kolom link bersifat opsional.
          </Text>
          <ScrollArea>
            <Table striped withTableBorder withColumnBorders>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Kolom</Table.Th>
                  <Table.Th>Keterangan</Table.Th>
                  <Table.Th>Contoh</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                <Table.Tr>
                  <Table.Td><Code>link1_targetUU</Code></Table.Td>
                  <Table.Td>Kode undang-undang tujuan link pertama</Table.Td>
                  <Table.Td>KUHAP, KUHP, UU-ITE</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>link1_targetNomor</Code></Table.Td>
                  <Table.Td>Nomor pasal tujuan link pertama</Table.Td>
                  <Table.Td>21, 340, 27</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>link1_keterangan</Code></Table.Td>
                  <Table.Td>Keterangan link (opsional)</Table.Td>
                  <Table.Td>Lihat prosedur penyidikan</Table.Td>
                </Table.Tr>
                <Table.Tr>
                  <Table.Td><Code>link2_targetUU</Code>, dst...</Table.Td>
                  <Table.Td colSpan={2}>Sama seperti link1, untuk link ke-2 sampai ke-5</Table.Td>
                </Table.Tr>
              </Table.Tbody>
            </Table>
          </ScrollArea>
        </div>

        {/* Tips */}
        <Alert icon={<IconInfoCircle size={16} />} color="yellow" title="Tips Penting">
          <List size="sm" spacing="xs">
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Jangan mengubah nama kolom di baris pertama (header)
            </List.Item>
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Pastikan tidak ada baris kosong di antara data
            </List.Item>
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Untuk keywords, gunakan koma sebagai pemisah: <Code>keyword1, keyword2, keyword3</Code>
            </List.Item>
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Link bersifat opsional - kosongkan jika pasal tidak perlu dihubungkan ke pasal lain
            </List.Item>
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Jika mengisi link, <Code>targetUU</Code> dan <Code>targetNomor</Code> harus diisi keduanya
            </List.Item>
            <List.Item icon={<ThemeIcon color="green" size={16} radius="xl"><IconCircleCheck size={12} /></ThemeIcon>}>
              Pasal tujuan link harus sudah ada di database sebelum import
            </List.Item>
          </List>
        </Alert>
      </Stack>
    </Card>
  )
}
