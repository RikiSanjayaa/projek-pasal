<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PasalLink;
use App\Services\AuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PasalLinkController extends Controller
{
    public function index(string $pasalId): JsonResponse
    {
        return response()->json(PasalLink::with(['sourcePasal.undangUndang', 'targetPasal.undangUndang'])
            ->where('source_pasal_id', $pasalId)
            ->where('is_active', true)
            ->get());
    }

    public function store(Request $request, string $pasalId, AuditService $audit): JsonResponse
    {
        $payload = $request->validate([
            'target_pasal_id' => ['required', 'uuid', 'exists:pasal,id', 'different:source_pasal_id'],
            'keterangan' => ['nullable', 'string'],
        ]);
        $payload['source_pasal_id'] = $pasalId;
        $payload['created_by'] = $request->user()?->id;
        $payload['is_active'] = true;

        $link = PasalLink::updateOrCreate(
            ['source_pasal_id' => $payload['source_pasal_id'], 'target_pasal_id' => $payload['target_pasal_id']],
            $payload,
        );
        $audit->log($request, 'CREATE', 'pasal_links', $link->id, null, $link);

        return response()->json($link->load(['sourcePasal.undangUndang', 'targetPasal.undangUndang']), 201);
    }

    public function destroy(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $link = PasalLink::findOrFail($id);
        $old = $link->replicate();
        $link->update(['is_active' => false]);
        $link->delete();
        $audit->log($request, 'DELETE', 'pasal_links', $link->id, $old, $link);

        return response()->json(['message' => 'Relasi pasal dihapus.']);
    }
}
