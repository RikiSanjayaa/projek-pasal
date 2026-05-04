<?php

namespace Database\Seeders;

use App\Models\AdminUser;
use App\Models\UndangUndang;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        AdminUser::firstOrCreate(
            ['email' => env('CARIPASAL_SUPER_ADMIN_EMAIL', 'superadmin@caripasal.local')],
            [
                'password' => env('CARIPASAL_SUPER_ADMIN_PASSWORD', 'ChangeMe123!'),
                'nama' => env('CARIPASAL_SUPER_ADMIN_NAME', 'Super Admin'),
                'role' => 'super_admin',
                'is_active' => true,
            ],
        );

        UndangUndang::firstOrCreate(
            ['kode' => 'KUHP'],
            [
                'nama' => 'Kitab Undang-Undang Hukum Pidana',
                'nama_lengkap' => 'Kitab Undang-Undang Hukum Pidana',
                'tahun' => 2023,
                'is_active' => true,
            ],
        );
    }
}
