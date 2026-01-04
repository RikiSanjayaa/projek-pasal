# Panduan Deployment Lokal - CariPasal

Dokumen ini adalah **versi LOCAL (self-hosted)** supabase dan admin dashboard. Seluruh isi, struktur, dan urutan tetap sama, **hanya Supabase dijalankan secara lokal menggunakan Docker** (bukan Supabase Cloud).

---

## Daftar Isi

1. [Setup Supabase Lokal (Docker)](#1-setup-supabase-lokal-docker)
2. [Setup Admin Dashboard](#2-setup-admin-dashboard)
3. [Deploy Admin Dashboard (Lokal)](#3-deploy-admin-dashboard-lokal)
4. [Setup Mobile App](#4-setup-mobile-app)

---

## 1. Setup Supabase Lokal (Docker). referensi: [self-hosting supabase docker](https://supabase.com/docs/guides/self-hosting/docker)

### 1.0 System Requirements

| Resource |   Minimum | Recommended |
| -------- | --------: | ----------: |
| RAM      |      4 GB |       8 GB+ |
| CPU      |   2 cores |    4 cores+ |
| Disk     | 50 GB SSD |  80 GB+ SSD |

### 1.1 Instalasi Supabase + Projek CariPasal

```bash
# Ambil kode supabase
git clone --depth 1 https://github.com/supabase/supabase

# clone kode projek CariPasal
git clone https://github.com/RikiSanjayaa/projek-pasal.git

# Tree should look like this
# .
# ├── supabase
# └── projek-pasal

# Copy compose file ke projek-pasal
cp -rf supabase/docker/* projek-pasal

# Copy contoh env ke projek-pasal
cp supabase/docker/.env.example projek-pasal/.env

# pindah ke projek-pasal directory
cd projek-pasal

# pull image
docker compose pull

```

---

### 1.2 Konfigurasi Variabel environment

Edit file `.env` (NOTE: gunakan secret generator dari [self-hosting supabase docker](https://supabase.com/docs/guides/self-hosting/docker) untuk mengganti key `JWT_SECRET`, `ANON_KEY`, dan `SERVICE_ROLE_KEY`) atau gunakan script `./supabase/docker/generate-env.sh` (NOTE: script ini masih beta dan perlu direview hasilnya):

```bash
sh ./utils/generate-keys.sh
```

Review dan ganti URL variabel environment:

```env
SITE_URL: the base URL of your site, e.g., http://localhost:3000
ADDITIONAL_REDIRECT_URLS: the base URL of your site, e.g., http://localhost:3000
API_EXTERNAL_URL: the base URL for API requests, e.g., http://localhost:8000

SUPABASE_PUBLIC_URL: the base URL for accessing your Supabase via the Internet, e.g, http://localhost:8000
```

---

### 1.2.1 Konfigurasi SMTP (Email untuk Reset Password & Verifikasi)

Supabase memerlukan SMTP untuk mengirim email seperti:
- Reset password
- Verifikasi email
- Account recovery

#### Menggunakan Resend (Gratis 3,000 email/bulan)

1. **Daftar akun di [Resend](https://resend.com/signup)**

2. **Buat API Key:**
   - Masuk ke dashboard Resend
   - Pergi ke **API Keys** → **Create API Key**
   - Simpan API key yang dihasilkan

3. **Tambahkan domain (opsional tapi disarankan):**
   - Pergi ke **Domains** → **Add Domain**
   - Ikuti instruksi DNS verification

4. **Update file `.env` Supabase:**

```env
# SMTP Configuration - Resend
SMTP_ADMIN_EMAIL=noreply@yourdomain.com
SMTP_HOST=smtp.resend.com
SMTP_PORT=465
SMTP_USER=resend
SMTP_PASS=re_xxxxxxxxxxxxxxxxxxxxxxxxx  # API Key dari Resend
SMTP_SENDER_NAME=CariPasal
```

#### Catatan Penting SMTP:

| Item | Keterangan |
|------|------------|
| Free Tier | 3,000 email/bulan, 100 email/hari |
| Alternatif | Brevo (300/hari), Mailgun, atau self-hosted Postfix |
| Testing | Tanpa SMTP, email akan ditangkap oleh Inbucket di `http://localhost:9000` |

---

### 1.3 Menjalankan Supabase Lokal

Jalankan seluruh service Supabase:

```bash
docker compose up -d
```

Verifikasi:

```bash
docker ps
```

Service yang harus aktif:

- supabase-db
- supabase-auth
- supabase-rest
- supabase-studio

Akses Supabase Studio:

```
http://localhost:3000
```

---

### 1.4 Migrasi Database (Spesifik Proyek CariPasal)

Setelah container aktif, jalankan migrasi database menggunakan script otomatis:

```bash
# Jalankan semua migration sekaligus
sh utils/run-migrations.sh
```

Script ini akan menjalankan semua file `.sql` di folder `supabase/migrations/` secara berurutan dan menawarkan opsi untuk menjalankan seed data.

<details>
<summary>Alternatif: Jalankan migration secara manual (satu per satu)</summary>

```bash
docker exec -i supabase-db psql -U supabase_admin -d postgres < supabase/migrations/001_initial_schema.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < supabase/migrations/002_rls_policies.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < supabase/migrations/003_search_functions.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < supabase/migrations/004_pasal_links_audit.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < supabase/migrations/005_remove_ip_in_audit.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < supabase/migrations/006_fix_get_download_data.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < supabase/migrations/007_fix_pasal_links_rls.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < supabase/migrations/008_audit_logs_retention.sql

# Seed data (opsional)
docker exec -i supabase-db psql -U supabase_admin -d postgres < supabase/seed.sql
```

</details>

---

### 1.5 Membuat Super Admin Pertama (Lokal)

1. Buka Supabase Studio
   ```
   http://localhost:3000
   ```
2. Masuk menu **Authentication → Users**
3. Buat user baru (email + password)
4. Salin `user_id`

Jalankan SQL:

```sql
INSERT INTO admin_users (id, email, nama, role)
VALUES (
  'USER_ID_DISINI',
  'admin@local.test',
  'Super Admin Lokal',
  'super_admin'
);
```

---

## 2. Setup Admin Dashboard

### 2.1 Prerequisites

- Node.js >= 18
- npm / pnpm

---

### 2.2 Install Dependencies

```bash
cd admin-dashboard
npm install
```

---

### 2.3 Konfigurasi Environment

```bash
cp .env.example .env
```

Edit `.env`:

```env
VITE_SUPABASE_URL=http://localhost:8000
VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY=your-local-anon-key
VITE_APP_NAME=CariPasal Admin (Local)
```

---

### 2.4 Jalankan Development Server

```bash
npm run dev
```

Akses:

```
http://localhost:5173
```

---

### 2.5 Create Admin (Edge Function Lokal)

copy isi folder yang ada pada repo: `supabase/functions/` ke directory supabase docker yang di copy tadi `volumes/functions`.

```bash
cp -r ~/projek-pasal/supabase/functions/create-admin ~/projek-pasal/volumes/functions/
```

---

## 3. Deploy Admin Dashboard (Lokal)

### Opsi A: Development Mode

```bash
npm run dev
```

### Opsi B: Build dengan Docker

```bash
docker compose up -d
```

---

## 4. Setup Mobile App

### 4.1 Prerequisites

- Flutter SDK >= 3.8
- Android Studio / Xcode

### 4.2 Install Dependencies

```bash
cd pasal_mobile_app
flutter pub get
```

### 4.3 Configure Environment

Copy dan edit file konfigurasi:

```bash
cp lib/core/config/env-example.dart lib/core/config/env.dart
```

Edit `lib/core/config/env.dart` dengan URL Supabase lokal:

```dart
class Env {
  static const String supabaseUrl = 'http://localhost:8000';  // atau IP server
  static const String supabaseAnonKey = 'your-local-anon-key';
}
```

### 4.4 Jalankan Aplikasi

```bash
flutter run
```

> **Note**: Untuk menghubungkan ke Supabase lokal dari device fisik, ganti `localhost` dengan IP address komputer Anda (contoh: `http://192.168.1.100:8000`).

---

## Catatan Penting

- Jangan expose `service_role key`
- Backup volume Docker sebelum reset
- Gunakan perintah ini jika gagal login padahal anonkeynya sudah benar
- `docker compose build --no-cache web-admin`
- `docker compose up -d web-admin`

---
