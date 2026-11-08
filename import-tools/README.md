# import-tools

Pipeline yang mengambil teks undang-undang dari datahukum.com, membandingkannya dengan PDF resmi
BPK (kalau ada), lalu menghasilkan file Bulk Import (xlsx) atau JSON untuk impor dari dashboard admin.
UU yang terdaftar ada di `laws/` (satu file per UU): `kuhp-2023`, `kuhap-2025`, `kuhper-1847`,
`uu-ite-2008`.

```bash
python -m venv .venv && .venv/bin/pip install -r import-tools/requirements.txt
.venv/bin/python import-tools/prepare_import.py kuhp-2023      # tulis data-import/kuhp-2023/*.xlsx
.venv/bin/python import-tools/prepare_import.py all
```

Sumber (HTML datahukum, PDF BPK, PDF UU perubahan) disimpan di `import-tools/.cache/`, atau di
folder `IMPORT_CACHE_DIR` kalau variabel itu diisi. File yang belum ada diunduh otomatis.

## Mode JSON (dipakai backend Laravel)

Dashboard admin menjalankan mode ini lewat job antrean (`php artisan queue:work`, antrean
`imports`). Mode ini tidak menulis xlsx maupun README.

```bash
python prepare_import.py --list --json                       # daftar UU terdaftar, JSON ke stdout
python prepare_import.py kuhp-2023 --json out.json           # pakai HTML dari cache kalau ada
python prepare_import.py kuhp-2023 --json out.json --refresh # unduh ulang HTML datahukum
python prepare_import.py kuhp-2023 --json out.json --previous-count 625
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
  ancaman pidana baru (lihat `laws/uu_ite_2008.py`).

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
