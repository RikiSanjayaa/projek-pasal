<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Teks pasal kini bisa datang dari sumber tidak resmi (misalnya datahukum.com), jadi setiap pasal
 * punya status verifikasi oleh admin. Data yang sudah ada dianggap belum diverifikasi.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement(<<<'SQL'
            ALTER TABLE pasal
                ADD COLUMN verification_status VARCHAR(20) NOT NULL DEFAULT 'perlu_verifikasi'
                    CONSTRAINT pasal_verification_status_check
                    CHECK (verification_status IN ('perlu_verifikasi', 'terverifikasi')),
                ADD COLUMN verified_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
                ADD COLUMN verified_at TIMESTAMPTZ
        SQL);
        DB::statement('CREATE INDEX idx_pasal_verification_status ON pasal(verification_status)');

        DB::statement(<<<'SQL'
            ALTER TABLE undang_undang
                ADD COLUMN official_url TEXT,
                ADD COLUMN source_url TEXT
        SQL);
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS idx_pasal_verification_status');
        DB::statement('ALTER TABLE pasal DROP COLUMN IF EXISTS verified_at, DROP COLUMN IF EXISTS verified_by, DROP COLUMN IF EXISTS verification_status');
        DB::statement('ALTER TABLE undang_undang DROP COLUMN IF EXISTS source_url, DROP COLUMN IF EXISTS official_url');
    }
};
