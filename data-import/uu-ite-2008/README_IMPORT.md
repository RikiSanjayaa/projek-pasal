# Import UU-ITE (Undang-Undang Nomor 11 Tahun 2008 tentang Informasi dan Transaksi Elektronik)

File ini dibuat oleh `import-tools/prepare_import.py uu-ite-2008`. Jangan edit manual; perbaiki konfigurasi di
`import-tools/laws/` atau mesinnya di `import-tools/datahukum_pipeline.py`, lalu jalankan ulang.

## Isi

- `01_uu_ite_2008_konsolidasi_ready.xlsx`
  - sheet `import`: 63 pasal (Pasal 1 sampai 54 ditambah Pasal 13A, 16A, 16B, 18A, 27A, 27B, 40A, 45A, 45B).
  - sheet `review`: hasil pemeriksaan tiap pasal dengan PDF resmi.
- Teks sudah dikonsolidasi dengan 3 peraturan perubahan (tabel di bawah):
  - isi pasal diubah (16): 1, 5, 13, 17, 26, 27, 28, 29, 31, 40, 43, 45, 48, 49, 50, 51
  - hanya penjelasan diubah (1): 15
  - pasal sisipan (9): 13A, 16A, 16B, 18A, 27A, 27B, 40A, 45A, 45B
  - pasal dihapus/dicabut, isinya "Dicabut." (4): 30, 36, 46, 47
- Sheet `riwayat` berisi 63 versi: semua rumusan tiap pasal yang pernah berubah, dari UU 11/2008 sampai rumusan yang berlaku, masing-masing dengan sumber dan link naskah resminya (kalau ada). Import menyimpannya sebagai riwayat pasal.
- `judul` diisi judul paragraf/bagian/bab tempat pasal berada (tidak ada judul per pasal).
- `penjelasan` diisi penjelasan resmi.
- Pasal 5, 44, 27A, 45, 28, 45A diberi catatan Putusan MK di kolom penjelasan.
- 2 pasal diberi catatan berawalan "Catatan CariPasal:" di kolom penjelasan: status
  berlaku menurut undang-undang yang lebih baru (bukan bagian naskah). Aturannya ada di
  `catatan_rules` konfigurasi.
- `keywords` (topik): judul bab dan bagian tempat pasal berada. Tidak perlu diisi manual.
- `linkN_*` (pasal terkait, 41 link): rujukan ke pasal lain di UU-ITE yang disebut di isi
  pasal, misalnya "sebagaimana dimaksud dalam Pasal 54". Rujukan yang diikuti nama undang-undang lain
  dilewati, begitu juga Bab Ketentuan Penutup dan Ketentuan Peralihan (isinya memetakan pasal UU lain).
  Maksimal 20 per pasal.

### Peraturan perubahan

| Peraturan | Tentang | Diubah | Disisipkan | Dicabut/dihapus |
|---|---|---|---|---|
| UU 19/2016 | Perubahan atas Undang-Undang Nomor 11 Tahun 2008 tentang Informasi dan Transaksi Elektronik | 6 | 2 | 0 |
| UU 1/2024 | Perubahan Kedua atas Undang-Undang Nomor 11 Tahun 2008 tentang Informasi dan Transaksi Elektronik | 13 | 7 | 0 |
| UU 1/2026 | Penyesuaian Pidana | 10 | 0 | 4 |

## Sumber

1. Teks terstruktur: https://www.datahukum.com/peraturan/UU_11_Tahun_2008.html (pihak ketiga, bukan sumber resmi)
2. Pembanding resmi: https://peraturan.bpk.go.id/Details/37589/uu-no-11-tahun-2008 (PDF salinan, hasil scan/OCR)
3. Rumusan perubahan UU 19/2016: `uu-nomor-19-tahun-2016.pdf`
4. Rumusan perubahan UU 1/2024: `uu-nomor-1-tahun-2024.pdf`

Kesalahan sumber HTML yang diperbaiki otomatis: butir ayat/huruf yang hilang, label penjelasan yang
menempel ke paragraf lain, kalimat yang terpotong jadi dua paragraf, dan judul bagian yang tergeser satu
pasal (dicek ke PDF). Typo per pasal ada di `text_fixes` (0 perbaikan, tiap entri dicek ke PDF).
Typo dicari dari kata yang tidak dikenal kamus dan tidak ada di PDF. Typo yang kebetulan membentuk kata
lain yang sah tidak bisa dipastikan otomatis, jadi verifikasi admin terhadap PDF resmi tetap diperlukan.

`cakupan_*_pdf` = porsi huruf pada teks kita yang ditemukan di PDF resmi (rumusan asli dicek ke PDF
BPK, rumusan perubahan ke PDF UU 19/2016, UU 1/2024). Nilai di bawah 90% atau butir ayat/huruf yang kosong ditandai
`perlu_review`. PDF resmi adalah hasil scan, jadi skor rendah biasanya berasal dari OCR PDF (kata hilang
di ujung baris). Pasal berskor rendah yang sudah dicek manual tercatat di `manual_review` dan kolom
`catatan`.

## Cara import

1. Admin dashboard → menu `Undang-Undang`. Pastikan ada UU kode `UU-ITE`:
   - Nama: `Undang-Undang Informasi dan Transaksi Elektronik`
   - Nama lengkap: `Undang-Undang Nomor 11 Tahun 2008 tentang Informasi dan Transaksi Elektronik`
   - Tahun: `2008`
   - Link naskah resmi: `https://peraturan.bpk.go.id/Details/37589/uu-no-11-tahun-2008`
   - Sumber teks: `https://www.datahukum.com/peraturan/UU_11_Tahun_2008.html`
2. Menu `Import Data` → mode XLSX → pilih UU `UU-ITE` → upload file xlsx.
3. Import memakai `updateOrCreate` per (UU, nomor): pasal yang sudah ada akan ditimpa,
   pasal lain di UU yang sama tidak dihapus.
4. Nomor disimpan tanpa awalan "Pasal" (contoh `1`, `13A`). Data lama dengan nomor `Pasal 1`
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
