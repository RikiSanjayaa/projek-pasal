# Mobile Web (Flutter Web) di aaPanel

Mobile web dibuka di `/mobile/` pada domain yang sama dengan API:

```text
https://ubgpasal.ubg.ac.id/admin/       Admin dashboard React
https://ubgpasal.ubg.ac.id/api/         Laravel REST API
https://ubgpasal.ubg.ac.id/mobile/      Flutter Web mobile (PWA offline)
```

Server tidak membuild Flutter dan tidak ada hasil build yang di-commit. Alurnya:

```text
push ke main (mengubah pasal_mobile_app/) -> GitHub Actions build -> rilis GitHub mobile-web
-> server: git pull + aapanel-mobile-web-update.sh -> unduh build -> salin ke mobile/
```

## 1. Build di CI

Workflow `.github/workflows/mobile-web.yml` (Mobile Web Release) berjalan setiap push ke `main`
yang mengubah `pasal_mobile_app/`, workflow itu sendiri, atau `deploy/mobile-web-version.sh`:

1. Tes mobile (`flutter test`) dan tes worker offline (`node --test`).
2. `dart run tool/build_web.dart --release --no-tree-shake-icons --base-href=/mobile/
   --dart-define=API_BASE_URL=/api`. Builder ini menyiapkan worker `caripasal-sw.js` dengan
   manifest SHA-256 seluruh file, `offline.js`, dan `offline-build.json`. `flutter build web`
   langsung tidak menyiapkan cache offline.
3. Unggah `caripasal-mobile-web-<id>.tar.gz` dan `.sha256` ke rilis
   [`mobile-web`](https://github.com/RikiSanjayaa/projek-pasal/releases/tag/mobile-web). Sepuluh build
   terbaru disimpan.

API relatif `/api` membuat satu build bisa dipakai di server mana pun, asalkan mobile web
disajikan di `/mobile/` pada domain yang sama dengan `/api/`.

`<id>` adalah 12 karakter commit terakhir yang mengubah input build, dicetak oleh
`deploy/mobile-web-version.sh`. CI dan server menjalankan script yang sama, jadi server selalu
mengunduh build yang cocok dengan kode yang sedang di-checkout. Commit yang hanya mengubah
backend atau admin tidak mengubah `<id>`, sehingga build sebelumnya tetap dipakai.

Build bisa dijalankan ulang manual dari tab Actions > Mobile Web Release > Run workflow. Build yang
`<id>`-nya sudah ada di rilis tidak dibuild ulang.

## 2. Publish di Server

Setelah `git pull` (atau di dalam script deploy):

```bash
cd "$APP_ROOT"
SKIP_GIT=1 bash deploy/aapanel-mobile-web-update.sh
```

`aapanel-publish-mobile-web.sh` (dipanggil oleh script di atas):

- menghitung `<id>` dari checkout server, mengunduh `caripasal-mobile-web-<id>.tar.gz` dan
  `.sha256` dari rilis GitHub, lalu mencocokkan checksum;
- menolak build yang tidak punya `index.html`, `caripasal-sw.js`, `offline.js`, atau
  `offline-build.json`;
- mengganti isi `$APP_ROOT/mobile/`, mengatur permission ke user web aaPanel, reload Nginx.

Jika build belum ada (CI masih berjalan beberapa menit setelah push), script berhenti dengan
pesan `Build mobile web ... belum tersedia` tanpa mengubah `mobile/`. Tunggu workflow selesai,
lalu ulangi.

Server butuh `curl`, `tar`, `sha256sum`, dan akses HTTPS ke `github.com` (dicek oleh
`deploy/aapanel-doctor.sh`). Variabel opsional: `MOBILE_WEB_VERSION` (pakai `<id>` tertentu),
`MOBILE_WEB_RELEASE` (default `mobile-web`), `GITHUB_REPO`.

## 3. Nginx

Di config Nginx domain, di dalam `server { ... }`:

```nginx
include /www/wwwroot/hukum-ubg.ac.id/projek-pasal/deploy/aapanel-mobile-web.conf;
```

Server dengan `APP_ROOT` lain menyalin isi file itu dan mengganti `root`; jangan mengedit file di
repo, karena `git pull --ff-only` akan gagal. Konfigurasi memberi header COOP/COEP untuk database
web, mencegah cache HTTP entrypoint/worker yang tertinggal, dan mengembalikan 404 untuk aset yang
tidak ada. Worker yang hilang tidak boleh mendapat respons `index.html` dari fallback SPA.

```bash
/www/server/nginx/sbin/nginx -t && /etc/init.d/nginx reload
```

## 4. Tes Setelah Publish

```bash
curl -I https://ubgpasal.ubg.ac.id/mobile/
curl -sI https://ubgpasal.ubg.ac.id/mobile/caripasal-sw.js | grep -i cross-origin
curl https://ubgpasal.ubg.ac.id/api/health
```

Jika masih tampil versi lama:

- sambungkan internet dan buka Profil/Pengaturan; periksa pemberitahuan versi baru;
- tutup seluruh tab CariPasal dan aplikasi terpasang, lalu buka kembali agar worker baru dapat aktif;
- jangan menyarankan hapus data situs atau incognito untuk memakai data offline yang sudah diunduh.
  Keduanya memakai atau membuat penyimpanan berbeda; hapus data situs menghapus data lokal.

Uji setelah login dan sinkronisasi selesai: status harus **Siap digunakan offline**, matikan
jaringan, reload, tutup/buka tab, lalu cari pasal dan periksa bookmark. Batas akses tetap maksimal
30 hari dan tidak melewati masa aktif akun. Uji instalasi/cold launch juga pada Android dan
Safari/iOS fisik sebelum menjanjikan dukungan perangkat tersebut.

## 5. Build Lokal (Pengembang)

Untuk mencoba di laptop, build dengan builder yang sama:

```bash
cd pasal_mobile_app
dart run tool/build_web.dart --release --base-href=/mobile/ --dart-define=API_BASE_URL=/api
```

Hasilnya di `pasal_mobile_app/build/web`. Sajikan dengan header COOP/COEP dan proxy `/api` ke
backend lokal, atau pakai `docker compose up mobile-web`. Jangan mengubah file hasil builder:
SHA-256 di worker harus cocok dengan byte yang disajikan.

## 6. Catatan Cloudflare

Endpoint `/api/*` tidak boleh diberi challenge:

```text
Hostname equals ubgpasal.ubg.ac.id
AND URI Path starts with /api/
Action: Skip/Allow challenge security features
```

Kalau `/api/*` kena challenge, mobile web dan APK gagal login/sync.

## 7. Bedanya Mobile Web dan APK

Mobile web dibuka lewat browser di `/mobile/`, bisa dipakai iPhone dan Android tanpa install APK,
dan bisa dibuka ulang tanpa jaringan setelah file aplikasi, data hukum, dan metadata akses
tersimpan. Penyimpanan tetap tunduk pada kebijakan browser dan batas akses akun.

APK khusus Android, dibuild pengembang dengan URL absolut
(`--dart-define=API_BASE_URL=https://<domain>/api`), dan perlu build baru setiap ada update
aplikasi.
