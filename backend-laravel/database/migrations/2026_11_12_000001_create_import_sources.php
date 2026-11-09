<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('undang_undang', function (Blueprint $table) {
            $table->text('official_pdf_url')->nullable();
            $table->jsonb('official_document')->nullable();
        });
        Schema::create('import_sources', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('undang_undang_id')->unique()->constrained('undang_undang')->cascadeOnDelete();
            $table->string('slug')->unique();
            $table->string('parser')->default('datahukum');
            $table->text('url');
            $table->jsonb('config');
            $table->timestampsTz();
        });
        Schema::table('import_runs', function (Blueprint $table) {
            $table->jsonb('source_config')->nullable();
        });

        $configs = json_decode(file_get_contents(database_path('data/import_sources.json')), true, flags: JSON_THROW_ON_ERROR);
        foreach ($configs as $config) {
            $uu = DB::table('undang_undang')->whereRaw("replace(upper(kode), '_', '-') = ?", [strtoupper($config['kode'])])->first();
            if (! $uu) {
                $id = (string) Str::uuid();
                DB::table('undang_undang')->insert([
                    'id' => $id,
                    'kode' => $config['kode'] === 'UU-ITE' ? 'UU_ITE' : $config['kode'],
                    'nama' => $config['nama'], 'nama_lengkap' => $config['nama_lengkap'],
                    'tahun' => $config['tahun'], 'is_active' => false,
                    'official_url' => $config['bpk_detail_url'] ?: null,
                    'source_url' => $config['datahukum_url'],
                    'created_at' => now(), 'updated_at' => now(),
                ]);
                $uu = DB::table('undang_undang')->where('id', $id)->first();
            }
            DB::table('undang_undang')->where('id', $uu->id)->update([
                'source_url' => $config['datahukum_url'],
                'official_pdf_url' => $config['bpk_pdf_url'] ?: null,
            ]);
            DB::table('import_sources')->insert([
                'id' => (string) Str::uuid(), 'undang_undang_id' => $uu->id,
                'slug' => $config['slug'], 'parser' => 'datahukum',
                'url' => $config['datahukum_url'], 'config' => json_encode($config, JSON_THROW_ON_ERROR),
                'created_at' => now(), 'updated_at' => now(),
            ]);
            DB::table('import_runs')->where('slug', $config['slug'])->whereNull('source_config')->update([
                'source_config' => json_encode($config, JSON_THROW_ON_ERROR),
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('import_runs', fn (Blueprint $table) => $table->dropColumn('source_config'));
        Schema::dropIfExists('import_sources');
        Schema::table('undang_undang', fn (Blueprint $table) => $table->dropColumn(['official_pdf_url', 'official_document']));
    }
};
