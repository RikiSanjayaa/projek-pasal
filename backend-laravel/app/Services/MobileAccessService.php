<?php

namespace App\Services;

use App\Models\AdminUser;
use App\Models\MobileUser;
use Carbon\CarbonImmutable;

/**
 * Metadata akses mobile yang dikirim ke app. offline_access_until adalah lease offline:
 * app tidak boleh dipakai offline melewati waktu ini sampai /mobile/me berhasil lagi.
 */
class MobileAccessService
{
    public const OFFLINE_LEASE_DAYS = 30;

    /** @return array{account_type: string, expires_at: ?string, offline_access_until: string} */
    public function forUser(AdminUser|MobileUser $user): array
    {
        $lease = CarbonImmutable::now()->addDays(self::OFFLINE_LEASE_DAYS);

        if ($user instanceof AdminUser) {
            return [
                'account_type' => 'admin',
                'expires_at' => null,
                'offline_access_until' => $lease->toISOString(),
            ];
        }

        $expiresAt = $user->expires_at ? CarbonImmutable::instance($user->expires_at) : null;
        if ($expiresAt && $expiresAt->lessThan($lease)) {
            $lease = $expiresAt;
        }

        return [
            'account_type' => 'mobile',
            'expires_at' => $expiresAt?->toISOString(),
            'offline_access_until' => $lease->toISOString(),
        ];
    }
}
