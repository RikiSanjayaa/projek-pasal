<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ImportRun;
use App\Models\ImportRunItem;
use App\Services\AuditService;
use App\Services\ImportApplyService;
use App\Services\ImportDiffService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use RuntimeException;

/** Draft hasil pengecekan pembaruan: lihat item per kategori, pilih, terapkan, atau buang. */
class ImportRunController extends Controller
{
    public function show(string $id): JsonResponse
    {
        return response()->json(ImportRun::findOrFail($id)->toApi());
    }

    public function items(Request $request, string $id): JsonResponse
    {
        $run = ImportRun::findOrFail($id);
        $request->validate([
            'category' => ['nullable', Rule::in(ImportDiffService::CATEGORIES)],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:200'],
        ]);

        $query = $run->items();
        if ($request->filled('category')) {
            $query->where('category', $request->query('category'));
        }

        $page = $query->paginate((int) $request->query('per_page', 50));
        $page->through(fn (ImportRunItem $item) => $item->toApi());

        return response()->json($page);
    }

    public function updateItems(Request $request, string $id): JsonResponse
    {
        $run = ImportRun::findOrFail($id);
        $data = $request->validate([
            'ids' => ['required_without:category', 'array', 'max:2000'],
            'ids.*' => ['uuid'],
            'category' => ['required_without:ids', Rule::in(ImportDiffService::SELECTABLE)],
            'selected' => ['required', 'boolean'],
        ]);

        if ($run->status !== ImportRun::READY) {
            return response()->json(['message' => 'Pilihan hanya bisa diubah selama run berstatus siap ditinjau.'], 409);
        }

        // diedit_admin hanya informasi, tidak pernah bisa dipilih.
        $query = ImportRunItem::where('import_run_id', $run->id)->whereIn('category', ImportDiffService::SELECTABLE);
        isset($data['ids']) ? $query->whereIn('id', $data['ids']) : $query->where('category', $data['category']);
        $updated = $query->update(['selected' => $data['selected']]);

        $summary = $run->summary ?? [];
        $summary['selected'] = ImportRunItem::where('import_run_id', $run->id)->where('selected', true)->count();
        $run->update(['summary' => $summary]);

        return response()->json(['updated' => $updated]);
    }

    public function apply(Request $request, string $id, ImportApplyService $service): JsonResponse
    {
        $run = ImportRun::findOrFail($id);
        $data = $request->validate(['confirm_large' => ['sometimes', 'boolean']]);

        if ($run->status !== ImportRun::READY) {
            return response()->json(['message' => 'Run ini tidak bisa diterapkan (status: '.$run->status.').'], 409);
        }
        if (! empty($run->summary['large_change']) && empty($data['confirm_large'])) {
            throw ValidationException::withMessages([
                'confirm_large' => 'Perubahan ini mencakup lebih dari 30% pasal. Konfirmasi secara eksplisit untuk melanjutkan.',
            ]);
        }

        try {
            $applied = $service->apply($run, $request);
        } catch (RuntimeException $e) {
            throw ValidationException::withMessages(['run' => $e->getMessage()]);
        }

        return response()->json($applied->toApi());
    }

    public function discard(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $run = ImportRun::findOrFail($id);
        if (! in_array($run->status, [ImportRun::QUEUED, ImportRun::READY], true)) {
            return response()->json(['message' => 'Run ini tidak bisa dibuang (status: '.$run->status.').'], 409);
        }

        $run->update(['status' => ImportRun::DISCARDED, 'finished_at' => $run->finished_at ?? now()]);
        $audit->log($request, 'UPDATE', 'import_runs', $run->id, null, null, ['run_id' => $run->id, 'aksi' => 'dibuang']);

        return response()->json($run->toApi());
    }
}
