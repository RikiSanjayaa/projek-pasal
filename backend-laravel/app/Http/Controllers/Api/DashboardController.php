<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminUser;
use App\Models\AuditLog;
use App\Models\MobileUser;
use App\Models\Pasal;
use App\Models\UndangUndang;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    public function summary(): JsonResponse
    {
        return response()->json([
            'total_undang_undang' => UndangUndang::count(),
            'total_pasal' => Pasal::count(),
            'total_pasal_active' => Pasal::where('is_active', true)->count(),
            'total_pasal_inactive' => Pasal::where('is_active', false)->count(),
            'total_admin' => AdminUser::count(),
            'total_mobile_user' => MobileUser::count(),
            'recent_audit_logs' => AuditLog::orderByDesc('created_at')->limit(10)->get(),
        ]);
    }
}
