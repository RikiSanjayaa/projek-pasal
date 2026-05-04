<!doctype html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <title>Reset Password CariPasal</title>
</head>
<body style="font-family: Arial, sans-serif; color: #111827; line-height: 1.5;">
    <p>Halo {{ $name }},</p>

    <p>Kami menerima permintaan reset password untuk akun CariPasal {{ $userType === 'admin' ? 'admin' : 'mobile' }} Anda.</p>

    <p>
        <a href="{{ $resetLink }}" style="display: inline-block; padding: 10px 16px; background: #2563eb; color: #ffffff; text-decoration: none; border-radius: 6px;">
            Reset Password
        </a>
    </p>

    <p>Link ini berlaku sampai {{ $expiresAt->timezone(config('app.timezone'))->format('d M Y H:i') }}.</p>

    <p>Jika tombol tidak bisa dibuka, salin link berikut ke browser:</p>
    <p style="word-break: break-all;">{{ $resetLink }}</p>

    <p>Jika Anda tidak meminta reset password, abaikan email ini.</p>
</body>
</html>
