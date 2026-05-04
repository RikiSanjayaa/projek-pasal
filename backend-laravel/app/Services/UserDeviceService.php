<?php

namespace App\Services;

use App\Models\MobileUser;
use App\Models\UserDevice;
use Illuminate\Validation\ValidationException;

class UserDeviceService
{
    private const MAX_ACTIVE_DEVICES = 3;

    public function registerOrTouch(MobileUser $user, string $deviceId, ?string $deviceName = null, ?string $platform = null): UserDevice
    {
        $existing = $user->devices()->where('device_id', $deviceId)->first();
        if ($existing) {
            if (! $existing->is_active && $this->activeDeviceCount($user) >= self::MAX_ACTIVE_DEVICES) {
                throw ValidationException::withMessages([
                    'device_id' => 'Akun ini sudah mencapai batas 3 perangkat aktif.',
                ]);
            }

            $existing->update([
                'device_name' => $deviceName ?? $existing->device_name,
                'platform' => $platform ?? $existing->platform,
                'is_active' => true,
                'last_active_at' => now(),
            ]);

            return $existing;
        }

        if ($this->activeDeviceCount($user) >= self::MAX_ACTIVE_DEVICES) {
            throw ValidationException::withMessages([
                'device_id' => 'Akun ini sudah mencapai batas 3 perangkat aktif.',
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

    public function deactivate(MobileUser $user, string $deviceId): void
    {
        $user->devices()
            ->where('device_id', $deviceId)
            ->update([
                'is_active' => false,
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

    private function activeDeviceCount(MobileUser $user): int
    {
        return $user->devices()->where('is_active', true)->count();
    }
}
