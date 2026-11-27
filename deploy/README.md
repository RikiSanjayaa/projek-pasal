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

Script deploy default ke `$HOME/deployments/caripasal` dan `$HOME/deployments/backup-prod.sh`. Jika user deploy memakai home lain, letakkan folder deployment dan script backup di bawah home user itu.

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

## Deploy lewat GitHub Actions

Workflow `.github/workflows/deploy.yml` berjalan dua cara:

- **Otomatis**: setelah workflow `images` selesai sukses untuk `main`, tag `sha-<7 karakter commit>` langsung dikirim ke server. Artinya merge ke `main` akan men-deploy begitu build image selesai.
- **Manual**: `workflow_dispatch` dengan input `tag`, misalnya `sha-27dfcf2`. Dipakai untuk rollback ke commit lama atau deploy ulang.

Untuk mematikan deploy otomatis, hapus blok `workflow_run` pada `on:` di file itu; `workflow_dispatch` tetap bekerja.

Workflow tidak membangun image; ia mengirim satu perintah `deploy caripasal <tag>` ke `deploy/deploy-gateway.sh` di server.

Pasang gateway dan script di server:

```text
~/deployments/deploy-gateway.sh                     0755
~/deployments/caripasal/deploy/deploy-caripasal.sh  0755
```

Izinkan key deploy hanya untuk perintah itu, bukan shell bebas. Baris di `~/.ssh/authorized_keys` milik user deploy:

```text
restrict,command="/home/<deploy-user>/deployments/deploy-gateway.sh" ssh-ed25519 AAAA... github-actions-deploy
```

Gateway menolak segalanya kecuali `deploy <caripasal|sita> sha-<hex>`, lalu menjalankan script dengan `TAG` di environment. Script server akan:

1. menyimpan `deploy.env` lama;
2. menarik image baru;
3. menjalankan `backup-prod.sh`;
4. mengganti image di `deploy.env`;
5. `up -d` dan cek `/api/health`, admin, dan mobile;
6. rollback ke `deploy.env` lama jika health gagal.

Secret repository atau environment `production`:

| Secret | Isi |
|---|---|
| `DEPLOY_HOST` | Hostname atau IP server |
| `DEPLOY_USER` | User SSH khusus deploy |
| `DEPLOY_SSH_KEY` | Private key user deploy |
| `DEPLOY_KNOWN_HOSTS` | Output `ssh-keyscan -H <host>` |
| `DEPLOY_PORT` | Opsional, default 22 |

Gunakan user deploy khusus dan key khusus. Jangan memakai key pribadi. Aktifkan required reviewer pada environment `production` jika tersedia.

## Test lab

Script lab menjalankan image GHCR yang sama di project Docker terpisah, port `28081` dan `28082`, dengan database kosong, lalu menghapus semuanya:

```bash
TAG=sha-27dfcf2 ./deploy/lab-caripasal.sh
```

Script memerlukan Docker dan akses GHCR. Script ini tidak menyentuh volume atau container produksi.

## Binding port

Default:

```yaml
ADMIN_BIND=0.0.0.0
MOBILE_BIND=0.0.0.0
ADMIN_PORT=8081
MOBILE_PORT=8082
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
