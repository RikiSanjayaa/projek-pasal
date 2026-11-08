<?php

namespace Tests\Feature;

use App\Models\Pasal;
use App\Models\UndangUndang;
use App\Services\ImportPasalService;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

/**
 * Skema produksi memakai fitur khusus Postgres, jadi tabel yang dipakai import dibuat ulang di sqlite memori.
 */
class ImportPasalCatatanTest extends TestCase
{
    private UndangUndang $uu;

    protected function setUp(): void
    {
        parent::setUp();

        Schema::create('undang_undang', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('kode')->unique();
            $table->string('nama');
            $table->text('nama_lengkap')->nullable();
            $table->text('deskripsi')->nullable();
            $table->integer('tahun')->nullable();
            $table->boolean('is_active')->default(true);
            $table->text('official_url')->nullable();
            $table->text('source_url')->nullable();
            $table->text('catatan_teks')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('pasal', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('undang_undang_id');
            $table->string('nomor');
            $table->string('judul')->nullable();
            $table->text('isi');
            $table->text('penjelasan')->nullable();
            $table->text('catatan')->nullable();
            $table->text('keywords')->nullable();
            $table->boolean('is_active')->default(true);
            $table->string('verification_status')->default('perlu_verifikasi');
            $table->uuid('verified_by')->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->text('source_snapshot')->nullable();
            $table->uuid('created_by')->nullable();
            $table->uuid('updated_by')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });

        $this->uu = UndangUndang::create(['kode' => 'KUHPER', 'nama' => 'KUHPerdata']);
    }

    private function row(array $extra = []): array
    {
        return $extra + ['kode_uu' => 'KUHPER', 'nomor' => '5a', 'isi' => 'Isi pasal.'];
    }

    private function pasal(): Pasal
    {
        return Pasal::where('nomor', '5a')->firstOrFail();
    }

    private function verify(): void
    {
        $this->pasal()->update(Pasal::verifiedBy(null));
    }

    public function test_new_pasal_stores_catatan_and_needs_verification(): void
    {
        $result = (new ImportPasalService)->importRows([$this->row(['catatan' => "  Bab ini tidak berlaku lagi.\r\nLihat UU 1/1974.  "])]);

        $this->assertSame(1, $result['created']);
        $this->assertSame("Bab ini tidak berlaku lagi.\nLihat UU 1/1974.", $this->pasal()->catatan);
        $this->assertSame(Pasal::UNVERIFIED, $this->pasal()->verification_status);
    }

    public function test_absent_catatan_key_keeps_existing_value(): void
    {
        $service = new ImportPasalService;
        $service->importRows([$this->row(['catatan' => 'Catatan lama.'])]);
        $this->verify();

        $result = $service->importRows([$this->row()]);

        $this->assertSame(1, $result['updated']);
        $this->assertSame('Catatan lama.', $this->pasal()->catatan);
        $this->assertSame(Pasal::VERIFIED, $this->pasal()->verification_status);
    }

    public function test_present_catatan_replaces_value_without_resetting_verification(): void
    {
        $service = new ImportPasalService;
        $service->importRows([$this->row(['catatan' => 'Catatan lama.'])]);
        $this->verify();

        $result = $service->importRows([$this->row(['catatan' => 'Catatan baru.'])]);

        $this->assertSame(0, $result['needs_verification']);
        $this->assertSame('Catatan baru.', $this->pasal()->catatan);
        $this->assertSame(Pasal::VERIFIED, $this->pasal()->verification_status);
    }

    public function test_empty_or_null_catatan_clears_value_without_resetting_verification(): void
    {
        $service = new ImportPasalService;
        foreach (['', '   ', null] as $empty) {
            $service->importRows([$this->row(['catatan' => 'Ada catatan.'])]);
            $this->verify();

            $result = $service->importRows([$this->row(['catatan' => $empty])]);

            $this->assertSame(0, $result['needs_verification']);
            $this->assertNull($this->pasal()->catatan);
            $this->assertSame(Pasal::VERIFIED, $this->pasal()->verification_status);
        }
    }

    public function test_text_change_still_resets_verification_alongside_catatan(): void
    {
        $service = new ImportPasalService;
        $service->importRows([$this->row(['catatan' => 'Catatan.'])]);
        $this->verify();

        $result = $service->importRows([$this->row(['isi' => 'Isi pasal diubah.', 'catatan' => 'Catatan.'])]);

        $this->assertSame(1, $result['needs_verification']);
        $this->assertSame(Pasal::UNVERIFIED, $this->pasal()->verification_status);
    }

    public function test_nomor_with_lowercase_suffix_orders_naturally(): void
    {
        foreach (['1153', '5b', '1152bis', '5a', '1152a', '1152', '10', '5'] as $nomor) {
            Pasal::create(['undang_undang_id' => $this->uu->id, 'nomor' => $nomor, 'isi' => 'x']);
        }

        $this->assertSame(
            ['5', '5a', '5b', '10', '1152', '1152a', '1152bis', '1153'],
            Pasal::query()->orderByNomor()->pluck('nomor')->all(),
        );
        $this->assertSame(
            ['1153', '1152bis', '1152a', '1152', '10', '5b', '5a', '5'],
            Pasal::query()->orderByNomor('desc')->pluck('nomor')->all(),
        );
    }
}
