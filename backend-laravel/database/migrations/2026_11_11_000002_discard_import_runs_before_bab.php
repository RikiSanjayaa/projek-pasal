<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Draft Sumber Data yang dibuat sebelum 2026_11_11_000001 menyimpan `keywords` dan tidak punya `bab`
 * di payload item. Diffnya sudah tidak berlaku (pembandingnya kolom yang sudah dihapus), dan menerapkannya
 * gagal karena `bab` tidak ada. Draft seperti itu dibuang supaya UU tersebut bisa dicek ulang lewat run baru.
 * Run yang sedang berjalan saat migrasi diproses kode lama, jadi ikut dibuang.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::update(<<<'SQL'
            UPDATE import_runs r
            SET status = 'discarded',
                finished_at = COALESCE(r.finished_at, NOW()),
                error = 'Dibuang otomatis: draft ini dibuat sebelum kata kunci diganti kolom bab. Jalankan pengecekan baru.',
                updated_at = NOW()
            WHERE r.status = 'running'
               OR (r.status = 'ready' AND EXISTS (
                    SELECT 1 FROM import_run_items i
                    WHERE i.import_run_id = r.id
                      AND ((i.incoming IS NOT NULL AND i.incoming -> 'bab' IS NULL)
                        OR (i.current IS NOT NULL AND i.current -> 'bab' IS NULL))
               ))
        SQL);
    }

    public function down(): void
    {
        // Draft yang dibuang tidak dikembalikan: payload lama tidak cocok dengan skema mana pun sesudah migrasi.
    }
};
