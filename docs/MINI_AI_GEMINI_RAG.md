# Mini AI CariPasal

Mini AI dibuat untuk aplikasi mobile. Cara kerjanya:

```text
Pertanyaan user mobile -> Laravel cari pasal relevan di PostgreSQL -> Gemini menyusun jawaban dari pasal itu saja -> mobile menampilkan jawaban + rujukan pasal
```

Ini bukan MCP. Ini pola **RAG**:

- aplikasi mengambil konteks dari database CariPasal;
- Gemini hanya dipakai untuk merapikan jawaban;
- API key Gemini disimpan di backend Laravel;
- APK/mobile web tidak menyimpan API key.

## Endpoint

```text
POST /api/mobile/ai-chat
```

Endpoint ini memakai auth mobile yang sudah ada, jadi user harus login.

Contoh response:

```json
{
  "answer": "Berdasarkan data yang tersedia...",
  "sources": [
    {
      "id": "uuid-pasal",
      "nomor": "12",
      "judul": "Judul pasal",
      "undang_undang": {
        "id": "uuid-uu",
        "kode": "KUHP",
        "nama": "Kitab Undang-Undang Hukum Pidana"
      }
    }
  ],
  "model": "gemini-3.1-flash-lite",
  "response_ms": 1200,
  "is_configured": true
}
```

## Setup Production

Isi `.env` Laravel:

```env
GEMINI_API_KEY=isi_api_key_google_ai_studio
GEMINI_MODEL=gemini-3.1-flash-lite
GEMINI_TIMEOUT=20
```

Setelah ubah `.env`:

```bash
cd /www/wwwroot/pasal/backend-laravel
/www/server/php/84/bin/php artisan optimize:clear
/www/server/php/84/bin/php artisan config:cache
sudo /etc/init.d/php-fpm-84 restart
```

Untuk server kampus dengan path berbeda, sesuaikan folder project dan versi PHP.

## Migration

Fitur ini menambah tabel:

```text
ai_chat_logs
```

Tabel ini menyimpan pertanyaan, jawaban, model, rujukan pasal, dan waktu response untuk kebutuhan audit/debug.

Jalankan saat deploy:

```bash
/www/server/php/84/bin/php artisan migrate --force
```

## Catatan Penting

- Kalau `GEMINI_API_KEY` belum diisi, aplikasi tetap bisa dibuka, tetapi Asisten akan memberi pesan bahwa AI belum dikonfigurasi.
- Jawaban AI wajib menampilkan rujukan pasal yang ditemukan dari database.
- AI tidak boleh menjawab di luar data CariPasal. Jika data tidak cukup, AI diarahkan untuk mengatakan belum menemukan dasar pasal.
- Untuk jawaban cepat dan hemat biaya, model default memakai `gemini-3.1-flash-lite`.
