<?php

namespace App\Services;

use App\Models\MobileUser;
use App\Models\UserDevice;
use Illuminate\Validation\ValidationException;

class UserDeviceService
{
    public function registerOrTouch(MobileUser $user, string $deviceId, ?string $deviceName = null, ?string $platform = null): UserDevice
    {
        $existing = $user->devices()->where('device_id', $deviceId)->first();
        if ($existing) {
            $existing->update([
                'device_name' => $deviceName ?? $existing->device_name,
                'platform' => $platform ?? $existing->platform,
                'is_active' => true,
                'last_active_at' => now(),
            ]);

            return $existing;
        }

        $hasOtherActiveDevice = $user->devices()->where('is_active', true)->exists();
        if ($hasOtherActiveDevice) {
            throw ValidationException::withMessages([
                'device_id' => 'Akun ini sudah terhubung dengan perangkat lain.',
            ]);
        }

        return UserDevice::create([
            'mobile_user_id' => $user->id,
            'device_id' => $deviceId,
            'device_name' => $deviceName,
            'platform' => $platform,
            'is_active' => true,
            'last_active_at' => now(),
        ]);
    }

    public function assertAllowed(MobileUser $user, ?string $deviceId): void
    {
        if (! $deviceId) {
            throw ValidationException::withMessages(['device_id' => 'Device ID wajib dikirim.']);
        }

        $allowed = $user->devices()
            ->where('device_id', $deviceId)
            ->where('is_active', true)
            ->exists();

        if (! $allowed) {
            throw ValidationException::withMessages(['device_id' => 'Perangkat tidak aktif untuk akun ini.']);
        }
    }
}
