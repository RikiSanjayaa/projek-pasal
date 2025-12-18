# Panduan Deployment Lokal - CariPasal

Dokumen ini adalah **versi LOCAL (self-hosted)** dari file deployment sebelumnya. Seluruh isi, struktur, dan urutan tetap sama, **hanya Supabase dijalankan secara lokal menggunakan Docker** (bukan Supabase Cloud).

---

## Daftar Isi

1. [Setup Supabase Lokal (Docker)](#1-setup-supabase-lokal-docker)
2. [Setup Admin Dashboard](#2-setup-admin-dashboard)
3. [Deploy Admin Dashboard (Lokal)](#3-deploy-admin-dashboard-lokal)
4. [Setup Mobile App](#4-setup-mobile-app)

---

## 1. Setup Supabase Lokal (Docker)

### 1.1 Persiapan Direktori Proyek

Unduh konfigurasi Docker Supabase resmi atau gunakan repository proyek Anda yang sudah menyertakan folder `docker` dan `supabase`:

```bash
# Opsi 1: Clone Supabase resmi (pertama kali)
git clone --depth 1 https://github.com/supabase/supabase.git
cd supabase/docker

# Opsi 2: Gunakan repository proyek sendiri
git clone <URL_REPOSITORY_ANDA> caripasal
cd caripasal/docker
```

---

### 1.2 Konfigurasi Variabel Lingkungan

Salin template environment:

```bash
cp .env.example .env
```

Edit file `.env`:

```env
POSTGRES_PASSWORD=postgresku
JWT_SECRET=super-secret-jwt
SITE_URL=http://localhost:3000
API_EXTERNAL_URL=http://localhost:8000
```

Catatan:
- `SITE_URL` dan `API_EXTERNAL_URL` **wajib localhost** untuk mode lokal
- Tidak perlu domain atau SSL

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

### 1.6 API Keys Lokal

Buka **Settings → API** di Supabase Studio:

Gunakan:
- **Project URL** → `http://localhost:8000`
- **anon key** → untuk frontend
- **service_role key** → hanya untuk server / edge function

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

Jika menggunakan Supabase Edge Function lokal:

```bash
npx supabase start
npx supabase functions deploy create-admin
```

Atau jalankan langsung via SQL Editor jika masih tahap development.

---

## 3. Deploy Admin Dashboard (Lokal)

### Opsi A: Development Mode

```bash
npm run dev
```

### Opsi B: Build + Nginx Lokal

```bash
npm run build
```

Upload folder `dist` ke server lokal lalu konfigurasi Nginx:

```nginx
server {
    listen 80;
    server_name localhost;

    root /var/www/caripasal-admin;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 4. Setup Mobile App

_(Sama seperti versi cloud, hanya URL Supabase diganti lokal)_

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

- Mode **LOCAL hanya untuk development & kampus**
- Jangan expose `service_role key`
- Backup volume Docker sebelum reset

---

✅ **File ini siap dipakai sebagai pengganti DEPLOYMENT.md untuk mode lokal tanpa mengubah struktur proyek.**

