<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Middleware\RoleMiddleware;
use App\Models\AdminUser;
use App\Models\MobileUser;
use App\Services\AuditService;
use App\Services\MobileAccessService;
use App\Services\UserDeviceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function adminLogin(Request $request, AuditService $audit): JsonResponse
    {
        $credentials = $request->validate(['email' => ['required', 'email'], 'password' => ['required', 'string']]);
        $admin = AdminUser::where('email', $credentials['email'])->first();

        if (! $admin || ! $admin->is_active || ! Hash::check($credentials['password'], $admin->password)) {
            throw ValidationException::withMessages(['email' => 'Email atau password salah.']);
        }

        $admin->update(['last_login_at' => now()]);
        $token = $admin->createToken('admin-dashboard', [RoleMiddleware::DASHBOARD_ABILITY])->plainTextToken;
        $audit->log($request, 'LOGIN', 'admin_users', $admin->id, null, ['email' => $admin->email]);

        return response()->json(['token' => $token, 'user' => $admin]);
    }

    public function adminMe(Request $request): JsonResponse
    {
        return response()->json(['user' => $request->user()]);
    }

    public function adminLogout(Request $request, AuditService $audit): JsonResponse
    {
        $user = $request->user();
        $request->user()?->currentAccessToken()?->delete();
        $audit->log($request, 'LOGOUT', 'admin_users', $user?->id);

        return response()->json(['message' => 'Logout berhasil.']);
    }

    public function mobileLogin(Request $request, UserDeviceService $devices, MobileAccessService $access, AuditService $audit): JsonResponse
    {
        $payload = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'device_id' => ['required', 'string', 'max:255'],
            'device_name' => ['nullable', 'string', 'max:255'],
            'platform' => ['nullable', 'string', 'max:50'],
        ]);

        // Tanpa pemilih tipe akun: kredensial admin dicocokkan lebih dulu (aktif atau tidak, agar admin
        // nonaktif tidak bisa jatuh ke akun mobile), baru kredensial user mobile.
        $user = AdminUser::where('email', $payload['email'])->first();
        if (! $user || ! Hash::check($payload['password'], $user->password)) {
            $user = MobileUser::where('email', $payload['email'])->first();
            if (! $user || ! Hash::check($payload['password'], $user->password)) {
                throw ValidationException::withMessages(['email' => 'Email atau password salah.']);
            }
        }
        $model = $user::class;

        // Kunci baris akun supaya batas 3 perangkat, penggantian token, dan pencabutan
        // bersamaan (nonaktifkan/reset password) tidak saling balapan.
        [$user, $device, $token] = DB::transaction(function () use ($model, $user, $payload, $devices, $request, $audit) {
            $locked = $model::query()->lockForUpdate()->find($user->id);

            if (! $locked || $locked->password !== $user->password) {
                throw ValidationException::withMessages(['email' => 'Email atau password salah.']);
            }

            if (! $locked->is_active) {
                throw ValidationException::withMessages(['email' => 'Akun tidak aktif.']);
            }

            if ($locked instanceof MobileUser && $locked->expires_at && $locked->expires_at->isPast()) {
                throw ValidationException::withMessages(['email' => 'Masa aktif akun sudah berakhir.']);
            }

            $device = $devices->registerOrTouch($locked, $payload['device_id'], $payload['device_name'] ?? null, $payload['platform'] ?? null, $request);
            $locked->update(['last_login_at' => now()]);
            $token = $devices->issueToken($locked, $payload['device_id']);

            if ($locked instanceof AdminUser) {
                $audit->log($request, 'LOGIN', 'admin_users', $locked->id, null, ['email' => $locked->email], ['channel' => 'mobile']);
            }

            return [$locked, $device, $token];
        });

        return response()->json([
            'token' => $token,
            'user' => $user,
            'device' => $device,
            'access' => $access->forUser($user),
        ]);
    }

    public function mobileMe(Request $request, MobileAccessService $access): JsonResponse
    {
        $user = $request->user();

        return response()->json(['user' => $user, 'access' => $access->forUser($user)]);
    }

    public function mobileLogout(Request $request, UserDeviceService $devices, AuditService $audit): JsonResponse
    {
        $user = $request->user();
        $device = $request->attributes->get('mobile_device');

        $devices->deactivate($user, $device->device_id);
        if ($user instanceof AdminUser) {
            $audit->log($request, 'LOGOUT', 'admin_users', $user->id, null, null, ['channel' => 'mobile']);
        }

        return response()->json(['message' => 'Logout berhasil.']);
    }

    public function mobileHeartbeat(Request $request, UserDeviceService $devices): JsonResponse
    {
        $payload = $request->validate([
            'device_id' => ['nullable', 'string', 'max:255'],
            'device_name' => ['nullable', 'string', 'max:255'],
            'platform' => ['nullable', 'string', 'max:50'],
        ]);

        $bound = $request->attributes->get('mobile_device');
        if (isset($payload['device_id']) && $payload['device_id'] !== $bound->device_id) {
            abort(403, 'Token tidak berlaku untuk perangkat ini.');
        }

        $device = DB::transaction(function () use ($request, $devices, $bound, $payload) {
            $user = $request->user();
            $user::query()->whereKey($user->getKey())->lockForUpdate()->firstOrFail();
            if (! $user->tokens()->whereKey($user->currentAccessToken()->getKey())->exists()
                || ! $devices->findActive($user, $bound->device_id)) {
                abort(403, 'Perangkat tidak aktif untuk akun ini.');
            }

            return $devices->registerOrTouch($user, $bound->device_id, $payload['device_name'] ?? null, $payload['platform'] ?? null, $request);
        });

        return response()->json(['device' => $device]);
    }
}
