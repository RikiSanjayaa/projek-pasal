<?php

namespace Tests\Feature;

use App\Jobs\RunDatahukumImport;
use App\Models\AdminUser;
use App\Models\ImportRun;
use App\Models\ImportSource;
use App\Models\UndangUndang;
use App\Services\ImportRunProcessor;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class LawSourceTest extends TestCase
{
    use RefreshDatabase;

    private function headers(): array
    {
        $user = AdminUser::create(['email' => 'sources@example.test', 'nama' => 'Editor', 'password' => bin2hex(random_bytes(20)), 'role' => 'admin', 'is_active' => true]);
        return ['Accept' => 'application/json', 'Authorization' => 'Bearer '.$user->createToken('admin-dashboard', ['admin'])->plainTextToken];
    }

    private function law(array $extra = []): array
    {
        return $extra + ['kode' => 'UU-BARU', 'nama' => 'UU Baru', 'tahun' => 2024, 'source_url' => 'https://www.datahukum.com/peraturan/UU_12_Tahun_2024.html'];
    }

    public function test_save_registers_source_without_fetch_or_import_even_when_fetch_disabled(): void
    {
        config(['services.datahukum.enabled' => false]);
        Queue::fake();
        $headers = $this->headers();
        $saved = $this->postJson('/api/admin/undang-undang', $this->law(), $headers)->assertCreated();
        $saved->assertJsonPath('import_source.status', 'ready')->assertJsonPath('import_source.config.doc_class', 'uu-122024');
        $id = $saved->json('id');
        $catalog = $this->getJson('/api/admin/import-sources', $headers)->assertOk()->assertJsonPath('enabled', false);
        $entry = collect($catalog->json('sources'))->firstWhere('undang_undang_id', $id);
        $this->assertSame($saved->json('import_source.slug'), $entry['slug']);
        $this->assertDatabaseMissing('pasal', ['undang_undang_id' => $id]);
        $this->assertDatabaseCount('import_runs', 0);
        Queue::assertNothingPushed();
    }

    public function test_edit_keeps_source_identity_and_removing_url_unregisters_without_deleting_runs(): void
    {
        $headers = $this->headers();
        $saved = $this->postJson('/api/admin/undang-undang', $this->law(), $headers)->assertCreated();
        $id = $saved->json('id');
        $slug = $saved->json('import_source.slug');
        $run = ImportRun::create(['slug' => $slug, 'undang_undang_id' => $id, 'status' => 'discarded']);
        $this->putJson('/api/admin/undang-undang/'.$id, ['kode' => 'RENAMED', 'nama' => 'Renamed'], $headers)
            ->assertOk()->assertJsonPath('import_source.slug', $slug);
        $catalog = $this->getJson('/api/admin/import-sources', $headers)->assertOk();
        $this->assertSame('RENAMED', collect($catalog->json('sources'))->firstWhere('slug', $slug)['kode']);
        $this->putJson('/api/admin/undang-undang/'.$id, ['source_url' => null], $headers)->assertOk()->assertJsonPath('import_source', null);
        $this->assertDatabaseHas('import_runs', ['id' => $run->id]);
        $catalog = $this->getJson('/api/admin/import-sources', $headers)->assertOk();
        $this->assertNull(collect($catalog->json('sources'))->firstWhere('slug', $slug));
    }

    public function test_replacing_source_url_does_not_reuse_inherited_document_class(): void
    {
        $headers = $this->headers();
        $saved = $this->postJson('/api/admin/undang-undang', $this->law(), $headers)->assertCreated();
        $this->putJson('/api/admin/undang-undang/'.$saved->json('id'), [
            'source_url' => 'https://www.datahukum.com/peraturan/UU_13_Tahun_2024.html',
            'import_config' => $saved->json('import_source.config'),
        ], $headers)->assertOk()->assertJsonPath('import_source.config.doc_class', 'uu-132024');
    }

    public function test_restoring_source_keeps_pending_draft_visible_and_prevents_another_run(): void
    {
        config(['services.datahukum.enabled' => true, 'services.datahukum.min_interval_minutes' => 0]);
        Queue::fake();
        $headers = $this->headers();
        $saved = $this->postJson('/api/admin/undang-undang', $this->law(), $headers)->assertCreated();
        $id = $saved->json('id');
        $slug = $saved->json('import_source.slug');
        $run = ImportRun::create(['slug' => $slug, 'undang_undang_id' => $id, 'status' => ImportRun::READY]);
        $this->putJson('/api/admin/undang-undang/'.$id, ['source_url' => null], $headers)->assertOk();
        $restored = $this->putJson('/api/admin/undang-undang/'.$id, ['source_url' => $this->law()['source_url']], $headers)
            ->assertOk()->assertJsonPath('import_source.slug', $slug);
        $catalog = $this->getJson('/api/admin/import-sources', $headers)->assertOk();
        $entry = collect($catalog->json('sources'))->firstWhere('undang_undang_id', $id);
        $this->assertSame($run->id, $entry['active_run']['id']);
        $this->postJson('/api/admin/import-sources/'.$restored->json('import_source.slug').'/runs', [], $headers)
            ->assertConflict()->assertJsonPath('run_id', $run->id);
        Queue::assertNothingPushed();
    }

    public function test_seeded_kuhap_source_keeps_2025_identity_after_unrelated_edit(): void
    {
        $this->seed(\Database\Seeders\DatabaseSeeder::class);
        $headers = $this->headers();
        $uu = UndangUndang::where('kode', 'KUHAP')->firstOrFail();
        $this->putJson('/api/admin/undang-undang/'.$uu->id, ['deskripsi' => 'Diperbarui'], $headers)
            ->assertOk()->assertJsonPath('tahun', 2025);
        $config = ImportSource::where('undang_undang_id', $uu->id)->firstOrFail()->config;
        $this->assertSame(2025, $config['tahun']);
        $this->assertSame('Undang-Undang Nomor 20 Tahun 2025 tentang Kitab Undang-Undang Hukum Acara Pidana', $config['nama_lengkap']);
    }

    public function test_unsupported_and_incomplete_sources_are_visible_but_cannot_start(): void
    {
        config(['services.datahukum.enabled' => true]);
        Queue::fake();
        $headers = $this->headers();
        foreach ([['source_url' => 'https://example.test/law', 'expected' => 'unsupported'], ['tahun' => null, 'expected' => 'incomplete']] as $case) {
            $expected = $case['expected'];
            unset($case['expected']);
            $saved = $this->postJson('/api/admin/undang-undang', $this->law($case + ['kode' => $expected]), $headers)->assertCreated();
            $saved->assertJsonPath('import_source.status', $expected);
            $this->postJson('/api/admin/import-sources/'.$saved->json('import_source.slug').'/runs', [], $headers)->assertStatus(422);
        }
        Queue::assertNothingPushed();
    }

    public function test_document_download_is_private_and_queued_snapshot_survives_edits_and_replacement(): void
    {
        Storage::fake('local');
        config(['services.datahukum.enabled' => true, 'services.datahukum.min_interval_minutes' => 0]);
        Queue::fake();
        $headers = $this->headers();
        $file = UploadedFile::fake()->createWithContent('original.pdf', "%PDF-1.4\noriginal legal document\n%%EOF");
        $saved = $this->post('/api/admin/undang-undang', $this->law() + ['official_document' => $file], $headers)->assertCreated();
        $id = $saved->json('id');
        $document = $saved->json('official_document');
        $this->assertSame(hash('sha256', file_get_contents($file->getRealPath())), $document['sha256']);
        $this->app['auth']->forgetGuards();
        $this->get('/api'.$document['download_url'], ['Accept' => 'application/json'])->assertUnauthorized();
        $this->app['auth']->forgetGuards();
        $this->get('/api'.$document['download_url'], $headers)->assertOk()->assertDownload('original.pdf');
        $started = $this->postJson('/api/admin/import-sources/'.$saved->json('import_source.slug').'/runs', [], $headers)->assertAccepted();
        $run = ImportRun::findOrFail($started->json('id'));
        $snapshot = $run->source_config;
        $oldPath = $snapshot['official_pdf_path'];
        $this->assertFileExists($oldPath);
        $this->post('/api/admin/undang-undang/'.$id, ['_method' => 'PUT', 'source_url' => 'https://www.datahukum.com/peraturan/UU_13_Tahun_2024.html', 'official_document' => UploadedFile::fake()->createWithContent('new.pdf', "%PDF-1.4\nreplacement\n%%EOF")], $headers)->assertOk();
        $this->assertSame($snapshot, $run->fresh()->source_config);
        $this->assertFileExists($oldPath);
        $this->assertNotSame($oldPath, app(\App\Services\LawSourceService::class)->snapshot(ImportSource::where('undang_undang_id', $id)->first())['official_pdf_path']);
    }

    public function test_execution_respects_disabled_fetch_even_for_previously_queued_run(): void
    {
        config(['services.datahukum.enabled' => false]);
        $uu = UndangUndang::firstOrFail();
        $run = ImportRun::create(['slug' => 'queued-before-disable', 'undang_undang_id' => $uu->id, 'status' => 'queued', 'source_config' => ['slug' => 'queued-before-disable']]);
        app(ImportRunProcessor::class)->process($run);
        $this->assertSame('failed', $run->fresh()->status);
        $this->assertStringContainsString('dinonaktifkan', $run->fresh()->error);
        $this->assertDatabaseMissing('import_run_items', ['import_run_id' => $run->id]);
    }

    public function test_rejects_executable_configuration_pdf_destination_and_invalid_document(): void
    {
        $headers = $this->headers();
        $this->postJson('/api/admin/undang-undang', $this->law(['import_config' => ['derive' => 'arbitrary code']]), $headers)->assertUnprocessable()->assertJsonValidationErrors('import_config');
        $this->postJson('/api/admin/undang-undang', $this->law(['official_pdf_url' => 'https://127.0.0.1/private.pdf']), $headers)->assertUnprocessable()->assertJsonValidationErrors('official_pdf_url');
        $this->post('/api/admin/undang-undang', $this->law(['official_document' => UploadedFile::fake()->createWithContent('bad.pdf', 'not a PDF')]), $headers)->assertUnprocessable()->assertJsonValidationErrors('official_document');
    }
}
