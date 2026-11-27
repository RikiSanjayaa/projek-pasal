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

## Deploy lewat GitHub Actions

Workflow `.github/workflows/deploy.yml` hanya berjalan manual (`workflow_dispatch`). Isi input `tag`, misalnya `sha-27dfcf2`. Workflow tidak membangun image; ia memanggil `deploy/deploy-caripasal.sh` di server.

Script server akan:

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

Setelah aaPanel menjadi reverse proxy dan routing hostname berhasil diuji, simpan binding di `deploy.env` agar tetap berlaku pada deploy berikutnya:

```dotenv
ADMIN_BIND=127.0.0.1
MOBILE_BIND=127.0.0.1
```

Terapkan hanya ke frontend tanpa menjalankan ulang init, migrasi, atau seeder:

```bash
docker compose --env-file deploy.env -f compose.production.yml up -d --no-deps --no-build --pull never admin mobile
```

Vhost aaPanel kampus memakai `admin-caripasal.ubg.ac.id` ke `http://127.0.0.1:8081` dan `caripasal.ubg.ac.id` ke `http://127.0.0.1:8082`. Verifikasi API melalui nginx lokal, bukan hanya langsung ke port Docker:

```bash
curl -f -H 'Host: admin-caripasal.ubg.ac.id' http://127.0.0.1/api/health
curl -f -H 'Host: caripasal.ubg.ac.id' http://127.0.0.1/api/health
```

Routing HTTP origin tidak memerlukan sertifikat. SSL dan akses melalui Cloudflare harus diuji terpisah setelah dikonfigurasi admin kampus.

### HTTPS dan PWA kampus

Pemeriksaan 23 November 2026: `APP_URL` backend memakai `https://admin-caripasal.ubg.ac.id`, cookie sesi memakai `Secure`, dan port admin/mobile tetap terikat ke `127.0.0.1:8081` serta `127.0.0.1:8082`. TLS berakhir di aaPanel; upstream Docker tetap HTTP loopback.

Origin `https://caripasal.ubg.ac.id` berhasil merender halaman login Flutter. Manifest sama dengan `https://app-caripasal.sanjaya.uk/manifest.json`, termasuk `display: standalone` dan ikon 192/512. Service worker `/caripasal-sw.js` aktif; pemeriksaan Chrome `Page.getAppManifest` dan `Page.getInstallabilityErrors` tidak mengembalikan error. Ini membuktikan kesiapan origin, bukan pemasangan pada ponsel pengguna.

Pemeriksaan respons penolakan publik membuktikan Cloudflare mengirim Challenge Page untuk `/manifest.json`: HTTP 403, `cf-mitigated: challenge`, `content-type: text/html`, dan judul `Just a moment...`. Ray ID pemeriksaan adalah `a5ecb1ac0be092f2-SIN` pada 23 November 2026, 02:20:19 UTC. Ini bukan penolakan manifest oleh kode Flutter. Identifikasi Service/Rule pemicu melalui Security Events sebelum membuat pengecualian; jangan menonaktifkan seluruh proteksi situs atau autentikasi API.

Koreksi laporan pengguna: pengujian mobile yang sebelumnya dianggap berhasil ternyata membuka URL homelab, bukan kampus. Desktop kampus bekerja, tetapi pemasangan PWA mobile kampus masih terbuka; console pengguna menunjukkan fetch manifest 403. Kesiapan origin tidak membuktikan jalur publik sudah dapat mengambil manifest.

Admin/pengguna melaporkan Force HTTPS sudah dikerjakan. Konfirmasi ini berasal dari pengguna, bukan pengujian ulang redirect atau pembacaan mode SSL Cloudflare dalam sesi ini. Pertahankan upstream loopback di atas.

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
