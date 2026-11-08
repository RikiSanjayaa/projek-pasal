<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Catatan status teks per undang-undang (tampil di setiap pasalnya, misalnya terjemahan tidak resmi)
 * dan catatan editorial per pasal (bukan bagian dari teks hukum).
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE undang_undang ADD COLUMN catatan_teks TEXT');
        DB::statement('ALTER TABLE pasal ADD COLUMN catatan TEXT');
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE pasal DROP COLUMN IF EXISTS catatan');
        DB::statement('ALTER TABLE undang_undang DROP COLUMN IF EXISTS catatan_teks');
    }
};
