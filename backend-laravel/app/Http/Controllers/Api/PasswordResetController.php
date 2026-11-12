<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminUser;
use App\Models\MobileUser;
use App\Services\UserDeviceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class PasswordResetController extends Controller
{
    public function request(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'email' => ['required', 'email'],
            'user_type' => ['nullable', Rule::in(['admin', 'mobile'])],
            'reset_url' => ['nullable', 'url'],
        ]);

        $email = Str::lower($payload['email']);
        // Tanpa user_type (form mobile tanpa pemilih akun), kirim tautan terpisah untuk tiap identitas aktif.
        $userTypes = isset($payload['user_type']) ? [$payload['user_type']] : ['admin', 'mobile'];

        foreach ($userTypes as $userType) {
            $user = $this->findActiveUser($email, $userType);
            if ($user) {
                $this->sendResetLink($user, $email, $userType, $payload['reset_url'] ?? null);
            }
        }

        return response()->json([
            'message' => 'Jika email terdaftar dan aktif, link reset password akan dikirim.',
        ]);
    }

    private function sendResetLink(AdminUser|MobileUser $user, string $email, string $userType, ?string $resetUrl): void
    {
        $plainToken = Str::random(64);
        $expiresAt = now()->addMinutes((int) config('auth.passwords.users.expire', 60));
        $baseResetUrl = $resetUrl ?? $this->defaultResetUrl($userType);
        $resetLink = $baseResetUrl.'?'.http_build_query([
            'email' => $email,
            'type' => $userType,
            'token' => $plainToken,
        ]);

        DB::table('password_reset_tokens')->insert([
            'email' => $email,
            'user_type' => $userType,
            'token' => Hash::make($plainToken),
            'created_at' => now(),
            'expires_at' => $expiresAt,
        ]);

        Mail::send('emails.password-reset', [
            'name' => $user->nama,
            'resetLink' => $resetLink,
            'expiresAt' => $expiresAt,
            'userType' => $userType,
        ], function ($message) use ($email) {
            $message->to($email)->subject('Reset Password CariPasal');
        });
    }

    public function reset(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'email' => ['required', 'email'],
            'user_type' => ['required', Rule::in(['admin', 'mobile'])],
            'token' => ['required', 'string'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $email = Str::lower($payload['email']);
        $userType = $payload['user_type'];
        $token = DB::table('password_reset_tokens')
            ->where('email', $email)
            ->where('user_type', $userType)
            ->whereNull('used_at')
            ->where('expires_at', '>', now())
            ->orderByDesc('created_at')
            ->first();

        if (! $token || ! Hash::check($payload['token'], $token->token)) {
            throw ValidationException::withMessages([
                'token' => 'Link reset password tidak valid atau sudah kedaluwarsa.',
            ]);
        }

        $user = $this->findActiveUser($email, $userType);
        if (! $user) {
            throw ValidationException::withMessages([
                'email' => 'Akun tidak ditemukan atau tidak aktif.',
            ]);
        }

        $user->update(['password' => $payload['password']]);
        app(UserDeviceService::class)->revokeAll($user);

        DB::table('password_reset_tokens')
            ->where('id', $token->id)
            ->update(['used_at' => now()]);

        return response()->json(['message' => 'Password berhasil direset. Silakan login dengan password baru.']);
    }

    private function findActiveUser(string $email, string $userType): AdminUser|MobileUser|null
    {
        $model = $userType === 'admin' ? AdminUser::class : MobileUser::class;

        return $model::query()
            ->where('email', $email)
            ->where('is_active', true)
            ->first();
    }

    private function defaultResetUrl(string $userType): string
    {
        $adminUrl = config('caripasal.password_reset_url.admin') ?: config('app.url').'/admin/reset-password';
        $url = $userType === 'mobile' ? (config('caripasal.password_reset_url.mobile') ?: $adminUrl) : $adminUrl;

        return rtrim((string) $url, '/');
    }
}
