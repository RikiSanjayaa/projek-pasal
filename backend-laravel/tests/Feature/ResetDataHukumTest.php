<?php

namespace Tests\Feature;

use App\Models\ImportSource;
use App\Models\Pasal;
use App\Models\PasalLink;
use App\Models\UndangUndang;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Tests\TestCase;

class ResetDataHukumTest extends TestCase
{
    use RefreshDatabase;

    private string $dir;

    protected function setUp(): void
    {
        parent::setUp();
        $this->dir = sys_get_temp_dir().'/caripasal-reset-'.bin2hex(random_bytes(4));
        foreach (ImportSource::pluck('slug') as $slug) {
            $this->workbook($slug, [['nomor' => '1', 'isi' => "Isi {$slug} pasal 1."], ['nomor' => '2', 'isi' => "Isi {$slug} pasal 2."]]);
        }
    }

    protected function tearDown(): void
    {
        File::deleteDirectory($this->dir);
        parent::tearDown();
    }

    /** @param list<array<string, string>> $rows */
    private function workbook(string $slug, array $rows, array $history = []): void
    {
        $book = new Spreadsheet;
        $book->getActiveSheet()->setTitle('import')->fromArray([array_keys($rows[0]), ...array_map('array_values', $rows)]);
        if ($history !== []) {
            $book->createSheet()->setTitle('riwayat')->fromArray([array_keys($history[0]), ...array_map('array_values', $history)]);
        }
        File::ensureDirectoryExists("{$this->dir}/{$slug}");
        (new Xlsx($book))->save("{$this->dir}/{$slug}/data.xlsx");
    }

    private function oldData(): array
    {
        // KUHP sudah dibuat migrasi import_sources (nonaktif); dipakai sebagai UU lama berisi data format lama.
        $kuhp = UndangUndang::where('kode', 'KUHP')->firstOrFail();
        $lama = UndangUndang::create(['kode' => 'UU_LAMA', 'nama' => 'UU tanpa sumber', 'tahun' => 2000, 'is_active' => true]);
        $a = Pasal::create(['undang_undang_id' => $kuhp->id, 'nomor' => 'Pasal 1', 'isi' => 'Format lama.']);
        $b = Pasal::create(['undang_undang_id' => $lama->id, 'nomor' => 'Pasal 9', 'isi' => 'Data berantakan.']);
        Pasal::create(['undang_undang_id' => $kuhp->id, 'nomor' => 'Pasal 2', 'isi' => 'Di sampah.'])->delete();
        PasalLink::create(['source_pasal_id' => $a->id, 'target_pasal_id' => $b->id, 'is_active' => true]);

        return [$kuhp, $lama];
    }

    public function test_replaces_all_pasal_with_data_import_files(): void
    {
        [$kuhp, $lama] = $this->oldData();
        $this->workbook('kuhp-2023', [
            ['nomor' => '1', 'isi' => 'Asas legalitas.', 'bab' => 'Bab I', 'link1_targetUU' => 'KUHP', 'link1_targetNomor' => '2'],
            ['nomor' => '2', 'isi' => 'Hukum yang hidup.', 'bab' => 'Bab I', 'link1_targetUU' => '', 'link1_targetNomor' => ''],
        ], [['nomor' => '1', 'urutan' => '1', 'status' => 'asli', 'sumber' => 'UU 1/2023', 'isi' => 'Asas legalitas.']]);

        $this->artisan('caripasal:reset-data-hukum', ['--dir' => $this->dir, '--force' => true])->assertSuccessful();

        $this->assertSame(0, Pasal::withTrashed()->where('nomor', 'like', 'Pasal %')->count());
        $this->assertSoftDeleted('undang_undang', ['id' => $lama->id]);
        $this->assertSame(['1', '2'], Pasal::where('undang_undang_id', $kuhp->id)->orderBy('nomor')->pluck('nomor')->all());
        $this->assertSame(1, PasalLink::count());
        $this->assertSame(1, Pasal::where('undang_undang_id', $kuhp->id)->where('nomor', '1')->firstOrFail()->versi()->count());
        $this->assertSame(8, Pasal::count());
        $this->assertSame(0, UndangUndang::whereIn('id', ImportSource::pluck('undang_undang_id'))->where('is_active', false)->count());
    }

    public function test_refuses_when_admins_already_verified_pasal(): void
    {
        [$kuhp] = $this->oldData();
        Pasal::where('nomor', 'Pasal 1')->update(Pasal::verifiedBy(null));

        $this->artisan('caripasal:reset-data-hukum', ['--dir' => $this->dir, '--force' => true])->assertFailed();

        $this->assertSame(3, Pasal::withTrashed()->count());
        $this->assertSame(1, Pasal::where('undang_undang_id', $kuhp->id)->count());
    }

    public function test_bad_file_rolls_back_everything(): void
    {
        [, $lama] = $this->oldData();
        $this->workbook('uu-ite-2008', [['nomor' => '1', 'isi' => '']]);

        $this->artisan('caripasal:reset-data-hukum', ['--dir' => $this->dir, '--force' => true])->assertFailed();

        $this->assertSame(3, Pasal::withTrashed()->count());
        $this->assertSame(1, PasalLink::count());
        $this->assertNotSoftDeleted('undang_undang', ['id' => $lama->id]);
    }
}
