# import-tools

Pipeline yang mengambil teks undang-undang dari datahukum.com, membandingkannya dengan PDF resmi
BPK, lalu menghasilkan file Bulk Import (xlsx) atau JSON untuk impor dari dashboard admin.
UU yang terdaftar ada di `laws/` (satu file per UU).

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
  penjelasan, keywords[], links[], riwayat[], status_teks, review`. Teksnya persis sama dengan
  sheet `import` dan `riwayat` di xlsx.
- Gagal struktural (div `batangtubuh`/`pasal` hilang, HTML tidak terbaca, unduhan gagal, jumlah
  pasal anjlok): exit 2 dan `out.json` berisi `{"error": "<pesan Indonesia>"}`.
- `unknown_versions`: class versi (`uu-...`) di HTML yang bukan versi asli maupun versi perubahan di
  konfigurasi UU. Kalau tidak kosong, ada UU perubahan baru yang belum dikonfigurasi.
- `warnings`: di mode xlsx, entri `text_fixes` yang tidak cocok lagi menghentikan skrip. Di mode JSON
  perbaikan itu dilewati dan dicatat sebagai peringatan `{nomor, message}`.

## PDF UU perubahan

`Amendment.pdf` adalah nama file di folder cache dan `Amendment.pdf_url` sumber unduhannya (BPK).
PDF diunduh sekali kalau belum ada, seperti PDF BPK utama.

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
