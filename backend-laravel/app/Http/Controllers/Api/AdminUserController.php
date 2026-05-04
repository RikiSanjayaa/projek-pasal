<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminUser;
use App\Services\AuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminUserController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        return response()->json(AdminUser::query()->orderBy('nama')->paginate((int) $request->query('per_page', 20)));
    }

    public function store(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $request->validate([
            'email' => ['required', 'email', 'unique:admin_users,email'],
            'password' => ['required', 'string', 'min:8'],
            'nama' => ['required', 'string', 'max:255'],
            'role' => ['required', 'in:admin,super_admin'],
        ]);

        $admin = AdminUser::create($payload + ['is_active' => true]);
        $audit->log($request, 'CREATE', 'admin_users', $admin->id, null, $admin);

        return response()->json($admin, 201);
    }

    public function activate(Request $request, string $id, AuditService $audit): JsonResponse
    {
        return $this->toggle($request, $id, true, $audit);
    }

    public function deactivate(Request $request, string $id, AuditService $audit): JsonResponse
    {
        return $this->toggle($request, $id, false, $audit);
    }

    private function toggle(Request $request, string $id, bool $active, AuditService $audit): JsonResponse
    {
        $admin = AdminUser::findOrFail($id);
        $old = $admin->replicate();
        $admin->update(['is_active' => $active]);
        $audit->log($request, 'UPDATE', 'admin_users', $admin->id, $old, $admin);

        return response()->json($admin);
    }
}
