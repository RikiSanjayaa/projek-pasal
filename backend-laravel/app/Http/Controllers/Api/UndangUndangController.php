<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UndangUndang;
use App\Services\AuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UndangUndangController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = UndangUndang::query();
        if ($request->boolean('with_trashed')) {
            $query->withTrashed();
        }
        if ($search = $request->query('search')) {
            $query->where(fn ($q) => $q->where('kode', 'ilike', "%{$search}%")->orWhere('nama', 'ilike', "%{$search}%"));
        }
        if ($request->has('is_active')) {
            $query->where('is_active', filter_var($request->query('is_active'), FILTER_VALIDATE_BOOLEAN));
        }

        return response()->json($query->orderByDesc('tahun')->paginate((int) $request->query('per_page', 20)));
    }

    public function store(Request $request, AuditService $audit): JsonResponse
    {
        $uu = UndangUndang::create($this->validated($request));
        $audit->log($request, 'CREATE', 'undang_undang', $uu->id, null, $uu);

        return response()->json($uu, 201);
    }

    public function show(string $id): JsonResponse
    {
        return response()->json(UndangUndang::withTrashed()->findOrFail($id));
    }

    public function update(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $uu = UndangUndang::withTrashed()->findOrFail($id);
        $old = $uu->replicate();
        $uu->update($this->validated($request, true));
        $audit->log($request, 'UPDATE', 'undang_undang', $uu->id, $old, $uu);

        return response()->json($uu);
    }

    public function destroy(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $uu = UndangUndang::findOrFail($id);
        $old = $uu->replicate();
        $uu->update(['is_active' => false]);
        $uu->delete();
        $audit->log($request, 'DELETE', 'undang_undang', $uu->id, $old, $uu);

        return response()->json(['message' => 'Undang-undang dihapus.']);
    }

    public function restore(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $uu = UndangUndang::withTrashed()->findOrFail($id);
        $uu->restore();
        $uu->update(['is_active' => true]);
        $audit->log($request, 'RESTORE', 'undang_undang', $uu->id, null, $uu);

        return response()->json($uu);
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'kode' => [$required, 'string', 'max:50'],
            'nama' => [$required, 'string', 'max:255'],
            'nama_lengkap' => ['nullable', 'string'],
            'deskripsi' => ['nullable', 'string'],
            'tahun' => ['nullable', 'integer'],
            'is_active' => ['sometimes', 'boolean'],
        ]);
    }
}
