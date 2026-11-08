# Import KUHAP (Undang-Undang Nomor 20 Tahun 2025 tentang Kitab Undang-Undang Hukum Acara Pidana)

File ini dibuat oleh `import-tools/prepare_import.py kuhap-2025`. Jangan edit manual; perbaiki konfigurasi di
`import-tools/laws/` atau mesinnya di `import-tools/datahukum_pipeline.py`, lalu jalankan ulang.

## Isi

- `01_kuhap_2025_ready.xlsx`
  - sheet `import`: 369 pasal (Pasal 1 sampai 369).
  - sheet `review`: hasil pemeriksaan tiap pasal dengan PDF resmi.
- `judul` diisi judul paragraf/bagian/bab tempat pasal berada (tidak ada judul per pasal).
- `penjelasan` diisi penjelasan resmi.
- `bab`: bab tempat pasal berada, dengan buku di depannya kalau ada (mis. "Buku Kedua · Bab XXI · Tentang Hipotek"). Tidak perlu diisi manual.
- `linkN_*` (pasal terkait, 179 link): rujukan ke pasal lain di KUHAP yang disebut di isi
  pasal, misalnya "sebagaimana dimaksud dalam Pasal 54". Rujukan yang diikuti nama undang-undang lain
  dilewati, begitu juga Bab Ketentuan Penutup dan Ketentuan Peralihan (isinya memetakan pasal UU lain).
  Maksimal 20 per pasal.

## Sumber

1. Teks terstruktur: https://www.datahukum.com/peraturan/UU_20_Tahun_2025.html (pihak ketiga, bukan sumber resmi)
2. Pembanding resmi: https://peraturan.bpk.go.id/Details/337302/uu-no-20-tahun-2025 (PDF salinan, hasil scan/OCR)

Kesalahan sumber HTML yang diperbaiki otomatis: butir ayat/huruf yang hilang, label penjelasan yang
menempel ke paragraf lain, kalimat yang terpotong jadi dua paragraf, dan judul bagian yang tergeser satu
pasal (dicek ke PDF). Typo per pasal ada di `text_fixes` (64 perbaikan, tiap entri dicek ke PDF).
Typo dicari dari kata yang tidak dikenal kamus dan tidak ada di PDF. Typo yang kebetulan membentuk kata
lain yang sah tidak bisa dipastikan otomatis, jadi verifikasi admin terhadap PDF resmi tetap diperlukan.

`cakupan_*_pdf` = porsi huruf pada teks kita yang ditemukan di PDF resmi (rumusan asli dicek ke PDF
BPK). Nilai di bawah 90% atau butir ayat/huruf yang kosong ditandai
`perlu_review`. PDF resmi adalah hasil scan, jadi skor rendah biasanya berasal dari OCR PDF (kata hilang
di ujung baris). Pasal berskor rendah yang sudah dicek manual tercatat di `manual_review` dan kolom
`catatan`.

## Cara import

1. Admin dashboard → menu `Undang-Undang`. Pastikan ada UU kode `KUHAP`:
   - Nama: `Kitab Undang-Undang Hukum Acara Pidana`
   - Nama lengkap: `Undang-Undang Nomor 20 Tahun 2025 tentang Kitab Undang-Undang Hukum Acara Pidana`
   - Tahun: `2025`
   - Link naskah resmi: `https://peraturan.bpk.go.id/Details/337302/uu-no-20-tahun-2025`
   - Sumber teks: `https://www.datahukum.com/peraturan/UU_20_Tahun_2025.html`
2. Menu `Import Data` → mode XLSX → pilih UU `KUHAP` → upload file xlsx.
3. Import memakai `updateOrCreate` per (UU, nomor): pasal yang sudah ada akan ditimpa,
   pasal lain di UU yang sama tidak dihapus.
4. Nomor disimpan tanpa awalan "Pasal" (contoh `1`, `369`). Data lama dengan nomor `Pasal 1`
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
