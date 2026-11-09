<?php

namespace App\Http\Middleware;

use App\Models\AdminUser;
use App\Models\MobileUser;
use App\Services\UserDeviceService;
use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;

/**
 * Gerbang endpoint mobile: AdminUser atau MobileUser aktif, token berscope `mobile` yang terikat
 * ke perangkat yang dikirim (X-Device-ID), dan perangkat itu masih aktif.
 */
class MobileSessionMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        if (! $user instanceof AdminUser && ! $user instanceof MobileUser) {
            abort(403, 'Akses ditolak.');
        }

        $token = $user->currentAccessToken();
        if (! $token instanceof PersonalAccessToken) {
            abort(403, 'Akses ditolak.');
        }

        // Token mobile versi lama (tanpa scope/ikatan perangkat) harus login ulang.
        if ($token->name === 'mobile-app') {
            abort(401, 'Sesi tidak valid. Silakan login ulang.');
        }

        if (($token->abilities ?? []) !== [UserDeviceService::MOBILE_ABILITY]
            || ! str_starts_with($token->name, UserDeviceService::TOKEN_PREFIX)) {
            abort(403, 'Akses ditolak.');
        }

        if ($user instanceof AdminUser) {
            if (! $user->is_active || ! in_array($user->role, ['admin', 'super_admin'], true)) {
                abort(403, 'Akun tidak aktif.');
            }
        } else {
            if (! $user->is_active) {
                abort(403, 'Akun tidak aktif.');
            }
            if ($user->expires_at && $user->expires_at->isPast()) {
                abort(403, 'Masa aktif akun sudah berakhir.');
            }
        }

        $deviceId = $request->header('X-Device-ID') ?? $request->input('device_id');
        if (! is_string($deviceId) || $deviceId === '') {
            abort(403, 'Device ID wajib dikirim.');
        }

        if (! hash_equals($token->name, UserDeviceService::tokenName($deviceId))) {
            abort(403, 'Token tidak berlaku untuk perangkat ini.');
        }

        $device = app(UserDeviceService::class)->findActive($user, $deviceId);
        if (! $device) {
            abort(403, 'Perangkat tidak aktif untuk akun ini.');
        }

        $request->attributes->set('mobile_device', $device);

        return $next($request);
    }
}
