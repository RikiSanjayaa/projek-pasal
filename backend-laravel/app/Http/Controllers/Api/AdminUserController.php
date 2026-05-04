<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminDevice;
use App\Models\AdminUser;
use App\Services\AuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class AdminUserController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        return response()->json(AdminUser::query()->with('devices')->orderBy('nama')->paginate((int) $request->query('per_page', 20)));
    }

    public function store(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $request->validate([
            'email' => ['required', 'email', 'unique:admin_users,email'],
            'password' => ['nullable', 'string', 'min:8'],
            'nama' => ['required', 'string', 'max:255'],
            'role' => ['nullable', 'in:admin,super_admin'],
        ]);
        $plainPassword = $payload['password'] ?? $this->temporaryPassword();
        $payload['password'] = $plainPassword;
        $payload['role'] = $payload['role'] ?? 'admin';

        $admin = AdminUser::create($payload + ['is_active' => true]);
        $audit->log($request, 'CREATE', 'admin_users', $admin->id, null, $admin);

        return response()->json($admin->load('devices')->toArray() + ['temporary_password' => $plainPassword], 201);
    }

    public function activate(Request $request, string $id, AuditService $audit): JsonResponse
    {
        return $this->toggle($request, $id, true, $audit);
    }

    public function deactivate(Request $request, string $id, AuditService $audit): JsonResponse
    {
        if ($request->user()?->id === $id) {
            return response()->json(['message' => 'Anda tidak dapat menonaktifkan akun sendiri.'], 422);
        }

        return $this->toggle($request, $id, false, $audit);
    }

    public function deleteDevice(Request $request, string $id, string $deviceId, AuditService $audit): JsonResponse
    {
        $device = AdminDevice::where('admin_user_id', $id)->where('id', $deviceId)->firstOrFail();
        $old = $device->replicate();
        $device->update(['is_active' => false]);
        $audit->log($request, 'DELETE', 'admin_devices', $device->id, $old, $device);

        return response()->json(['message' => 'Device admin dinonaktifkan.']);
    }

    private function toggle(Request $request, string $id, bool $active, AuditService $audit): JsonResponse
    {
        $admin = AdminUser::findOrFail($id);
        $old = $admin->replicate();
        $admin->update(['is_active' => $active]);
        $audit->log($request, 'UPDATE', 'admin_users', $admin->id, $old, $admin);

        return response()->json($admin);
    }

    private function temporaryPassword(): string
    {
        return Str::random(10).'1a';
    }
}
