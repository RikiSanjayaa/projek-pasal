<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncController extends Controller
{
    public function check(Request $request, SyncService $sync): JsonResponse
    {
        $request->validate(['since' => ['nullable', 'date']]);

        return response()->json([
            'has_updates' => $sync->hasUpdates($request->query('since')),
            'server_time' => now()->toISOString(),
        ]);
    }

    public function updates(Request $request, SyncService $sync): JsonResponse
    {
        $request->validate(['since' => ['nullable', 'date']]);

        return response()->json($sync->updates($request->query('since')));
    }

    public function full(SyncService $sync): JsonResponse
    {
        return response()->json($sync->full());
    }
}
