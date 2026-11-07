# Import KUHP (UU Nomor 1 Tahun 2023)

File ini dibuat oleh `import-tools/prepare_kuhp_2023_import.py`. Jangan edit manual; perbaiki
skripnya lalu jalankan ulang.

## Isi

- `01_kuhp_2023_konsolidasi_ready.xlsx`
  - sheet `import`: 625 pasal (Pasal 1 sampai 624 ditambah Pasal 599A).
  - sheet `review`: hasil pembandingan tiap pasal dengan PDF resmi JDIH BPK.
- Teks sudah dikonsolidasi dengan UU 1/2026 (Penyesuaian Pidana):
  - isi pasal diubah (48): 3, 8, 37, 49, 66, 69, 76, 77, 82, 83, 84, 90, 91, 95, 99, 100, 101, 103, 120, 121, 132, 136, 196, 243, 251, 263, 264, 281, 295, 296, 297, 299, 300, 332, 375, 398, 407, 455, 457, 473, 521, 597, 605, 606, 609, 610, 613, 622
  - hanya penjelasan diubah (4): 48, 433, 458, 466
  - pasal sisipan (1): 599A
- `judul` diisi judul paragraf/bagian/bab tempat pasal berada (KUHP tidak punya judul per pasal).
- `penjelasan` diisi penjelasan resmi. Pasal 220 dan 237 diberi catatan Putusan MK.
- `keywords` (topik): judul bab dan bagian tempat pasal berada, contoh
  `tindak pidana terhadap tubuh, penganiayaan`. Tidak perlu diisi manual.
- `linkN_*` (pasal terkait): rujukan ke pasal KUHP lain yang disebut di isi pasal, misalnya
  "sebagaimana dimaksud dalam Pasal 54". Rujukan yang diikuti nama undang-undang lain dilewati,
  begitu juga Bab Ketentuan Peralihan dan Ketentuan Penutup (isinya memetakan pasal UU lain).
  Maksimal 20 per pasal.

## Sumber

1. Teks terstruktur: https://www.datahukum.com/peraturan/UU_1_Tahun_2023.html (pihak ketiga, bukan sumber resmi)
2. Pembanding resmi: https://peraturan.bpk.go.id/Details/234935/uu-no-1-tahun-2023 (PDF salinan, hasil scan/OCR)
3. Rumusan perubahan: `uu-nomor-1-tahun-2026.pdf` (Penyesuaian Pidana)

Kesalahan sumber HTML yang diperbaiki skrip: butir ayat/huruf yang hilang, label penjelasan yang
menempel ke paragraf lain, judul bagian yang tergeser satu pasal (dicek ke PDF), dan typo OCR pada
rumusan UU 1/2026 (`TEXT_FIXES`, tiap entri dicek ke PDF).

`cakupan_*_pdf` = porsi huruf pada teks kita yang ditemukan di PDF resmi (rumusan asli dicek ke PDF
BPK, rumusan perubahan ke PDF UU 1/2026). Nilai di bawah 90% atau butir
ayat/huruf yang kosong ditandai `perlu_review`. PDF resmi adalah hasil scan, jadi skor rendah biasanya
berasal dari OCR PDF (kata hilang di ujung baris). Pasal dengan skor rendah yang sudah dicek manual
tercatat di `MANUAL_REVIEW` dan kolom `catatan`.

## Cara import

1. Admin dashboard → menu `Undang-Undang`. Pastikan ada UU kode `KUHP`:
   - Nama: `Kitab Undang-Undang Hukum Pidana`
   - Nama lengkap: `Undang-Undang Nomor 1 Tahun 2023 tentang Kitab Undang-Undang Hukum Pidana`
   - Tahun: `2023`
2. Menu `Import Data` → mode XLSX → pilih UU `KUHP` → upload file xlsx.
3. Import memakai `updateOrCreate` per (UU, nomor): pasal yang sudah ada akan ditimpa,
   pasal lain di UU yang sama tidak dihapus.
4. Nomor disimpan tanpa awalan "Pasal" (contoh `1`, `599A`). Data lama dengan nomor `Pasal 1`
   tidak akan tertimpa dan jadi dobel, jadi hapus dulu pasal KUHP lama sebelum import.

Catatan tampilan: normalizer import menggabungkan anak kalimat penutup setelah daftar huruf
(misalnya "..., pidananya dapat ditambah 1/3") ke butir huruf terakhir. Isi teks tetap lengkap.

## Perlu dicek manual (0 pasal)

| Pasal | Catatan |
|---|---|
| - | - |
