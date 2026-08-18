# Smart Search CariPasal

Smart Search dibuat agar pencarian pasal tetap cepat, bisa dipakai offline di mobile, dan lebih tahan typo tanpa perlu AI berbayar.

## Prinsip

- Mobile tetap mencari dari database lokal hasil sync.
- Backend admin memakai PostgreSQL full-text search dan ranking.
- Query dinormalisasi: huruf kecil, tanda baca dibersihkan, spasi dirapikan.
- Nomor pasal selalu diprioritaskan.
- Keyword, judul, isi pasal, dan penjelasan ikut dihitung dalam ranking.
- Sinonim hukum umum ditambahkan sebagai content-aware search ringan.

## Contoh Query yang Dibantu

```text
maling         -> pencurian, mencuri
barang curian  -> penadahan, hasil kejahatan
tipu           -> penipuan, perbuatan curang
narkoba        -> narkotika, psikotropika
judi online    -> perjudian, transaksi elektronik
hoax           -> berita bohong, kabar bohong
```

## Mobile

File utama:

```text
pasal_mobile_app/lib/core/utils/search_utils.dart
pasal_mobile_app/lib/core/services/query_service.dart
pasal_mobile_app/lib/ui/screens/home_screen.dart
pasal_mobile_app/lib/ui/screens/detail_uu_screen.dart
pasal_mobile_app/lib/ui/screens/archive_screen.dart
```

Mobile memakai scoring lokal:

1. nomor pasal exact match;
2. nomor pasal prefix/contains;
3. judul;
4. keyword;
5. isi;
6. penjelasan;
7. synonym match;
8. fuzzy token match untuk typo ringan.

## Backend Admin

File utama:

```text
backend-laravel/app/Http/Controllers/Api/PasalController.php
backend-laravel/database/migrations/2026_08_18_000001_include_keywords_in_pasal_search_vector.php
```

Backend memakai:

```text
search_vector @@ websearch_to_tsquery('simple', query)
ts_rank_cd(search_vector, query)
ILIKE fallback
keyword ranking
```

Migration baru memasukkan `keywords` ke `search_vector`, lalu memicu reindex semua pasal dengan update ringan.

## Kenapa Belum Pakai AI

AI embedding belum dipakai karena:

- perlu biaya API atau model lokal;
- setup server kampus aaPanel jadi lebih berat;
- mobile offline tidak bisa bergantung ke AI online;
- data pasal saat ini masih cukup untuk ranking lokal + full-text search.

Kalau nanti dibutuhkan, AI bisa ditambahkan sebagai tahap berikutnya dengan embedding yang dibuat saat import pasal, bukan setiap user mengetik.
