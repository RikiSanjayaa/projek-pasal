<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Pasal;
use App\Services\AuditService;
use App\Services\ImportPasalService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PasalController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Pasal::query()->with('undangUndang');
        if ($request->boolean('with_trashed')) {
            $query->withTrashed();
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

        return response()->json($query->orderBy('nomor')->paginate((int) $request->query('per_page', 20)));
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
        $payload = $this->validated($request, true);
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

    private function validated(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'undang_undang_id' => [$required, 'uuid', 'exists:undang_undang,id'],
            'nomor' => [$required, 'string', 'max:100'],
            'judul' => ['nullable', 'string', 'max:500'],
            'isi' => [$required, 'string'],
            'penjelasan' => ['nullable', 'string'],
            'keywords' => ['sometimes', 'array'],
            'keywords.*' => ['string'],
            'is_active' => ['sometimes', 'boolean'],
        ]);
    }
}
