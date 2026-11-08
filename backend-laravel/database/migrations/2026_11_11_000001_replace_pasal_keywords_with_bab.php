<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Konsep keywords dihapus. Gantinya kolom struktural `bab` (teks, boleh kosong), mis.
 * "Buku Kedua · Bab XXI · Tentang Hipotek". Diisi oleh pipeline import datahukum.
 * Trigger search_vector memakai bab dengan bobot 'B' (sama seperti keywords dulu).
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('DROP INDEX IF EXISTS idx_pasal_keywords');
        DB::statement('ALTER TABLE pasal DROP COLUMN keywords');
        DB::statement('ALTER TABLE pasal ADD COLUMN bab TEXT NULL');

        DB::statement(<<<'SQL'
            CREATE OR REPLACE FUNCTION caripasal_update_pasal_search_vector()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.search_vector =
                    setweight(to_tsvector('simple', coalesce(NEW.nomor, '')), 'A') ||
                    setweight(to_tsvector('simple', coalesce(NEW.judul, '')), 'B') ||
                    setweight(to_tsvector('simple', coalesce(NEW.bab, '')), 'B') ||
                    setweight(to_tsvector('simple', coalesce(NEW.isi, '')), 'C') ||
                    setweight(to_tsvector('simple', coalesce(NEW.penjelasan, '')), 'D');
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        SQL);

        // Pemicu BEFORE UPDATE menghitung ulang search_vector untuk semua baris.
        DB::statement('UPDATE pasal SET search_vector = NULL');
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE pasal DROP COLUMN bab');
        DB::statement("ALTER TABLE pasal ADD COLUMN keywords TEXT[] NOT NULL DEFAULT '{}'");
        DB::statement('CREATE INDEX idx_pasal_keywords ON pasal USING GIN(keywords)');

        DB::statement(<<<'SQL'
            CREATE OR REPLACE FUNCTION caripasal_update_pasal_search_vector()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.search_vector =
                    setweight(to_tsvector('simple', coalesce(NEW.nomor, '')), 'A') ||
                    setweight(to_tsvector('simple', coalesce(NEW.judul, '')), 'B') ||
                    setweight(to_tsvector('simple', coalesce(array_to_string(NEW.keywords, ' '), '')), 'B') ||
                    setweight(to_tsvector('simple', coalesce(NEW.isi, '')), 'C') ||
                    setweight(to_tsvector('simple', coalesce(NEW.penjelasan, '')), 'D');
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        SQL);

        DB::statement('UPDATE pasal SET search_vector = NULL');
    }
};
