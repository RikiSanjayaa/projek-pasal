<?php

namespace App\Services;

use App\Models\AdminDevice;
use App\Models\AdminUser;
use App\Models\MobileUser;
use App\Models\UserDevice;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Perangkat aktif untuk akun mobile (user_devices) maupun admin/super_admin (admin_devices).
 * Batas 3 perangkat aktif berlaku sama untuk keduanya.
 */
class UserDeviceService
{
    public const MAX_ACTIVE_DEVICES = 3;

    public const TOKEN_PREFIX = 'mobile-app:';

    public const MOBILE_ABILITY = 'mobile';

    public static function tokenName(string $deviceId): string
    {
        return self::TOKEN_PREFIX.hash('sha256', $deviceId);
    }

    public function registerOrTouch(AdminUser|MobileUser $owner, string $deviceId, ?string $deviceName = null, ?string $platform = null, ?Request $request = null): AdminDevice|UserDevice
    {
        $existing = $owner->devices()->where('device_id', $deviceId)->first();
        if ($existing) {
            if (! $existing->is_active && $this->activeDeviceCount($owner) >= self::MAX_ACTIVE_DEVICES) {
                throw $this->capacityException();
            }

            $existing->update($this->attributes($owner, $deviceName ?? $existing->device_name, $platform ?? ($existing->platform ?? null), $request));

            return $existing;
        }

        if ($this->activeDeviceCount($owner) >= self::MAX_ACTIVE_DEVICES) {
            throw $this->capacityException();
        }

        return $owner->devices()->create(['device_id' => $deviceId] + $this->attributes($owner, $deviceName, $platform, $request));
    }

    /** Buat token mobile yang terikat ke satu perangkat; token lama perangkat yang sama diganti. */
    public function issueToken(AdminUser|MobileUser $owner, string $deviceId): string
    {
        $name = self::tokenName($deviceId);
        $owner->tokens()->where('name', $name)->delete();

        return $owner->createToken($name, [self::MOBILE_ABILITY])->plainTextToken;
    }

    /** Nonaktifkan satu perangkat dan cabut token yang terikat padanya. */
    public function deactivate(AdminUser|MobileUser $owner, string $deviceId): void
    {
        DB::transaction(function () use ($owner, $deviceId) {
            $this->lockOwner($owner);

            $owner->devices()
                ->where('device_id', $deviceId)
                ->update(['is_active' => false, 'last_active_at' => now()]);

            $owner->tokens()->where('name', self::tokenName($deviceId))->delete();
        });
    }

    /** Nonaktifkan seluruh perangkat dan cabut semua token akun (mobile maupun dashboard). */
    public function revokeAll(AdminUser|MobileUser $owner): void
    {
        DB::transaction(function () use ($owner) {
            $this->lockOwner($owner);

            $owner->devices()->update(['is_active' => false]);
            $owner->tokens()->delete();
        });
    }

    public function findActive(AdminUser|MobileUser $owner, ?string $deviceId): AdminDevice|UserDevice|null
    {
        if (! $deviceId) {
            return null;
        }

        return $owner->devices()
            ->where('device_id', $deviceId)
            ->where('is_active', true)
            ->first();
    }

    /** Serialkan login dan pencabutan untuk satu akun (dipanggil di dalam transaksi). */
    private function lockOwner(AdminUser|MobileUser $owner): void
    {
        $owner::query()->whereKey($owner->getKey())->lockForUpdate()->first();
    }

    private function attributes(AdminUser|MobileUser $owner, ?string $deviceName, ?string $platform, ?Request $request): array
    {
        $attributes = ['device_name' => $deviceName, 'is_active' => true, 'last_active_at' => now()];

        if ($owner instanceof AdminUser) {
            if ($request) {
                $attributes['user_agent'] = $request->userAgent();
                $attributes['ip_address'] = $request->ip();
            }

            return $attributes;
        }

        return $attributes + ['platform' => $platform];
    }

    private function capacityException(): ValidationException
    {
        return ValidationException::withMessages([
            'device_id' => 'Akun ini sudah mencapai batas 3 perangkat aktif.',
        ]);
    }

    private function activeDeviceCount(AdminUser|MobileUser $owner): int
    {
        return $owner->devices()->where('is_active', true)->count();
    }
}
