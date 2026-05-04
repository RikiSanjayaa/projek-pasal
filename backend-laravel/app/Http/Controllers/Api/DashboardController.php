<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminUser;
use App\Models\AuditLog;
use App\Models\MobileUser;
use App\Models\Pasal;
use App\Models\PasalLink;
use App\Models\UndangUndang;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function summary(): JsonResponse
    {
        $today = now()->startOfDay();
        $weekAgo = now()->subDays(7);
        $pasalCounts = Pasal::query()
            ->select('undang_undang_id', DB::raw('count(*) as total'))
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->groupBy('undang_undang_id')
            ->pluck('total', 'undang_undang_id');

        return response()->json([
            'total_undang_undang' => UndangUndang::count(),
            'total_pasal' => Pasal::count(),
            'total_pasal_active' => Pasal::where('is_active', true)->count(),
            'total_pasal_inactive' => Pasal::where('is_active', false)->count(),
            'total_admin' => AdminUser::count(),
            'total_mobile_user' => MobileUser::count(),
            'recent_audit_logs' => AuditLog::orderByDesc('created_at')->limit(10)->get(),
            'total_changes_today' => AuditLog::where('created_at', '>=', $today)->count(),
            'undang_undang_list' => UndangUndang::where('is_active', true)->orderBy('kode')->get(),
            'pasal_counts' => $pasalCounts,
            'admin_active_count' => AdminUser::where('is_active', true)->count(),
            'all_pasal' => Pasal::where('is_active', true)->whereNull('deleted_at')->get([
                'id',
                'nomor',
                'judul',
                'isi',
                'penjelasan',
                'keywords',
                'created_at',
                'updated_at',
                'undang_undang_id',
            ]),
            'all_links' => PasalLink::where('is_active', true)->get(),
            'audit_logs_analytics' => AuditLog::where('created_at', '>=', now()->subDays(90))->orderByDesc('created_at')->get(),
            'trashed_pasal' => Pasal::withTrashed()
                ->where('is_active', false)
                ->whereNotNull('deleted_at')
                ->orderByDesc('deleted_at')
                ->limit(10)
                ->get(['id', 'nomor', 'judul', 'deleted_at']),
            'new_pasal_this_week' => Pasal::where('created_at', '>=', $weekAgo)->where('is_active', true)->count(),
        ]);
    }
}
