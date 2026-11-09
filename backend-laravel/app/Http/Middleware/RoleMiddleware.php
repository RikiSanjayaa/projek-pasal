<?php

namespace App\Http\Middleware;

use App\Models\AdminUser;
use App\Services\UserDeviceService;
use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;

class RoleMiddleware
{
    public const DASHBOARD_ABILITY = 'admin';

    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user instanceof AdminUser || ! $user->is_active || ! in_array($user->role, $roles, true)) {
            abort(403, 'Akses ditolak.');
        }

        if (! $this->isDashboardToken($user->currentAccessToken())) {
            abort(403, 'Akses ditolak.');
        }

        return $next($request);
    }

    /**
     * Token dashboard berscope `admin`. Token dashboard lama (wildcard, bernama admin-dashboard)
     * tetap diterima; token mobile tidak pernah punya hak dashboard.
     */
    private function isDashboardToken(mixed $token): bool
    {
        if (! $token instanceof PersonalAccessToken) {
            return false;
        }

        $abilities = $token->abilities ?? [];

        if ($abilities === ['*']) {
            return $token->name === 'admin-dashboard';
        }

        return in_array(self::DASHBOARD_ABILITY, $abilities, true)
            && ! in_array('mobile', $abilities, true)
            && ! str_starts_with($token->name, UserDeviceService::TOKEN_PREFIX);
    }
}
