# import-tools

Pipeline yang mengambil teks undang-undang dari datahukum.com, membandingkannya dengan PDF resmi
BPK (kalau ada), lalu menghasilkan file Bulk Import (xlsx) atau JSON untuk impor dari dashboard admin.
Registrasi sumber disimpan di database bersama UU melalui form Tambah/Edit UU pada dashboard.
Konfigurasi empat sumber lama dimigrasikan dari `backend-laravel/database/data/import_sources.json`;
file itu bukan katalog runtime kedua. Backend mengirim snapshot JSON tiap run ke pipeline.

```bash
python -m venv .venv && .venv/bin/pip install -r import-tools/requirements.txt
.venv/bin/python import-tools/prepare_import.py --config source.json # ekspor xlsx
```

Sumber (HTML datahukum, PDF BPK, PDF UU perubahan) disimpan di `import-tools/.cache/`, atau di
folder `IMPORT_CACHE_DIR` kalau variabel itu diisi. File yang belum ada diunduh otomatis.

## Mode JSON (dipakai backend Laravel)

Dashboard admin menjalankan mode ini lewat job antrean (`php artisan queue:work`, antrean
`imports`). Mode ini tidak menulis xlsx maupun README.

```bash
python prepare_import.py --config source.json --json out.json
python prepare_import.py --config source.json --json out.json --refresh
python prepare_import.py --config source.json --json out.json --previous-count 625
```

- `--refresh` mengunduh ulang HTML. Unduhan baru menggantikan cache hanya kalau lolos parse, jadi
  HTML rusak tidak meracuni cache. PDF tidak diunduh ulang.
- `--previous-count N` (opsional) menggagalkan run kalau jumlah pasal turun lebih dari 2% dari `N`.
- Berhasil: exit 0, `out.json` berisi `slug, kode, source_url, fetched_at, html_sha256,
  unknown_versions, metrics.pasal_count, warnings, pasal[]`. Setiap pasal membawa `judul, isi,
  penjelasan, bab, links[], riwayat[], status_teks, review`. Teksnya persis sama dengan
  sheet `import` dan `riwayat` di xlsx.
- Gagal struktural (div `batangtubuh`/`pasal` hilang, HTML tidak terbaca, unduhan gagal, jumlah
  pasal anjlok): exit 2 dan `out.json` berisi `{"error": "<pesan Indonesia>"}`.
- `unknown_versions`: class versi di HTML yang bukan versi asli maupun versi perubahan yang dikenal.
  Kalau tidak kosong, ada peraturan perubahan baru yang belum dikonfigurasi.
- `warnings`: di mode xlsx, entri `text_fixes` yang tidak cocok lagi menghentikan skrip. Di mode JSON
  perbaikan itu dilewati dan dicatat sebagai peringatan `{nomor, message}`.

## Perubahan dan riwayat

Setiap pasal disusun sebagai daftar versi, dari rumusan asli sampai rumusan yang berlaku. Versi
yang teksnya sama dengan versi sebelumnya dilewati; pasal yang dicabut lalu ditambahkan lagi tercatat
sebagai `dihapus` lalu `disisipkan`. Sheet `riwayat` berisi semua versi itu.

- `LawConfig.amendments`: daftar perubahan yang ditulis tangan (KUHP: UU 1/2026 beserta PDF resminya
  di `Amendment.pdf`/`pdf_url`, diunduh sekali ke cache).
- `LawConfig.amendments_from_html=True`: daftar perubahan dibaca dari bagian "Riwayat" HTML
  datahukum, termasuk daftar pasal yang dicabut. Dipakai KUHPerdata (47 Staatsblad dan UU 23/2006) dan
  UU ITE (UU 19/2016, UU 1/2024, UU 1/2026). Metadata yang salah di sumber, juga `pdf`/`pdf_url`
  pembanding, diisi lewat `amendment_overrides`. Tanggal yang tahunnya meleset lebih dari lima tahun
  dari nomor peraturan diabaikan dan dicetak sebagai peringatan.
- `Amendment.derive`: rumusan suatu perubahan disusun sendiri dari versi sebelumnya, bukan dari HTML.
  Dipakai untuk UU 1/2026 di UU ITE: versi datahukum mencabut ayat yang tidak disebut dan memakai
  kembali rumusan lama, sedangkan UU 1/2026 sendiri hanya memuat daftar ayat yang dicabut dan tabel
  ancaman pidana baru. Snapshot memakai `derive_rule: "ite-2026"`, dipetakan ke fungsi yang ditinjau
  dalam `reviewed_rules.py`; konfigurasi tidak dapat memuat kode yang dieksekusi.

## Perbaikan teks

- `text_fixes`: typo pada rumusan yang berlaku (isi/penjelasan pasal).
- `version_fixes`: typo pada satu versi rumusan (per class versi). Dijalankan saat versi itu dibaca,
  jadi ikut ke riwayat dan ke versi turunan `derive`.
- `ocr_fixes`: pola regex untuk artefak OCR yang berulang di seluruh UU (contoh huruf "ı", catatan
  kaki "TAMBAHAN LEMBARAN NEGARA ...").

Semua entri berhenti dengan error kalau teks salahnya tidak ditemukan lagi, supaya daftar tidak basi.

HTML datahukum ada dua format: yang baru menautkan pasal ke judul bab/bagian lewat `data-parent-id`,
yang lama (UU ITE) menyarangkan `div.pasal` di dalam `div.bab`. Keduanya didukung.

