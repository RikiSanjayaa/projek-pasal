<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
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

    public function down(): void
    {
        DB::statement(<<<'SQL'
            CREATE OR REPLACE FUNCTION caripasal_update_pasal_search_vector()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.search_vector =
                    setweight(to_tsvector('simple', coalesce(NEW.nomor, '')), 'A') ||
                    setweight(to_tsvector('simple', coalesce(NEW.judul, '')), 'B') ||
                    setweight(to_tsvector('simple', coalesce(NEW.isi, '')), 'C') ||
                    setweight(to_tsvector('simple', coalesce(NEW.penjelasan, '')), 'D');
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        SQL);

        DB::statement('UPDATE pasal SET search_vector = NULL');
    }
};
