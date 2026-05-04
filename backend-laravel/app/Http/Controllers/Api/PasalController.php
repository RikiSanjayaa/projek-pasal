<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Pasal;
use App\Models\PasalLink;
use App\Services\AuditService;
use App\Services\ImportPasalService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PasalController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Pasal::query()->with('undangUndang');
        if ($request->boolean('with_trashed') || $request->boolean('trash')) {
            $query->withTrashed();
        }
        if ($request->boolean('trash')) {
            $query->onlyTrashed();
        }
        if ($request->filled('undang_undang_id')) {
            $query->where('undang_undang_id', $request->query('undang_undang_id'));
        }
        if ($request->has('is_active')) {
            $query->where('is_active', filter_var($request->query('is_active'), FILTER_VALIDATE_BOOLEAN));
        }
        if ($search = $request->query('search')) {
            $query->where(fn ($q) => $q
                ->where('nomor', 'ilike', "%{$search}%")
                ->orWhere('judul', 'ilike', "%{$search}%")
                ->orWhere('isi', 'ilike', "%{$search}%"));
        }
        $keywords = $request->query('keywords', []);
        if (is_string($keywords)) {
            $keywords = array_filter(explode(',', $keywords));
        }
        if (is_array($keywords) && count($keywords) > 0) {
            $query->where(function ($q) use ($keywords) {
                foreach ($keywords as $keyword) {
                    $q->orWhereRaw('? = ANY(keywords)', [$keyword]);
                }
            });
        }

        $sort = $request->boolean('trash') ? 'deleted_at' : 'nomor';
        $direction = $request->boolean('trash') ? 'desc' : 'asc';

        return response()->json($query->orderBy($sort, $direction)->paginate((int) $request->query('per_page', 20)));
    }

    public function store(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $this->validated($request);
        $payload['created_by'] = $request->user()?->id;
        $payload['updated_by'] = $request->user()?->id;
        $pasal = Pasal::create($payload);
        $audit->log($request, 'CREATE', 'pasal', $pasal->id, null, $pasal);

        return response()->json($pasal->load('undangUndang'), 201);
    }

    public function show(string $id): JsonResponse
    {
        return response()->json(Pasal::withTrashed()->with('undangUndang')->findOrFail($id));
    }

    public function update(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $pasal = Pasal::withTrashed()->findOrFail($id);
        $old = $pasal->replicate();
        $payload = $this->validated($request, true, $pasal);
        $payload['updated_by'] = $request->user()?->id;
        $pasal->update($payload);
        $audit->log($request, 'UPDATE', 'pasal', $pasal->id, $old, $pasal);

        return response()->json($pasal->load('undangUndang'));
    }

    public function destroy(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $pasal = Pasal::findOrFail($id);
        $old = $pasal->replicate();
        $pasal->update(['is_active' => false, 'updated_by' => $request->user()?->id]);
        $pasal->delete();
        $audit->log($request, 'DELETE', 'pasal', $pasal->id, $old, $pasal);

        return response()->json(['message' => 'Pasal dihapus.']);
    }

    public function restore(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $pasal = Pasal::withTrashed()->findOrFail($id);
        $pasal->restore();
        $pasal->update(['is_active' => true, 'updated_by' => $request->user()?->id]);
        $audit->log($request, 'RESTORE', 'pasal', $pasal->id, null, $pasal);

        return response()->json($pasal);
    }

    public function bulkDelete(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $request->validate(['ids' => ['required', 'array'], 'ids.*' => ['uuid']]);
        $deleted = 0;

        foreach ($payload['ids'] as $id) {
            $pasal = Pasal::find($id);
            if (! $pasal) {
                continue;
            }
            $old = $pasal->replicate();
            $pasal->update(['is_active' => false, 'updated_by' => $request->user()?->id]);
            $pasal->delete();
            $audit->log($request, 'DELETE', 'pasal', $pasal->id, $old, $pasal);
            $deleted++;
        }

        return response()->json(['deleted' => $deleted]);
    }

    public function bulkRestore(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $request->validate(['ids' => ['required', 'array'], 'ids.*' => ['uuid']]);
        $restored = 0;

        foreach ($payload['ids'] as $id) {
            $pasal = Pasal::withTrashed()->find($id);
            if (! $pasal) {
                continue;
            }
            $pasal->restore();
            $pasal->update(['is_active' => true, 'updated_by' => $request->user()?->id]);
            $audit->log($request, 'RESTORE', 'pasal', $pasal->id, null, $pasal);
            $restored++;
        }

        return response()->json(['restored' => $restored]);
    }

    public function forceDelete(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $pasal = Pasal::withTrashed()->findOrFail($id);
        $old = $pasal->replicate();
        PasalLink::withTrashed()
            ->where('source_pasal_id', $id)
            ->orWhere('target_pasal_id', $id)
            ->forceDelete();
        $pasal->forceDelete();
        $audit->log($request, 'DELETE', 'pasal', $id, $old, null, ['force' => true]);

        return response()->json(['message' => 'Pasal dihapus permanen.']);
    }

    public function bulkForceDelete(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $request->validate(['ids' => ['required', 'array'], 'ids.*' => ['uuid']]);
        $deleted = 0;

        foreach ($payload['ids'] as $id) {
            $pasal = Pasal::withTrashed()->find($id);
            if (! $pasal) {
                continue;
            }
            $old = $pasal->replicate();
            PasalLink::withTrashed()
                ->where('source_pasal_id', $id)
                ->orWhere('target_pasal_id', $id)
                ->forceDelete();
            $pasal->forceDelete();
            $audit->log($request, 'DELETE', 'pasal', $id, $old, null, ['force' => true]);
            $deleted++;
        }

        return response()->json(['deleted' => $deleted]);
    }

    public function bulkImport(Request $request, ImportPasalService $importer, AuditService $audit): JsonResponse
    {
        $request->validate([
            'file' => ['nullable', 'file', 'mimes:xlsx,xls,csv'],
            'rows' => ['nullable', 'array'],
        ]);

        $result = $request->hasFile('file')
            ? $importer->importFile($request->file('file'), $request->user()?->id)
            : $importer->importRows($request->input('rows', []), $request->user()?->id);

        $audit->log($request, 'IMPORT', 'pasal', null, null, null, $result);

        return response()->json($result);
    }

    private function validated(Request $request, bool $partial = false, ?Pasal $pasal = null): array
    {
        $required = $partial ? 'sometimes' : 'required';
        $undangUndangId = $request->input('undang_undang_id', $pasal?->undang_undang_id);

        return $request->validate([
            'undang_undang_id' => [$required, 'uuid', 'exists:undang_undang,id'],
            'nomor' => [
                $required,
                'string',
                'max:100',
                Rule::unique('pasal', 'nomor')
                    ->where(fn ($query) => $query->where('undang_undang_id', $undangUndangId))
                    ->ignore($pasal?->id),
            ],
            'judul' => ['nullable', 'string', 'max:500'],
            'isi' => [$required, 'string'],
            'penjelasan' => ['nullable', 'string'],
            'keywords' => ['sometimes', 'array'],
            'keywords.*' => ['string'],
            'is_active' => ['sometimes', 'boolean'],
        ], [
            'nomor.unique' => 'Nomor pasal ini sudah ada pada undang-undang yang dipilih.',
        ]);
    }
}
