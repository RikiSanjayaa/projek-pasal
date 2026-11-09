<?php

namespace App\Http\Controllers\Api;

use Carbon\CarbonImmutable;
use App\Http\Controllers\Controller;
use App\Jobs\RunDatahukumImport;
use App\Models\ImportRun;
use App\Models\UndangUndang;
use App\Models\ImportSource;
use App\Services\LawSourceService;
use App\Services\ImportSourceCatalog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Throwable;

/** Registrasi sumber dari form UU; pengambilan menghasilkan draf yang harus ditinjau. */
class ImportSourceController extends Controller
{
    public function index(ImportSourceCatalog $catalog): JsonResponse
    {
        $enabled = (bool) config('services.datahukum.enabled');

        try {
            $sources = $catalog->all();
        } catch (Throwable $e) {
            return response()->json(['enabled' => true, 'sources' => [], 'error' => 'Daftar sumber import tidak bisa dimuat: '.$e->getMessage()]);
        }

        $result = array_map(function (array $source) {
            $latest = fn () => ImportRun::where('slug', $source['slug'])->orderByDesc('created_at');

            return [
                ...$source,
                'last_run' => $latest()->first()?->toApi(),
                'active_run' => $latest()->whereIn('status', ImportRun::ACTIVE_STATUSES)->first()?->toApi(),
            ];
        }, $sources);

        return response()->json(['enabled' => $enabled, 'sources' => $result]);
    }

    public function startRun(Request $request, ImportSourceCatalog $catalog, string $slug): JsonResponse
    {
        if (! config('services.datahukum.enabled')) {
            return response()->json(['message' => 'Import dari datahukum belum diaktifkan di server ini.'], 403);
        }

        try {
            $source = $catalog->find($slug);
        } catch (Throwable $e) {
            return response()->json(['message' => 'Daftar sumber import tidak bisa dimuat: '.$e->getMessage()], 503);
        }
        if (! $source) {
            return response()->json(['message' => 'Sumber import tidak dikenal.'], 404);
        }

        if ($source['status'] !== 'ready') {
            return response()->json(['message' => $source['status_message'] ?? 'Konfigurasi sumber belum siap.'], 422);
        }
        $uu = UndangUndang::findOrFail($source['undang_undang_id']);

        // Kunci singkat supaya dua klik bersamaan tidak membuat dua run.
        $lock = Cache::lock('import-run:'.$slug, 15);
        if (! $lock->get()) {
            return response()->json(['message' => 'Pengecekan untuk sumber ini sedang dimulai. Muat ulang halaman.'], 409);
        }

        try {
            $active = ImportRun::where('slug', $slug)->whereIn('status', ImportRun::ACTIVE_STATUSES)->latest('created_at')->first();
            if ($active) {
                $message = $active->status === ImportRun::READY
                    ? 'Masih ada hasil pengecekan yang belum diterapkan. Terapkan atau buang dulu sebelum memeriksa lagi.'
                    : 'Pengecekan untuk sumber ini sedang berjalan.';

                return response()->json(['message' => $message, 'run_id' => $active->id], 409);
            }

            $minutes = (int) config('services.datahukum.min_interval_minutes');
            $last = ImportRun::where('slug', $slug)->orderByDesc('created_at')->first();
            $lastAt = $last ? ($last->started_at ?? $last->created_at) : null;
            if ($lastAt && ($retryAt = CarbonImmutable::instance($lastAt)->addMinutes($minutes))->isFuture()) {
                return response()->json([
                    'message' => "Pengecekan terakhir baru dijalankan. Coba lagi setelah pukul {$retryAt->timezone(config('app.timezone'))->format('H:i')}.",
                    'retry_at' => $retryAt->toISOString(),
                ], 409);
            }

            $run = DB::transaction(function () use ($uu, $slug, $request) {
                UndangUndang::lockForUpdate()->findOrFail($uu->id);
                $registration = ImportSource::with('undangUndang')->where('slug', $slug)->lockForUpdate()->firstOrFail();
                $policy = app(LawSourceService::class);
                $state = $policy->status($registration);
                abort_unless($state['status'] === 'ready', 422, $state['status_message']);
                return ImportRun::create([
                    'slug' => $slug, 'undang_undang_id' => $uu->id,
                    'status' => ImportRun::QUEUED, 'requested_by' => $request->user()?->id,
                    'source_url' => $registration->url,
                    'source_config' => $policy->snapshot($registration),
                ]);
            });
            RunDatahukumImport::dispatch($run->id);
        } finally {
            $lock->release();
        }

        return response()->json($run->toApi(), 202);
    }
}
