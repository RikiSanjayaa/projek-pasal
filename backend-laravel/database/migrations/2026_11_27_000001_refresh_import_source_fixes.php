<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Menyelaraskan konfigurasi impor yang sudah tersimpan dengan teks datahukum.com saat ini.
 *
 * Setiap perubahan hanya diterapkan kalau nilai tersimpan masih persis nilai lama, jadi suntingan
 * pengelola lewat panel tidak tertimpa. Konfigurasi baru untuk instalasi bersih ada di
 * database/data/import_sources.json.
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->patch('kuhp-2023', function (array $config): array {
            // Sumber menandai anotasi Putusan MK dengan class sendiri, bukan versi UU.
            $config['annotation_classes'] = ['MK2822025', 'MK272026', 'un'];

            $old90 = [
                ['isi', "\nKetentuan sebagaimana dimaksud pada ayat (1) huruf b", "\n(2) Ketentuan sebagaimana dimaksud pada ayat (1) huruf b"],
                ['isi', "\n(2) Pidana pencabutan hak mulai berlaku", "\n(3) Pidana pencabutan hak mulai berlaku"],
            ];
            $new90 = [
                ['isi', 'paling lama 5 (lima) tahun. Ketentuan sebagaimana dimaksud pada ayat (1) huruf b', "paling lama 5 (lima) tahun.\n(2) Ketentuan sebagaimana dimaksud pada ayat (1) huruf b"],
                ['isi', "\n(2) Pidana pencabutan hak mulai berlaku", "\n(3) Pidana pencabutan hak mulai berlaku"],
            ];
            if (($config['text_fixes']['90'] ?? null) === $old90) {
                $config['text_fixes']['90'] = $new90;
            }

            $config['text_fixes']['622'] = $this->replaceEntry(
                $config['text_fixes']['622'] ?? [],
                ['isi', "\nCC. ", "\ncc. "],
                ['isi', 'CC. Pasal 37', 'cc. Pasal 37'],
            );

            return $config;
        });

        $this->patch('uu-ite-2008', function (array $config): array {
            $versionFixes = $config['version_fixes'] ?? [];

            // Artefak OCR sudah berbentuk satu baris setelah pembersihan teks.
            $versionFixes['1'] = $this->replaceEntry(
                $versionFixes['1'] ?? [],
                ['uu-192016', 'isi', "surat elektronik\n!electronic mni9,", 'surat elektronik (electronic mail),'],
                ['uu-192016', 'isi', 'surat elektronik !electronic mni9,', 'surat elektronik (electronic mail),'],
            );

            // Teks sumber sudah diperbaiki, jadi perbaikan lama tidak punya sasaran lagi.
            $obsolete = [
                '13A' => [['uu-12024', 'penjelasan', 'bukti lerkait', 'bukti terkait']],
                '16A' => [
                    ['uu-12024', 'penjelasan', 'dan fAur yang', 'dan fitur yang'],
                    ['uu-12024', 'penjelasan', 'maupon psikis', 'maupun psikis'],
                ],
                '18A' => [['uu-12024', 'penjelasan', 'klausola baku', 'klausula baku']],
                '40A' => [
                    ['uu-12024', 'penjelasan', 'penambahan fltur', 'penambahan fitur'],
                    ['uu-12024', 'penjelasan', 'me ujudkan', 'mewujudkan'],
                ],
                '45' => [['uu-12024', 'isi', '(empat) tahon', '(empat) tahun']],
                '45A' => [['uu-12024', 'isi', '(3) Setiap Orang yang dengan sengaja dan tanpa hak mendistribusikan', '(2) Setiap Orang yang dengan sengaja dan tanpa hak mendistribusikan']],
                '45B' => [['uu-192016', 'penjelasan', '!cyber btt!Iying) yang mengandurig susar ancaman kekerasan atau meriakut-nakuti', '(cyber bullying) yang mengandung unsur ancaman kekerasan atau menakut-nakuti']],
            ];
            foreach ($obsolete as $nomor => $entries) {
                foreach ($entries as $entry) {
                    if (! array_key_exists($nomor, $versionFixes)) {
                        continue;
                    }
                    $versionFixes[$nomor] = array_values(array_filter(
                        $versionFixes[$nomor],
                        fn ($fix) => $fix !== $entry,
                    ));
                    if ($versionFixes[$nomor] === []) {
                        unset($versionFixes[$nomor]);
                    }
                }
            }
            $config['version_fixes'] = $versionFixes;

            return $config;
        });
    }

    public function down(): void
    {
        // Perbaikan konfigurasi bersifat maju saja; teks lama tidak dipulihkan otomatis.
    }

    /** @param callable(array): array $patch */
    private function patch(string $slug, callable $patch): void
    {
        $row = DB::table('import_sources')->where('slug', $slug)->first();
        if ($row === null) {
            return;
        }

        $config = json_decode((string) $row->config, true);
        if (! is_array($config)) {
            return;
        }

        $next = $patch($config);
        if ($next === $config) {
            return;
        }

        DB::table('import_sources')->where('slug', $slug)->update([
            'config' => json_encode($next, JSON_THROW_ON_ERROR),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param  list<array<int, string>>  $entries
     * @param  array<int, string>  $old
     * @param  array<int, string>  $new
     * @return list<array<int, string>>
     */
    private function replaceEntry(array $entries, array $old, array $new): array
    {
        if (! in_array($old, $entries, true)) {
            return $entries;
        }

        return array_values(array_map(fn ($entry) => $entry === $old ? $new : $entry, $entries));
    }
};
