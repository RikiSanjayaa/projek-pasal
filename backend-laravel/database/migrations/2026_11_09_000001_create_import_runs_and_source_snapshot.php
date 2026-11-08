<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Import on-demand dari datahukum (issue #29).
 *
 * - pasal.source_snapshot: isi pasal persis seperti terakhir diterapkan dari sumber (judul, isi,
 *   penjelasan, keywords, run_id, hash). Jadi pembanding "dasar" untuk perbandingan 3 arah:
 *   snapshot lama / data sekarang / sumber baru. Hanya import datahukum yang mengisinya.
 * - import_runs: satu pengecekan pembaruan (draft) per UU. Tidak mengubah data pasal sampai diterapkan.
 * - import_run_items: hasil perbandingan per pasal beserta pilihan admin.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE pasal ADD COLUMN source_snapshot JSONB');

        // Backfill: data staging sama dengan keluaran pipeline terakhir, jadi kondisi sekarang dianggap
        // sebagai snapshot sumber. Semua pasal yang belum dihapus ikut (bukan hanya KUHP/KUHAP) supaya
        // migrasi tidak perlu tahu daftar sumber; UU tanpa sumber import tidak akan pernah memakainya.
        // Trigger updated_at dimatikan sementara: ini bukan perubahan isi, dan tanpa itu semua pasal
        // akan terkirim ulang ke setiap perangkat mobile pada sync berikutnya.
        DB::statement('ALTER TABLE pasal DISABLE TRIGGER pasal_updated_at');
        try {
            DB::statement(<<<'SQL'
                UPDATE pasal
                SET source_snapshot = jsonb_build_object(
                    'judul', judul,
                    'isi', isi,
                    'penjelasan', penjelasan,
                    'keywords', to_jsonb(keywords),
                    'run_id', NULL,
                    'hash', NULL
                )
                WHERE deleted_at IS NULL
                  AND undang_undang_id IN (SELECT id FROM undang_undang WHERE deleted_at IS NULL)
            SQL);
        } finally {
            DB::statement('ALTER TABLE pasal ENABLE TRIGGER pasal_updated_at');
        }

        DB::statement(<<<'SQL'
            CREATE TABLE import_runs (
                id UUID PRIMARY KEY,
                slug VARCHAR(100) NOT NULL,
                undang_undang_id UUID REFERENCES undang_undang(id) ON DELETE SET NULL,
                status VARCHAR(20) NOT NULL DEFAULT 'queued'
                    CONSTRAINT import_runs_status_check
                    CHECK (status IN ('queued', 'running', 'ready', 'applied', 'failed', 'discarded', 'needs_config')),
                requested_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
                applied_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
                started_at TIMESTAMPTZ,
                finished_at TIMESTAMPTZ,
                applied_at TIMESTAMPTZ,
                error TEXT,
                source_url TEXT,
                html_sha256 VARCHAR(64),
                unknown_versions JSONB NOT NULL DEFAULT '[]',
                warnings JSONB NOT NULL DEFAULT '[]',
                summary JSONB NOT NULL DEFAULT '{}',
                created_at TIMESTAMPTZ,
                updated_at TIMESTAMPTZ
            )
        SQL);
        DB::statement('CREATE INDEX idx_import_runs_slug_created ON import_runs(slug, created_at DESC)');
        DB::statement('CREATE INDEX idx_import_runs_uu_status ON import_runs(undang_undang_id, status)');

        DB::statement(<<<'SQL'
            CREATE TABLE import_run_items (
                id UUID PRIMARY KEY,
                import_run_id UUID NOT NULL REFERENCES import_runs(id) ON DELETE CASCADE,
                pasal_id UUID REFERENCES pasal(id) ON DELETE SET NULL,
                nomor VARCHAR(100) NOT NULL,
                category VARCHAR(20) NOT NULL
                    CONSTRAINT import_run_items_category_check
                    CHECK (category IN ('baru', 'hilang', 'konflik', 'berubah', 'diedit_admin', 'riwayat')),
                selected BOOLEAN NOT NULL DEFAULT false,
                base JSONB,
                current JSONB,
                incoming JSONB,
                incoming_riwayat JSONB,
                current_riwayat JSONB,
                incoming_links JSONB,
                review JSONB,
                notes JSONB NOT NULL DEFAULT '[]',
                sort_key INTEGER NOT NULL DEFAULT 0,
                applied_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ,
                updated_at TIMESTAMPTZ,
                CONSTRAINT import_run_items_run_nomor_unique UNIQUE (import_run_id, nomor)
            )
        SQL);
        DB::statement('CREATE INDEX idx_import_run_items_run_category ON import_run_items(import_run_id, category, sort_key)');
    }

    public function down(): void
    {
        DB::statement('DROP TABLE IF EXISTS import_run_items');
        DB::statement('DROP TABLE IF EXISTS import_runs');
        DB::statement('ALTER TABLE pasal DROP COLUMN IF EXISTS source_snapshot');
    }
};
