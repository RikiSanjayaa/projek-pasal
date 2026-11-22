# Deployment produksi CariPasal

`compose.production.yml` hanya menjalankan image dari GHCR. Tidak ada `build:` dan tidak perlu source code di server.

Image dibangun oleh `.github/workflows/images.yml` setelah `CI - Build Verification` lulus di `main`:

- `ghcr.io/<owner>/caripasal-app:sha-<commit>`
- `ghcr.io/<owner>/caripasal-admin:sha-<commit>`
- `ghcr.io/<owner>/caripasal-mobile:sha-<commit>`

Tag `main` dan `latest` juga tersedia, tetapi deploy produksi sebaiknya memakai `sha-<commit>` agar rollback jelas.

## File yang harus ada di server

Letakkan di folder yang sama dengan `compose.production.yml`:

```text
app.env
bootstrap.env
deploy/nginx/backend.conf
deploy/php/production.ini
```

Isi `app.env` dan `bootstrap.env` tidak masuk git. Salin dari server lama atau buat dari template yang sesuai.

## Deploy

```bash
export CARIPASAL_APP_IMAGE=ghcr.io/<owner>/caripasal-app:sha-<commit>
export CARIPASAL_ADMIN_IMAGE=ghcr.io/<owner>/caripasal-admin:sha-<commit>
export CARIPASAL_MOBILE_IMAGE=ghcr.io/<owner>/caripasal-mobile:sha-<commit>

docker compose -f compose.production.yml pull
docker compose -f compose.production.yml up -d --remove-orphans
```

Service `init` menjalankan `php artisan migrate --force` satu kali sebelum `app`, `imports`, dan `backend` mulai. Tidak ada seeder.

Cek status:

```bash
docker compose -f compose.production.yml ps
docker compose -f compose.production.yml exec backend wget -qO- http://127.0.0.1:8000/up
```

`backend` hanya mendengarkan di jaringan Docker. Port publik ada di `admin` dan `mobile`.

## Binding port

Default:

```yaml
ADMIN_BIND=0.0.0.0
MOBILE_BIND=0.0.0.0
```

Setelah aaPanel menjadi reverse proxy, ubah menjadi:

```bash
export ADMIN_BIND=127.0.0.1
export MOBILE_BIND=127.0.0.1
```

## Rollback

Ganti ketiga variabel image ke tag commit sebelumnya, lalu:

```bash
docker compose -f compose.production.yml pull
docker compose -f compose.production.yml up -d --remove-orphans
```

Volume `caripasal_database` dan `caripasal_storage` tidak tersentuh oleh pergantian image.

## Build lokal untuk verifikasi

Dari root repo:

```bash
docker build -f backend-laravel/Dockerfile.production -t caripasal-app:local .
docker build -t caripasal-admin:local admin-dashboard
docker build -t caripasal-mobile:local pasal_mobile_app
```

Lalu jalankan compose dengan image lokal:

```bash
export CARIPASAL_APP_IMAGE=caripasal-app:local
export CARIPASAL_ADMIN_IMAGE=caripasal-admin:local
export CARIPASAL_MOBILE_IMAGE=caripasal-mobile:local
export CARIPASAL_PULL_POLICY=never
docker compose -f compose.production.yml up -d
```

Build backend memakai context root karena image membutuhkan `import-tools`. `.dockerignore` di root membatasi context.
