<?php

// Nilai dari .env wajib dibaca lewat config(): setelah `php artisan config:cache`, env() di luar
// folder config mengembalikan null.
return [

    // Dipakai DatabaseSeeder hanya saat akun super admin belum ada.
    'super_admin' => [
        'email' => env('CARIPASAL_SUPER_ADMIN_EMAIL', 'superadmin@caripasal.local'),
        'password' => env('CARIPASAL_SUPER_ADMIN_PASSWORD', 'ChangeMe123!'),
        'name' => env('CARIPASAL_SUPER_ADMIN_NAME', 'Super Admin'),
    ],

    'password_reset_url' => [
        'admin' => env('ADMIN_PASSWORD_RESET_URL'),
        'mobile' => env('MOBILE_PASSWORD_RESET_URL'),
    ],

];
