<?php

use App\Http\Controllers\Api\AdminUserController;
use App\Http\Controllers\Api\AuditLogController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\MobileUserController;
use App\Http\Controllers\Api\PasalController;
use App\Http\Controllers\Api\PasalLinkController;
use App\Http\Controllers\Api\SyncController;
use App\Http\Controllers\Api\UndangUndangController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => ['status' => 'ok', 'time' => now()->toISOString()]);

Route::post('/admin/login', [AuthController::class, 'adminLogin']);
Route::post('/mobile/login', [AuthController::class, 'mobileLogin']);

Route::middleware(['auth:sanctum', 'role:admin,super_admin'])->prefix('admin')->group(function () {
    Route::post('/logout', [AuthController::class, 'adminLogout']);
    Route::get('/me', [AuthController::class, 'adminMe']);
    Route::get('/dashboard/summary', [DashboardController::class, 'summary']);

    Route::apiResource('/undang-undang', UndangUndangController::class);
    Route::patch('/undang-undang/{id}/restore', [UndangUndangController::class, 'restore']);

    Route::post('/pasal/bulk-import', [PasalController::class, 'bulkImport']);
    Route::post('/pasal/bulk-delete', [PasalController::class, 'bulkDelete']);
    Route::post('/pasal/bulk-restore', [PasalController::class, 'bulkRestore']);
    Route::post('/pasal/bulk-force-delete', [PasalController::class, 'bulkForceDelete']);
    Route::delete('/pasal/{id}/force', [PasalController::class, 'forceDelete']);
    Route::apiResource('/pasal', PasalController::class);
    Route::patch('/pasal/{id}/restore', [PasalController::class, 'restore']);
    Route::get('/pasal/{id}/links', [PasalLinkController::class, 'index']);
    Route::post('/pasal/{id}/links', [PasalLinkController::class, 'store']);
    Route::delete('/pasal-links/{id}', [PasalLinkController::class, 'destroy']);

    Route::get('/mobile-users', [MobileUserController::class, 'index']);
    Route::post('/mobile-users', [MobileUserController::class, 'store']);
    Route::post('/mobile-users/bulk-create', [MobileUserController::class, 'bulkCreate']);
    Route::patch('/mobile-users/{id}/activate', [MobileUserController::class, 'activate']);
    Route::patch('/mobile-users/{id}/deactivate', [MobileUserController::class, 'deactivate']);
    Route::patch('/mobile-users/{id}/extend', [MobileUserController::class, 'extend']);
    Route::patch('/mobile-users/{id}/password', [MobileUserController::class, 'resetPassword']);
    Route::get('/mobile-users/{id}/devices', [MobileUserController::class, 'devices']);
    Route::delete('/mobile-users/{id}/devices/{deviceId}', [MobileUserController::class, 'deleteDevice']);
    Route::delete('/mobile-users/{id}', [MobileUserController::class, 'destroy']);

    Route::middleware('role:super_admin')->group(function () {
        Route::get('/admin-users', [AdminUserController::class, 'index']);
        Route::post('/admin-users', [AdminUserController::class, 'store']);
        Route::patch('/admin-users/{id}/activate', [AdminUserController::class, 'activate']);
        Route::patch('/admin-users/{id}/deactivate', [AdminUserController::class, 'deactivate']);
        Route::delete('/admin-users/{id}/devices/{deviceId}', [AdminUserController::class, 'deleteDevice']);
    });

    Route::get('/audit-logs', [AuditLogController::class, 'index']);
    Route::get('/audit-logs/{id}', [AuditLogController::class, 'show']);
});

Route::middleware(['auth:sanctum', 'mobile.active', 'mobile.not_expired', 'device.allowed'])->prefix('mobile')->group(function () {
    Route::post('/logout', [AuthController::class, 'mobileLogout']);
    Route::get('/me', [AuthController::class, 'mobileMe']);
    Route::post('/device/heartbeat', [AuthController::class, 'mobileHeartbeat']);
    Route::get('/sync/check', [SyncController::class, 'check']);
    Route::get('/sync/updates', [SyncController::class, 'updates']);
    Route::get('/sync/full', [SyncController::class, 'full']);
});
