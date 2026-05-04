# Deploy CariPasal di aaPanel

Target production satu subdomain:

```text
https://pasal.kampus.ac.id/admin  -> React admin dashboard
https://pasal.kampus.ac.id/api    -> Laravel API
```

## 1. Kebutuhan Server

Install dari aaPanel:

- Nginx
- PHP 8.3 atau 8.4
- Composer
- PostgreSQL
- Node.js 22+
- SSL Let's Encrypt

Aktifkan extension PHP:

```text
pdo_pgsql
pgsql
mbstring
openssl
fileinfo
curl
zip
xml
gd
```

## 2. Clone Project

```bash
cd /www/wwwroot
git clone https://github.com/RikiSanjayaa/projek-pasal.git pasal
cd /www/wwwroot/pasal
git checkout main
```

## 3. Setup Database PostgreSQL

Buat database dan user:

```sql
CREATE DATABASE caripasal;
CREATE USER caripasal_user WITH PASSWORD 'ganti_password_database';
GRANT ALL PRIVILEGES ON DATABASE caripasal TO caripasal_user;
```

Jika PostgreSQL 15+ membatasi schema public:

```sql
\c caripasal
GRANT ALL ON SCHEMA public TO caripasal_user;
```

## 4. Setup Laravel API

```bash
cd /www/wwwroot/pasal/backend-laravel
composer install --no-dev --optimize-autoloader
cp .env.production.example .env
php artisan key:generate
```

Edit `.env`:

```env
APP_URL=https://pasal.kampus.ac.id
APP_DEBUG=false

DB_HOST=127.0.0.1
DB_DATABASE=caripasal
DB_USERNAME=caripasal_user
DB_PASSWORD=ganti_password_database

ADMIN_PASSWORD_RESET_URL=https://pasal.kampus.ac.id/admin/reset-password
MOBILE_PASSWORD_RESET_URL=https://pasal.kampus.ac.id/admin/reset-password
```

Jalankan migrasi:

```bash
php artisan migrate --force
php artisan db:seed --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

Permission:

```bash
chown -R www:www storage bootstrap/cache
chmod -R 775 storage bootstrap/cache
```

## 5. Build React Admin

```bash
cd /www/wwwroot/pasal/admin-dashboard
cp .env.production.example .env.production
npm ci
npm run build
mkdir -p /www/wwwroot/pasal/admin
cp -r dist/* /www/wwwroot/pasal/admin/
```

Pastikan `.env.production` berisi:

```env
VITE_API_BASE_URL=https://pasal.kampus.ac.id/api
VITE_APP_BASE_PATH=/admin/
```

## 6. Konfigurasi Nginx aaPanel

Di aaPanel:

```text
Website -> pasal.kampus.ac.id -> Config
```

Tambahkan/atur location berikut. Sesuaikan socket PHP dengan versi aaPanel, misalnya `/tmp/php-cgi-83.sock` atau `/tmp/php-cgi-84.sock`.

```nginx
location = /admin {
    return 301 /admin/;
}

location ^~ /admin/ {
    alias /www/wwwroot/pasal/admin/;
    try_files $uri $uri/ /admin/index.html;
}

location ^~ /api/ {
    try_files $uri /index.php?$query_string;

    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /www/wwwroot/pasal/backend-laravel/public/index.php;
    fastcgi_param DOCUMENT_ROOT /www/wwwroot/pasal/backend-laravel/public;
    fastcgi_param SCRIPT_NAME /index.php;
    fastcgi_param REQUEST_URI $request_uri;
    fastcgi_param HTTPS on;
    fastcgi_pass unix:/tmp/php-cgi-84.sock;
}

location ~ \.php$ {
    return 404;
}
```

Jika aaPanel memakai PHP 8.3:

```nginx
fastcgi_pass unix:/tmp/php-cgi-83.sock;
```

## 7. Smoke Test

Cek dari browser:

```text
https://pasal.kampus.ac.id/api/health
https://pasal.kampus.ac.id/admin
https://pasal.kampus.ac.id/admin/reset-password
```

Cek dari server:

```bash
curl -I https://pasal.kampus.ac.id/api/health
```

Expected API health:

```json
{"status":"ok","time":"..."}
```

## 8. Update Mobile Production

Sebelum build APK/AAB production, ubah `pasal_mobile_app/lib/core/config/env.dart`:

```dart
class Env {
  static const String apiBaseUrl = 'https://pasal.kampus.ac.id/api';
  static const String webAppUrl = 'https://pasal.kampus.ac.id';
}
```

## 9. Perintah Update Deploy Berikutnya

Setiap pull update baru:

```bash
cd /www/wwwroot/pasal
git pull origin main

cd backend-laravel
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache

cd ../admin-dashboard
npm ci
npm run build
rm -rf /www/wwwroot/pasal/admin/*
cp -r dist/* /www/wwwroot/pasal/admin/
```

## 10. Catatan Keamanan

- Jangan commit file `.env`.
- `APP_DEBUG=false` wajib di production.
- PostgreSQL jangan dibuka ke publik.
- Gunakan password super admin yang kuat.
- Backup PostgreSQL sebelum import data Supabase dan sebelum update besar.
