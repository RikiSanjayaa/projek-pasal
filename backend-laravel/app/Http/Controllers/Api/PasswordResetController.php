<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminUser;
use App\Models\MobileUser;
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
            'user_type' => ['required', Rule::in(['admin', 'mobile'])],
            'reset_url' => ['nullable', 'url'],
        ]);

        $email = Str::lower($payload['email']);
        $userType = $payload['user_type'];
        $user = $this->findActiveUser($email, $userType);

        if ($user) {
            $plainToken = Str::random(64);
            $expiresAt = now()->addMinutes((int) config('auth.passwords.users.expire', 60));
            $baseResetUrl = $payload['reset_url'] ?? $this->defaultResetUrl($userType);
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

        return response()->json([
            'message' => 'Jika email terdaftar dan aktif, link reset password akan dikirim.',
        ]);
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
        $user->tokens()->delete();

        if ($user instanceof MobileUser) {
            $user->devices()->update(['is_active' => false]);
        }

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
        if ($userType === 'mobile') {
            return rtrim((string) env('MOBILE_PASSWORD_RESET_URL', env('ADMIN_PASSWORD_RESET_URL', config('app.url').'/admin/reset-password')), '/');
        }

        return rtrim((string) env('ADMIN_PASSWORD_RESET_URL', config('app.url').'/admin/reset-password'), '/');
    }
}
