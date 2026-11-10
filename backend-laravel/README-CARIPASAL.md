# CariPasal Laravel Backend

Backend ini adalah target migrasi dari Supabase ke Laravel + PostgreSQL.

## Setup Lokal

```bash
cd backend-laravel
composer install
cp .env.example .env
php artisan key:generate
```

Edit koneksi PostgreSQL di `.env`:

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=caripasal
DB_USERNAME=caripasal_user
DB_PASSWORD=...
```

Jalankan migration dan seed:

```bash
php artisan migrate --seed
php artisan serve
```

Super admin awal dibuat dari env:

```env
CARIPASAL_SUPER_ADMIN_EMAIL=superadmin@caripasal.local
CARIPASAL_SUPER_ADMIN_PASSWORD=ChangeMe123!
CARIPASAL_SUPER_ADMIN_NAME="Super Admin"
```

Ganti password default sebelum production.

## Endpoint Awal

```text
GET  /api/health
POST /api/admin/login
GET  /api/admin/me
POST /api/mobile/login
GET  /api/mobile/sync/full
```

Route lengkap:

```bash
php artisan route:list --path=api
```

## Pengujian akses

Suite backend memakai PostgreSQL karena migrasi menggunakan enum, array, dan trigger PostgreSQL. Siapkan database **khusus pengujian** `caripasal_test` dengan pengguna `caripasal_test`; jangan arahkan pengujian ke database development atau production karena `RefreshDatabase` membangun ulang skema.

```bash
DB_HOST=127.0.0.1 DB_PORT=5432 DB_PASSWORD='<password database pengujian>' vendor/bin/phpunit
```

Host, port, database, dan pengguna dapat ditimpa melalui `DB_HOST`, `DB_PORT`, `DB_DATABASE`, dan `DB_USERNAME`. `MobileAccessTest` mencakup admin/super admin tanpa expiry, expiry pengguna biasa, lease offline 30 hari, isolasi token dashboard/mobile, batas perangkat, dan pencabutan sesi. CI menyediakan PostgreSQL terisolasi untuk suite ini.

## Catatan Migrasi

- UUID lama dari Supabase harus dipertahankan saat import data.
- Password Supabase Auth tidak dimigrasikan langsung. Gunakan reset password atau password awal baru.
- PostgreSQL jangan diekspos publik; cukup Laravel yang bisa mengakses database.
- Admin dashboard production direncanakan di `/admin`, API di `/api`.

## Sumber data dan PDF asli

Tambah/Edit UU menerima `source_url`, `official_pdf_url`, `import_config`, dan unggahan PDF
`official_document` maksimal 20 MiB. Sumber disimpan di `import_sources`, terhubung lewat ID UU.
Simpan hanya mendaftarkan sumber; pengambilan tetap eksplisit melalui Sumber Data. Registrasi
ditampilkan juga saat `DATAHUKUM_FETCH_ENABLED=false`. Empat konfigurasi lama dimigrasikan beserta
koreksinya. Mengosongkan URL menyembunyikan sumber tanpa memutus identitas draf dan riwayatnya.

Penanda versi asli opsional; worker mendeteksinya dari metadata HTML saat pemeriksaan. Status
konfigurasi `ready` tidak menyatakan parser sudah berhasil. Katalog menyertakan `parse_status`
`unverified|passed|failed`, berdasarkan hasil run terminal yang cocok dengan snapshot konfigurasi
dan lampiran saat ini. Mengganti URL, metadata, atau PDF tidak mewarisi bukti parsing snapshot lama.
Wrapper CLI menjaga field peta JSON tetap object setelah round-trip PostgreSQL/PHP, termasuk peta
koreksi kosong, agar empat konfigurasi migrasi tetap dapat dijalankan.


Setiap run menyimpan `source_config` dan path lampiran privat yang tidak berubah setelah antre.
Backend dan worker harus berbagi volume `caripasal_law_documents` pada
`storage/app/private/law-documents`; `IMPORT_DOCUMENTS_DIR` menunjuk lokasi yang sama pada worker.
PDF tidak dipublikasikan lewat storage link; endpoint unduhan memerlukan token admin aktif.
Worker memeriksa ulang flag pengambilan sebelum menjalankan parser. Pengambilan HTML/PDF memakai
host HTTPS yang disetujui, validasi DNS publik dan pemeriksaan setiap redirect.

Image Docker memakai `artisan serve --no-reload` agar environment container diteruskan ke proses
HTTP, termasuk koneksi database dan flag pengambilan. Batas PHP unggahan 20M dan request 24M;
proxy dashboard membatasi request 24m agar multipart PDF 20 MiB dapat diterima.

