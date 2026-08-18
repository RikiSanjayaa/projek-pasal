<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement(<<<'SQL'
            CREATE TABLE search_aliases (
                id UUID PRIMARY KEY,
                term VARCHAR(120) NOT NULL,
                aliases JSONB NOT NULL DEFAULT '[]'::jsonb,
                category VARCHAR(120),
                notes TEXT,
                is_active BOOLEAN NOT NULL DEFAULT true,
                created_by UUID REFERENCES admin_users(id),
                updated_by UUID REFERENCES admin_users(id),
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            )
        SQL);

        DB::statement('CREATE UNIQUE INDEX unique_search_alias_term ON search_aliases (lower(term))');
        DB::statement('CREATE INDEX idx_search_aliases_active ON search_aliases(is_active)');
        DB::statement('CREATE INDEX idx_search_aliases_aliases ON search_aliases USING GIN(aliases)');
        DB::statement('CREATE TRIGGER search_aliases_updated_at BEFORE UPDATE ON search_aliases FOR EACH ROW EXECUTE FUNCTION caripasal_update_updated_at()');

        $defaults = [
            ['maling', ['pencurian', 'mencuri', 'mengambil barang'], 'Pidana umum'],
            ['curi', ['pencurian', 'mencuri', 'mengambil barang'], 'Pidana umum'],
            ['nyuri', ['pencurian', 'mencuri', 'mengambil barang'], 'Pidana umum'],
            ['barang curian', ['penadahan', 'hasil kejahatan'], 'Pidana umum'],
            ['penadah', ['penadahan', 'hasil kejahatan'], 'Pidana umum'],
            ['tipu', ['penipuan', 'tipu muslihat', 'perbuatan curang'], 'Pidana umum'],
            ['bohong', ['penipuan', 'keterangan palsu', 'berita bohong'], 'Pidana umum'],
            ['ancam', ['pengancaman', 'ancaman kekerasan'], 'Pidana umum'],
            ['aniaya', ['penganiayaan', 'kekerasan'], 'Pidana umum'],
            ['bunuh', ['pembunuhan', 'menghilangkan nyawa'], 'Pidana umum'],
            ['narkoba', ['narkotika', 'psikotropika'], 'Narkotika'],
            ['sabu', ['narkotika', 'psikotropika'], 'Narkotika'],
            ['ganja', ['narkotika'], 'Narkotika'],
            ['judi', ['perjudian'], 'Pidana umum'],
            ['judi online', ['perjudian', 'transaksi elektronik'], 'Digital'],
            ['korupsi', ['tindak pidana korupsi', 'merugikan keuangan negara'], 'Korupsi'],
            ['suap', ['gratifikasi', 'korupsi'], 'Korupsi'],
            ['fitnah', ['pencemaran nama baik', 'penghinaan'], 'Pidana umum'],
            ['hoax', ['berita bohong', 'kabar bohong'], 'Digital'],
            ['palsu', ['pemalsuan', 'surat palsu', 'keterangan palsu'], 'Pidana umum'],
            ['gelap', ['penggelapan'], 'Pidana umum'],
            ['rampas', ['perampasan', 'kekerasan'], 'Pidana umum'],
            ['paksa', ['pemaksaan', 'kekerasan'], 'Pidana umum'],
            ['rusak', ['perusakan', 'merusak'], 'Pidana umum'],
        ];

        foreach ($defaults as [$term, $aliases, $category]) {
            DB::table('search_aliases')->insert([
                'id' => (string) Str::uuid(),
                'term' => $term,
                'aliases' => json_encode($aliases, JSON_UNESCAPED_UNICODE),
                'category' => $category,
                'notes' => 'Alias bawaan untuk pencarian bahasa sehari-hari.',
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::statement('DROP TABLE IF EXISTS search_aliases CASCADE');
    }
};
