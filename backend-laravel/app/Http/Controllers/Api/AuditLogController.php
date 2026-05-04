<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = AuditLog::query();
        foreach (['actor_type', 'action', 'table_name', 'record_id'] as $field) {
            if ($request->filled($field)) {
                $query->where($field, $request->query($field));
            }
        }
        if ($search = $request->query('search')) {
            $query->where(fn ($q) => $q
                ->where('admin_email', 'ilike', "%{$search}%")
                ->orWhere('table_name', 'ilike', "%{$search}%")
                ->orWhere('record_id', 'ilike', "%{$search}%"));
        }
        if ($request->filled('start_date')) {
            $query->where('created_at', '>=', $request->query('start_date'));
        }
        if ($request->filled('end_date')) {
            $query->where('created_at', '<=', $request->query('end_date'));
        }

        return response()->json($query->orderByDesc('created_at')->paginate((int) $request->query('per_page', 20)));
    }

    public function show(string $id): JsonResponse
    {
        return response()->json(AuditLog::findOrFail($id));
    }
}
