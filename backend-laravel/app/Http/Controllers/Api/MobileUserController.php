<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MobileUser;
use App\Models\UserDevice;
use App\Services\AuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MobileUserController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = MobileUser::query()->with('devices');
        if ($search = $request->query('search')) {
            $query->where(fn ($q) => $q->where('email', 'ilike', "%{$search}%")->orWhere('nama', 'ilike', "%{$search}%"));
        }
        if ($request->has('is_active')) {
            $query->where('is_active', filter_var($request->query('is_active'), FILTER_VALIDATE_BOOLEAN));
        }

        return response()->json($query->orderBy('nama')->paginate((int) $request->query('per_page', 20)));
    }

    public function store(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $this->validated($request);
        $payload['created_by_admin_id'] = $request->user()?->id;
        $payload['expires_at'] = $payload['expires_at'] ?? now()->addYears(3);
        $payload['is_active'] = true;

        $user = MobileUser::create($payload);
        $audit->log($request, 'CREATE', 'mobile_users', $user->id, null, $user);

        return response()->json($user, 201);
    }

    public function bulkCreate(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $request->validate(['users' => ['required', 'array'], 'users.*.email' => ['required', 'email'], 'users.*.nama' => ['required', 'string'], 'users.*.password' => ['required', 'string', 'min:8']]);
        $created = [];
        $errors = [];

        foreach ($payload['users'] as $index => $row) {
            try {
                $created[] = MobileUser::create($row + [
                    'created_by_admin_id' => $request->user()?->id,
                    'expires_at' => now()->addYears(3),
                    'is_active' => true,
                ]);
            } catch (\Throwable $e) {
                $errors[] = ['row' => $index + 1, 'message' => $e->getMessage()];
            }
        }

        $audit->log($request, 'IMPORT', 'mobile_users', null, null, null, ['created' => count($created), 'errors' => $errors]);

        return response()->json(['created' => $created, 'errors' => $errors]);
    }

    public function activate(Request $request, string $id, AuditService $audit): JsonResponse
    {
        return $this->toggle($request, $id, true, $audit);
    }

    public function deactivate(Request $request, string $id, AuditService $audit): JsonResponse
    {
        return $this->toggle($request, $id, false, $audit);
    }

    public function extend(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $payload = $request->validate(['years' => ['nullable', 'integer', 'min:1', 'max:10'], 'expires_at' => ['nullable', 'date']]);
        $user = MobileUser::findOrFail($id);
        $old = $user->replicate();
        $user->update(['expires_at' => $payload['expires_at'] ?? now()->addYears($payload['years'] ?? 3)]);
        $audit->log($request, 'UPDATE', 'mobile_users', $user->id, $old, $user);

        return response()->json($user);
    }

    public function devices(string $id): JsonResponse
    {
        $user = MobileUser::with('devices')->findOrFail($id);

        return response()->json($user->devices);
    }

    public function deleteDevice(Request $request, string $id, string $deviceId, AuditService $audit): JsonResponse
    {
        $device = UserDevice::where('mobile_user_id', $id)->where('id', $deviceId)->firstOrFail();
        $old = $device->replicate();
        $device->update(['is_active' => false]);
        $audit->log($request, 'DELETE', 'user_devices', $device->id, $old, $device);

        return response()->json(['message' => 'Device dinonaktifkan.']);
    }

    private function toggle(Request $request, string $id, bool $active, AuditService $audit): JsonResponse
    {
        $user = MobileUser::findOrFail($id);
        $old = $user->replicate();
        $user->update(['is_active' => $active]);
        $audit->log($request, 'UPDATE', 'mobile_users', $user->id, $old, $user);

        return response()->json($user);
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'email' => ['required', 'email', 'unique:mobile_users,email'],
            'password' => ['required', 'string', 'min:8'],
            'nama' => ['required', 'string', 'max:255'],
            'expires_at' => ['nullable', 'date'],
        ]);
    }
}
