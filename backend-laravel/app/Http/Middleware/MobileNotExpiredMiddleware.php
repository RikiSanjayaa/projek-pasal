<?php

namespace App\Http\Middleware;

use App\Models\MobileUser;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class MobileNotExpiredMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user instanceof MobileUser || ($user->expires_at && $user->expires_at->isPast())) {
            abort(403, 'Masa aktif akun sudah berakhir.');
        }

        return $next($request);
    }
}
