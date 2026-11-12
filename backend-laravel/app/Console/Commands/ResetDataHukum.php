<?php

namespace App\Console\Commands;

use App\Models\AdminUser;
use App\Models\ImportSource;
use App\Models\Pasal;
use App\Models\UndangUndang;
use App\Services\ImportPasalService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Migrasi data satu kali untuk server yang masih berisi data lama (nomor "Pasal 1", kata kunci
 * lama): semua pasal dihapus permanen lalu diisi ulang dari data-import/<slug>/*.xlsx.
 *
 * Penghapusan permanen aman untuk perangkat: aplikasi versi ini selalu melakukan sync penuh
 * (mengosongkan database lokal) pada pembukaan pertama, karena versi data sync-nya naik.
 */
class ResetDataHukum extends Command
{
    protected $signature = 'caripasal:reset-data-hukum
        {--dir= : Folder data-import (default: data-import di root repo)}
        {--force : Jalankan tanpa pertanyaan konfirmasi}';

    protected $description = 'Hapus permanen semua pasal, lalu import ulang dari data-import/*.xlsx (sekali saat pindah dari data lama)';

    public function handle(ImportPasalService $importer): int
    {
        $dir = rtrim($this->option('dir') ?: dirname(base_path()).'/data-import', '/\\');
        $sources = ImportSource::with('undangUndang')->orderBy('slug')->get();
        if ($sources->isEmpty()) {
            $this->error('Tabel import_sources kosong. Jalankan php artisan migrate --force dulu.');

            return self::FAILURE;
        }

        $files = [];
        foreach ($sources as $source) {
            $found = glob("{$dir}/{$source->slug}/*.xlsx") ?: [];
            if (count($found) !== 1) {
                $this->error("Harus ada tepat satu file .xlsx di {$dir}/{$source->slug}, ditemukan ".count($found).'.');

                return self::FAILURE;
            }
            $files[$source->slug] = $found[0];
        }

        $verified = Pasal::withTrashed()->where('verification_status', Pasal::VERIFIED)->count();
        if ($verified > 0) {
            $this->error("Dibatalkan: {$verified} pasal sudah diverifikasi admin. Reset hanya untuk data lama yang belum pernah diverifikasi.");

            return self::FAILURE;
        }

        $this->info('Data yang akan dihapus permanen:');
        $this->table(['Kode', 'Pasal (termasuk Sampah)', 'Dipertahankan'], UndangUndang::withTrashed()
            ->withCount(['pasal as total' => fn ($query) => $query->withTrashed()])
            ->orderBy('kode')
            ->get()
            ->map(fn (UndangUndang $uu) => [$uu->kode, $uu->total, $sources->contains('undang_undang_id', $uu->id) ? 'UU tetap, pasal diganti' : 'UU dihapus'])
            ->all());

        if (! $this->option('force') && ! $this->confirm('Hapus semua pasal di atas lalu import ulang dari '.$dir.'?')) {
            $this->warn('Dibatalkan, tidak ada yang diubah.');

            return self::FAILURE;
        }

        $adminId = AdminUser::where('email', config('caripasal.super_admin.email'))->value('id');

        try {
            $summary = DB::transaction(function () use ($sources, $files, $importer, $adminId) {
                // pasal_links dan pasal_versi ikut terhapus lewat ON DELETE CASCADE.
                DB::table('pasal')->delete();
                UndangUndang::whereNotIn('id', $sources->pluck('undang_undang_id'))->get()->each->delete();

                $summary = [];
                foreach ($sources as $source) {
                    $uu = $source->undangUndang;
                    if ($uu->trashed()) {
                        $uu->restore();
                    }
                    $uu->update(['is_active' => true]);

                    $this->line("Import {$uu->kode} dari ".basename($files[$source->slug]).' ...');
                    $result = $importer->importPath($files[$source->slug], $adminId, $uu->id);
                    $errors = array_merge(
                        array_map(fn ($e) => "baris {$e['row']}: {$e['message']}", $result['errors']),
                        array_map(fn ($e) => "link {$e['source']} -> {$e['target']}: {$e['message']}", $result['links']['errors']),
                    );
                    if ($errors !== []) {
                        throw new \RuntimeException("{$uu->kode}: ".count($errors).' error, contoh '.$errors[0]);
                    }
                    $summary[] = [$uu->kode, $result['created'] + $result['updated'], $result['links']['created'], $result['riwayat']['versi']];
                }

                return $summary;
            });
        } catch (\Throwable $e) {
            $this->error('Gagal, semua perubahan dibatalkan (database kembali seperti sebelum perintah): '.$e->getMessage());

            return self::FAILURE;
        }

        $this->info('Selesai. Semua pasal berstatus "Perlu verifikasi".');
        $this->table(['Kode', 'Pasal', 'Link', 'Versi riwayat'], $summary);

        return self::SUCCESS;
    }
}
