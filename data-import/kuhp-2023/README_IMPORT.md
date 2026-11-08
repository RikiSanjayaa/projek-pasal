# Import KUHP (Undang-Undang Nomor 1 Tahun 2023 tentang Kitab Undang-Undang Hukum Pidana)

File ini dibuat oleh `import-tools/prepare_import.py kuhp-2023`. Jangan edit manual; perbaiki konfigurasi di
`import-tools/laws/` atau mesinnya di `import-tools/datahukum_pipeline.py`, lalu jalankan ulang.

## Isi

- `01_kuhp_2023_konsolidasi_ready.xlsx`
  - sheet `import`: 625 pasal (Pasal 1 sampai 624 ditambah Pasal 599A).
  - sheet `review`: hasil pembandingan tiap pasal dengan PDF resmi.
- Teks sudah dikonsolidasi dengan UU 1/2026 (Penyesuaian Pidana):
  - isi pasal diubah (48): 3, 8, 37, 49, 66, 69, 76, 77, 82, 83, 84, 90, 91, 95, 99, 100, 101, 103, 120, 121, 132, 136, 196, 243, 251, 263, 264, 281, 295, 296, 297, 299, 300, 332, 375, 398, 407, 455, 457, 473, 521, 597, 605, 606, 609, 610, 613, 622
  - hanya penjelasan diubah (4): 48, 433, 458, 466
  - pasal sisipan (1): 599A
  - pasal dihapus, isinya "Dihapus." (2): 615, 616
- Sheet `riwayat` berisi 109 versi untuk pasal di atas: rumusan UU 1/2023 lalu rumusan UU 1/2026, masing-masing dengan link naskah resminya. Import menyimpannya sebagai riwayat pasal (tampil di admin).
- `judul` diisi judul paragraf/bagian/bab tempat pasal berada (tidak ada judul per pasal).
- `penjelasan` diisi penjelasan resmi.
- Pasal 220, 237 diberi catatan Putusan MK di kolom penjelasan.
- `keywords` (topik): judul bab dan bagian tempat pasal berada. Tidak perlu diisi manual.
- `linkN_*` (pasal terkait, 348 link): rujukan ke pasal lain di KUHP yang disebut di isi
  pasal, misalnya "sebagaimana dimaksud dalam Pasal 54". Rujukan yang diikuti nama undang-undang lain
  dilewati, begitu juga Bab Ketentuan Penutup dan Ketentuan Peralihan (isinya memetakan pasal UU lain).
  Maksimal 20 per pasal.

## Sumber

1. Teks terstruktur: https://www.datahukum.com/peraturan/UU_1_Tahun_2023.html (pihak ketiga, bukan sumber resmi)
2. Pembanding resmi: https://peraturan.bpk.go.id/Details/234935/uu-no-1-tahun-2023 (PDF salinan, hasil scan/OCR)
3. Rumusan perubahan UU 1/2026 (Penyesuaian Pidana): `uu-nomor-1-tahun-2026.pdf`

Kesalahan sumber HTML yang diperbaiki otomatis: butir ayat/huruf yang hilang, label penjelasan yang
menempel ke paragraf lain, kalimat yang terpotong jadi dua paragraf, dan judul bagian yang tergeser satu
pasal (dicek ke PDF). Typo per pasal ada di `text_fixes` (31 perbaikan, tiap entri dicek ke PDF).
Typo dicari dari kata yang tidak dikenal kamus dan tidak ada di PDF. Typo yang kebetulan membentuk kata
lain yang sah tidak bisa dipastikan otomatis, jadi verifikasi admin terhadap PDF resmi tetap diperlukan.

`cakupan_*_pdf` = porsi huruf pada teks kita yang ditemukan di PDF resmi (rumusan asli dicek ke PDF
BPK, rumusan perubahan ke PDF UU 1/2026). Nilai di bawah 90% atau butir ayat/huruf yang kosong ditandai
`perlu_review`. PDF resmi adalah hasil scan, jadi skor rendah biasanya berasal dari OCR PDF (kata hilang
di ujung baris). Pasal berskor rendah yang sudah dicek manual tercatat di `manual_review` dan kolom
`catatan`.

## Cara import

1. Admin dashboard → menu `Undang-Undang`. Pastikan ada UU kode `KUHP`:
   - Nama: `Kitab Undang-Undang Hukum Pidana`
   - Nama lengkap: `Undang-Undang Nomor 1 Tahun 2023 tentang Kitab Undang-Undang Hukum Pidana`
   - Tahun: `2023`
   - Link naskah resmi: `https://peraturan.bpk.go.id/Details/234935/uu-no-1-tahun-2023`
   - Sumber teks: `https://www.datahukum.com/peraturan/UU_1_Tahun_2023.html`
2. Menu `Import Data` → mode XLSX → pilih UU `KUHP` → upload file xlsx.
3. Import memakai `updateOrCreate` per (UU, nomor): pasal yang sudah ada akan ditimpa,
   pasal lain di UU yang sama tidak dihapus.
4. Nomor disimpan tanpa awalan "Pasal" (contoh `1`, `599A`). Data lama dengan nomor `Pasal 1`
   tidak akan tertimpa dan jadi dobel, jadi hapus dulu pasal lama sebelum import.
5. Pasal baru atau yang teksnya berubah masuk menu `Verifikasi` dengan status "Perlu verifikasi".
   Admin mencocokkan tiap pasal dengan naskah resmi lalu menekan "Verifikasi". Sebelum itu pasal
   tetap tampil di mobile dengan label "Belum diverifikasi admin".

Catatan tampilan: normalizer import menggabungkan anak kalimat penutup setelah daftar huruf
(misalnya "..., pidananya dapat ditambah 1/3") ke butir huruf terakhir. Isi teks tetap lengkap.

## Perlu dicek manual (0 pasal)

| Pasal | Catatan |
|---|---|
| - | - |