## Tanpa PDF resmi (KUHPerdata)

KUHPerdata hanya punya naskah resmi berbahasa Belanda, jadi `bpk_pdf_url` kosong dan kolom
`cakupan_*_pdf` di sheet `review` kosong. Semua versi rumusan dipindai untuk sisa teks penerjemah
atau chatbot, kata ganti percakapan, kata Belanda yang tertinggal, dan judul pasal di dalam isi;
temuannya ditandai `perlu_review`. Perbaikan per pasal ada di `text_fixes`.

`catatan_rules` menambahkan baris berawalan "Catatan CariPasal:" di akhir penjelasan (seperti catatan
Putusan MK) per buku/bab atau per pasal, misalnya bab perkawinan yang tidak berlaku lagi sejauh telah
diatur UU 1/1974. Catatan ini bukan bagian naskah. Aturan yang tidak mengenai satu pasal pun
menghentikan skrip.

## Docker

Image backend (`backend-laravel/Dockerfile`) membawa pipeline ini di `/opt/import-tools` dan venv di
`/opt/import-venv`. Folder `import-tools/` ada di luar build context backend, jadi compose
mengirimnya lewat `additional_contexts: import-tools` dan Dockerfile memakai
`COPY --from=import-tools`. Tanpa compose:
`docker build --build-context import-tools=./import-tools backend-laravel`.

Env di image: `IMPORT_TOOLS_DIR=/opt/import-tools`, `IMPORT_PYTHON=/opt/import-venv/bin/python`,
`IMPORT_CACHE_DIR=/var/www/html/storage/app/import-cache`. Service `queue-worker` yang menjalankan
pipeline, jadi hanya worker yang memasang volume `caripasal_import_cache` untuk cache itu; service
`backend` hanya membaca hasilnya dari database.

Backend dan worker memasang volume privat `caripasal_law_documents` pada
`storage/app/private/law-documents`. PDF unggahan maksimal 20 MiB disimpan dengan nama UUID;
unduhan memerlukan autentikasi admin. Mengganti atau melepas lampiran tidak menghapus file snapshot
run lama. `IMPORT_DOCUMENTS_DIR` membatasi lokasi PDF lokal yang boleh dibaca pipeline.

## Registrasi dan batas sumber

Simpan URL sumber melalui form UU; URL PDF asli dan unggahan PDF bersifat opsional. Simpan tidak
mengambil data atau mengubah pasal. Halaman Sumber Data menampilkan registrasi meski pengambilan
dinonaktifkan. Jalankan Periksa pembaruan untuk menghasilkan draf, tinjau, pilih item, lalu Terapkan.
Sumber standar baru tidak memerlukan modul Python. Struktur tidak dikenal gagal dengan alasan,
bukan dianggap berhasil. Koreksi khusus lama tetap tersimpan di konfigurasi database.

Identitas versi asli dan perubahan dibaca dari class metadata riwayat HTML dan section isi.
`doc_class` bersifat opsional untuk override yang sudah ditinjau; nilai yang bertentangan dengan
metadata asli ditolak. Judul perubahan tidak harus berbentuk UU bernomor: label seperti
`Amandemen I` tetap disimpan, tanpa membuat nomor UU atau mengambil tahun dari class HTML.
Urutan riwayat mengikuti sumber, dengan pemeriksaan tanggal/tahun yang tersedia. Tanggal pengesahan
dan pengundangan tetap terpisah. Untuk registrasi Staatsblad, tahun registrasi tidak diganti oleh
tanggal keputusan kerajaan yang lebih awal. Metadata tanpa tanggal diberi peringatan.

Fixture UUD 1945 mempertahankan 79 node pasal dan empat amandemen. Pasal Romawi diberi lingkup
bagian, misalnya `I (ATURAN PERALIHAN)` dan `I (ATURAN TAMBAHAN)`, agar riwayat dan penerapannya tidak
bercampur. Induk DOM digunakan ketika atribut referensi induk sumber rusak. Pencabutan Bab IV tidak
mencabut Pasal 16; pencabutan Pasal IV tetap tercatat pada Aturan Peralihan. Ayat bernomor eksplisit
dalam markup daftar yang salah tersarang tetap dipertahankan.

Berhasil diparse bukan verifikasi kebenaran hukum atau kelengkapan historis sumber. Fixture tetap
memuat label `25E`, beberapa salah ketik, dan versi pasal yang tidak lengkap. Parser tidak mengubahnya
menjadi `25A`, mengarang rumusan yang hilang, atau mengisi tanggal yang tidak ada. Draf perlu ditinjau
terhadap naskah resmi sebelum diterapkan. Koreksi empat sumber lama dan aturan UU ITE tetap berlaku.

API katalog memisahkan `status` konfigurasi dari `parse_status` (`unverified`, `passed`, `failed`).
Bukti parsing hanya berlaku untuk snapshot konfigurasi/dokumen yang sama. Simpan atau edit tidak
menjalankan parser; hasil gagal tetap dapat diperiksa ulang setelah masalah diperbaiki.


Konfigurasi JSON memakai whitelist field dan tipe. HTML hanya diambil dari HTTPS datahukum.com;
PDF dari host resmi yang disetujui. Semua alamat DNS harus publik; koneksi dipatok ke alamat yang
divalidasi dan setiap redirect diperiksa ulang. Tidak ada akses ke localhost, jaringan privat,
path file bebas, atau callback dari input HTTP. Cache HTML dibedakan menurut identitas sumber/URL.

