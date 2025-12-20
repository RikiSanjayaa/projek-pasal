# Panduan Deployment Lokal - CariPasal

Dokumen ini adalah **versi LOCAL (self-hosted)** dari file deployment sebelumnya. Seluruh isi, struktur, dan urutan tetap sama, **hanya Supabase dijalankan secara lokal menggunakan Docker** (bukan Supabase Cloud).

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

### 1.1 Instalasi dan cara start

```bash
# Get the code
git clone --depth 1 https://github.com/supabase/supabase

# Make your new supabase project directory
mkdir supabase-project

# Tree should look like this
# .
# ├── supabase
# └── supabase-project

# Copy the compose files over to your project
cp -rf supabase/docker/* supabase-project

# Copy the fake env vars
cp supabase/docker/.env.example supabase-project/.env

# Switch to your project directory
cd supabase-project

# Pull the latest images
docker compose pull

```

---

### 1.2 Konfigurasi Variabel Lingkungan

Edit file `.env` (NOTE: gunakan secret generator dari [self-hosting supabase docker](https://supabase.com/docs/guides/self-hosting/docker) untuk mengganti key `JWT_SECRET`, `ANON_KEY`, dan `SERVICE_ROLE_KEY`):

```env
POSTGRES_PASSWORD=postgresku
SITE_URL=http://localhost:3000
API_EXTERNAL_URL=http://localhost:8000
```

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

Setelah container aktif, jalankan migrasi database secara berurutan:

```bash
docker exec -i supabase-db psql -U supabase_admin -d postgres < ../supabase/migrations/001_initial_schema.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < ../supabase/migrations/002_rls_policies.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < ../supabase/migrations/003_search_functions.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < ../supabase/migrations/004_pasal_links_audit.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres < ../supabase/migrations/005_remove_ip_in_audit.sql
```

Seed data (opsional):

```bash
docker exec -i supabase-db psql -U supabase_admin -d postgres < ../supabase/seed.sql
```

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

copy isi folder yang ada pada repo: `supabase/functions/` ke directory docker `docker/volumes/functions`.

contoh: jika repo yang di clone berada di `~/projek-pasal/supabase/` dan supabase docker berada di `~/supabase/docker/`

```bash
cp -r ~/projek-pasal/supabase/functions/create-admin ~/supabase/docker/volumes/functions/
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

_(Sama seperti versi cloud, hanya URL Supabase diganti)_

### 4.1 Konfigurasi

Edit `lib/core/config/env.dart`:

```dart
class Env {
  static const supabaseUrl = 'http://localhost:8000';
  static const supabaseAnonKey = 'your-local-anon-key';
}
```

---

## Catatan Penting

- Jangan expose `service_role key`
- Backup volume Docker sebelum reset

---
