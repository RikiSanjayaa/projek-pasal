<?php

namespace App\Http\Middleware;

use App\Models\MobileUser;
use App\Services\UserDeviceService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class DeviceAllowedMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        if ($user instanceof MobileUser) {
            app(UserDeviceService::class)->assertAllowed($user, $request->header('X-Device-ID') ?? $request->input('device_id'));
        }

        return $next($request);
    }
}
