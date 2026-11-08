<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Riwayat rumusan pasal akibat perubahan undang-undang (contoh: UU 1/2026 mengubah KUHP).
 * Tabel pasal tetap menyimpan rumusan yang berlaku; tabel ini menyimpan semua versi berurutan,
 * masing-masing dengan UU sumber dan link naskah resminya. Hanya dipakai admin (tidak di-sync).
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement(<<<'SQL'
            CREATE TABLE pasal_versi (
                id UUID PRIMARY KEY,
                pasal_id UUID NOT NULL REFERENCES pasal(id) ON DELETE CASCADE,
                urutan SMALLINT NOT NULL,
                status VARCHAR(20) NOT NULL
                    CONSTRAINT pasal_versi_status_check
                    CHECK (status IN ('asli', 'diubah', 'disisipkan', 'dihapus')),
                sumber VARCHAR(100) NOT NULL,
                judul_sumber TEXT,
                diundangkan DATE,
                berlaku_sejak DATE,
                naskah_resmi TEXT,
                isi TEXT NOT NULL,
                penjelasan TEXT,
                created_at TIMESTAMPTZ,
                updated_at TIMESTAMPTZ,
                CONSTRAINT pasal_versi_pasal_urutan_unique UNIQUE (pasal_id, urutan)
            )
        SQL);
    }

    public function down(): void
    {
        DB::statement('DROP TABLE IF EXISTS pasal_versi');
    }
};
