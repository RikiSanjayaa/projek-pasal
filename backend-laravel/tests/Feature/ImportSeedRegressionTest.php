<?php

namespace Tests\Feature;

use App\Models\Pasal;
use App\Models\UndangUndang;
use App\Services\ImportPasalService;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ImportSeedRegressionTest extends TestCase
{
    use RefreshDatabase;

    public function test_links_targeting_hyphenated_kode_resolve_to_underscored_uu(): void
    {
        $uu = UndangUndang::where('kode', 'UU_ITE')->firstOrFail();

        $result = app(ImportPasalService::class)->importRows([
            ['undang_undang_id' => $uu->id, 'nomor' => '1', 'isi' => 'Ketentuan umum.'],
            [
                'undang_undang_id' => $uu->id,
                'nomor' => '45',
                'isi' => 'Sebagaimana dimaksud dalam Pasal 1.',
                'links' => [['targetUU' => 'UU-ITE', 'targetNomor' => '1']],
            ],
        ]);

        $this->assertSame(1, $result['links']['created']);
        $this->assertSame([], $result['links']['errors']);
    }

    public function test_reseeding_after_demo_pasal_deleted_neither_fails_nor_recreates_them(): void
    {
        $this->seed(DatabaseSeeder::class);
        Pasal::where('nomor', 'Pasal 1')->firstOrFail()->delete();
        Pasal::where('nomor', 'Pasal 2')->firstOrFail()->forceDelete();

        $this->seed(DatabaseSeeder::class);

        $this->assertSoftDeleted('pasal', ['nomor' => 'Pasal 1']);
        $this->assertDatabaseMissing('pasal', ['nomor' => 'Pasal 2']);
    }
}
