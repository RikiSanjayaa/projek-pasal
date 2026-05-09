<?php

namespace Database\Seeders;

use App\Models\AdminUser;
use App\Models\Pasal;
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
        $admin = AdminUser::updateOrCreate(
            [
                "email" => env(
                    "CARIPASAL_SUPER_ADMIN_EMAIL",
                    "superadmin@caripasal.local",
                ),
            ],
            [
                "password" => env(
                    "CARIPASAL_SUPER_ADMIN_PASSWORD",
                    "ChangeMe123!",
                ),
                "nama" => env("CARIPASAL_SUPER_ADMIN_NAME", "Super Admin"),
                "role" => "super_admin",
                "is_active" => true,
            ],
        );

        $undangUndang = collect([
            [
                "kode" => "KUHP",
                "nama" => "Kitab Undang-Undang Hukum Pidana",
                "nama_lengkap" =>
                    "Undang-Undang Nomor 1 Tahun 2023 tentang Kitab Undang-Undang Hukum Pidana",
                "deskripsi" =>
                    "KUHP nasional terbaru sebagai rujukan utama pasal pidana umum.",
                "tahun" => 2023,
                "is_active" => true,
            ],
            [
                "kode" => "KUHAP",
                "nama" => "Kitab Undang-Undang Hukum Acara Pidana",
                "nama_lengkap" =>
                    "Undang-Undang Nomor 8 Tahun 1981 tentang Hukum Acara Pidana",
                "deskripsi" =>
                    "Kerangka hukum acara pidana untuk melengkapi referensi pidana materiil.",
                "tahun" => 1981,
                "is_active" => true,
            ],
            [
                "kode" => "UU_ITE",
                "nama" => "Undang-Undang Informasi dan Transaksi Elektronik",
                "nama_lengkap" =>
                    "Undang-Undang Nomor 11 Tahun 2008 tentang Informasi dan Transaksi Elektronik beserta perubahannya",
                "deskripsi" =>
                    "Referensi hukum untuk informasi elektronik, transaksi elektronik, dan delik digital.",
                "tahun" => 2008,
                "is_active" => true,
            ],
        ])->mapWithKeys(function (array $item) {
            $record = UndangUndang::updateOrCreate(
                ["kode" => $item["kode"]],
                $item,
            );

            return [$item["kode"] => $record];
        });

        foreach (
            [
                [
                    "nomor" => "Pasal 1",
                    "judul" => "Asas legalitas",
                    "isi" =>
                        "Tiada seorang pun dapat dipidana atau dikenai tindakan, kecuali perbuatan yang dilakukan telah ditetapkan sebagai tindak pidana dalam peraturan perundang-undangan yang berlaku pada saat perbuatan itu dilakukan.",
                    "penjelasan" =>
                        "Pasal ini menegaskan asas legalitas sebagai dasar utama pemidanaan dalam KUHP nasional.",
                    "keywords" => [
                        "asas legalitas",
                        "pemidanaan",
                        "ketentuan umum",
                    ],
                ],
                [
                    "nomor" => "Pasal 2",
                    "judul" => "Hukum yang hidup dalam masyarakat",
                    "isi" =>
                        "Hukum yang hidup dalam masyarakat dapat menjadi dasar pemidanaan sepanjang sesuai dengan nilai Pancasila, Undang-Undang Dasar Negara Republik Indonesia Tahun 1945, hak asasi manusia, dan asas hukum umum yang diakui masyarakat bangsa-bangsa.",
                    "penjelasan" =>
                        "Pasal ini membuka ruang pengakuan terhadap hukum yang hidup dengan pembatasan konstitusional dan HAM.",
                    "keywords" => ["hukum adat", "living law", "asas hukum"],
                ],
                [
                    "nomor" => "Pasal 23",
                    "judul" => "Pertanggungjawaban pidana",
                    "isi" =>
                        "Setiap orang yang melakukan tindak pidana dipertanggungjawabkan atas perbuatannya apabila pada waktu melakukan tindak pidana tersebut memiliki kesalahan.",
                    "penjelasan" =>
                        "Rumusan ini menempatkan kesalahan sebagai syarat pokok pertanggungjawaban pidana.",
                    "keywords" => [
                        "kesalahan",
                        "pertanggungjawaban pidana",
                        "unsur pidana",
                    ],
                ],
                [
                    "nomor" => "Pasal 37",
                    "judul" => "Tujuan pemidanaan",
                    "isi" =>
                        "Pemidanaan bertujuan mencegah tindak pidana, memasyarakatkan terpidana dengan pembinaan, menyelesaikan konflik akibat tindak pidana, memulihkan keseimbangan, serta menumbuhkan rasa penyesalan pada terpidana.",
                    "penjelasan" =>
                        "Pasal ini menegaskan orientasi pemidanaan yang tidak semata-mata bersifat pembalasan.",
                    "keywords" => [
                        "tujuan pemidanaan",
                        "restoratif",
                        "pembinaan",
                    ],
                ],
                [
                    "nomor" => "Pasal 38",
                    "judul" => "Larangan merendahkan martabat manusia",
                    "isi" =>
                        "Pemidanaan tidak dimaksudkan untuk menderitakan dan tidak diperkenankan merendahkan martabat manusia.",
                    "penjelasan" =>
                        "Prinsip ini menjadi batas etis dalam penjatuhan dan pelaksanaan pidana.",
                    "keywords" => [
                        "martabat manusia",
                        "pidana",
                        "hak asasi manusia",
                    ],
                ],
                [
                    "nomor" => "Pasal 218",
                    "judul" => "Penyerangan harkat dan martabat Presiden",
                    "isi" =>
                        "Setiap orang yang di muka umum menyerang kehormatan atau harkat dan martabat diri Presiden atau Wakil Presiden dipidana dengan pidana penjara paling lama 3 tahun 6 bulan atau pidana denda paling banyak kategori IV.",
                    "penjelasan" =>
                        "Contoh pasal delik aduan yang sering menjadi perhatian publik dalam pembahasan KUHP baru.",
                    "keywords" => ["presiden", "penghinaan", "delik aduan"],
                ],
                [
                    "nomor" => "Pasal 240",
                    "judul" => "Penyiaran berita bohong",
                    "isi" =>
                        "Setiap orang yang menyiarkan atau menyebarluaskan berita atau pemberitahuan bohong yang menimbulkan keonaran dalam masyarakat dipidana dengan pidana penjara paling lama 6 tahun atau pidana denda paling banyak kategori V.",
                    "penjelasan" =>
                        "Pasal ini relevan untuk simulasi pencarian isu hoaks dan gangguan ketertiban umum.",
                    "keywords" => [
                        "berita bohong",
                        "keonaran",
                        "ketertiban umum",
                    ],
                ],
                [
                    "nomor" => "Pasal 408",
                    "judul" => "Pencurian",
                    "isi" =>
                        "Setiap orang yang mengambil barang yang seluruhnya atau sebagian milik orang lain dengan maksud untuk memiliki secara melawan hukum dipidana karena pencurian dengan pidana penjara paling lama 5 tahun atau pidana denda paling banyak kategori V.",
                    "penjelasan" =>
                        "Rumusan dasar tindak pidana pencurian untuk kebutuhan contoh pasal yang umum dicari.",
                    "keywords" => [
                        "pencurian",
                        "mengambil barang",
                        "melawan hukum",
                    ],
                ],
                [
                    "nomor" => "Pasal 459",
                    "judul" => "Penipuan",
                    "isi" =>
                        "Setiap orang yang dengan maksud menguntungkan diri sendiri atau orang lain secara melawan hukum, memakai nama palsu, martabat palsu, tipu muslihat, atau rangkaian kebohongan untuk menggerakkan orang supaya menyerahkan barang, memberi utang, atau menghapuskan piutang dipidana karena penipuan.",
                    "penjelasan" =>
                        "Pasal ini mewakili tindak pidana penipuan yang sering dicari dalam praktik sehari-hari.",
                    "keywords" => [
                        "penipuan",
                        "tipu muslihat",
                        "rangkaian kebohongan",
                    ],
                ],
                [
                    "nomor" => "Pasal 473",
                    "judul" => "Penggelapan",
                    "isi" =>
                        "Setiap orang yang secara melawan hukum memiliki barang yang seluruhnya atau sebagian milik orang lain yang berada dalam penguasaannya bukan karena tindak pidana dipidana karena penggelapan.",
                    "penjelasan" =>
                        "Pasal penggelapan berguna sebagai pembanding terhadap pencurian dan penipuan.",
                    "keywords" => [
                        "penggelapan",
                        "penguasaan barang",
                        "melawan hukum",
                    ],
                ],
            ]
            as $pasal
        ) {
            Pasal::updateOrCreate(
                [
                    "undang_undang_id" => $undangUndang["KUHP"]->id,
                    "nomor" => $pasal["nomor"],
                ],
                $pasal + [
                    "undang_undang_id" => $undangUndang["KUHP"]->id,
                    "is_active" => true,
                    "created_by" => $admin->id,
                    "updated_by" => $admin->id,
                ],
            );
        }
    }
}
