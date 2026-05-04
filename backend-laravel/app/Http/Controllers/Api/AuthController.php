<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminUser;
use App\Models\MobileUser;
use App\Services\AuditService;
use App\Services\UserDeviceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
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
        $token = $admin->createToken('admin-dashboard')->plainTextToken;
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

    public function mobileLogin(Request $request, UserDeviceService $devices): JsonResponse
    {
        $payload = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'device_id' => ['required', 'string', 'max:255'],
            'device_name' => ['nullable', 'string', 'max:255'],
            'platform' => ['nullable', 'string', 'max:50'],
        ]);

        $user = MobileUser::where('email', $payload['email'])->first();
        if (! $user || ! $user->is_active || ($user->expires_at && $user->expires_at->isPast()) || ! Hash::check($payload['password'], $user->password)) {
            throw ValidationException::withMessages(['email' => 'Email atau password salah, akun tidak aktif, atau akun sudah expired.']);
        }

        $device = $devices->registerOrTouch($user, $payload['device_id'], $payload['device_name'] ?? null, $payload['platform'] ?? null);
        $user->update(['last_login_at' => now()]);
        $token = $user->createToken('mobile-app')->plainTextToken;

        return response()->json(['token' => $token, 'user' => $user, 'device' => $device]);
    }

    public function mobileMe(Request $request): JsonResponse
    {
        return response()->json(['user' => $request->user()]);
    }

    public function mobileLogout(Request $request): JsonResponse
    {
        $request->user()?->currentAccessToken()?->delete();

        return response()->json(['message' => 'Logout berhasil.']);
    }

    public function mobileHeartbeat(Request $request, UserDeviceService $devices): JsonResponse
    {
        $payload = $request->validate([
            'device_id' => ['required', 'string', 'max:255'],
            'device_name' => ['nullable', 'string', 'max:255'],
            'platform' => ['nullable', 'string', 'max:50'],
        ]);

        $device = $devices->registerOrTouch($request->user(), $payload['device_id'], $payload['device_name'] ?? null, $payload['platform'] ?? null);

        return response()->json(['device' => $device]);
    }
}
