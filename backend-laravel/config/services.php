<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    /*
    | Import on-demand dari datahukum.com lewat dashboard admin (issue #29).
    | Mati secara default; staging menyalakannya dengan DATAHUKUM_FETCH_ENABLED=true.
    */
    'datahukum' => [
        'enabled' => (bool) env('DATAHUKUM_FETCH_ENABLED', false),
        'python' => env('IMPORT_PYTHON', '/opt/import-venv/bin/python'),
        'tools_dir' => env('IMPORT_TOOLS_DIR', '/opt/import-tools'),
        'cache_dir' => env('IMPORT_CACHE_DIR', storage_path('app/import-cache')),
        // Batas waktu satu run (detik). Harus lebih kecil dari --timeout queue worker (900).
        'timeout' => (int) env('IMPORT_TIMEOUT', 840),
        // Jarak minimum antar run untuk UU yang sama (menit), supaya datahukum tidak dibebani.
        'min_interval_minutes' => (int) env('IMPORT_MIN_INTERVAL_MINUTES', 10),
    ],

];
