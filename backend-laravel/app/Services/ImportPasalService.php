<?php

namespace App\Services;

use App\Models\Pasal;
use App\Models\PasalLink;
use App\Models\PasalVersi;
use App\Models\UndangUndang;
use App\Support\PasalTextNormalizer;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;

/**
 * Import xlsx/rows dari dashboard. Sengaja TIDAK mengisi pasal.source_snapshot: snapshot adalah
 * "isi terakhir yang diterapkan dari sumber datahukum" dan hanya diperbarui oleh ImportApplyService.
 * Import xlsx tidak lewat perbandingan 3 arah, jadi hasilnya muncul sebagai "diedit admin" pada
 * pengecekan datahukum berikutnya bila berbeda dari snapshot.
 */
class ImportPasalService
{
    public function importRows(array $rows, ?string $adminId = null): array
    {
        $created = 0;
        $updated = 0;
        $errors = [];
        $needsVerification = 0;
        $pasalByRow = [];
        $linkCreated = 0;
        $linkErrors = [];
        $historyPasal = 0;
        $historyVersions = 0;

        foreach ($rows as $index => $row) {
            try {
                $kode = $row['kode_uu'] ?? $row['kode'] ?? null;
                $uuId = $row['undang_undang_id'] ?? null;
                $uu = $uuId ? UndangUndang::find($uuId) : UndangUndang::where('kode', $kode)->first();
                if (! $uu) {
                    throw new \RuntimeException('Undang-undang tidak ditemukan.');
                }

                $payload = PasalTextNormalizer::normalizePayload([
                    'undang_undang_id' => $uu->id,
                    'nomor' => (string) ($row['nomor'] ?? ''),
                    'judul' => $row['judul'] ?? null,
                    'isi' => (string) ($row['isi'] ?? ''),
                    'penjelasan' => $row['penjelasan'] ?? null,
                    'keywords' => $this->normalizeKeywords($row['keywords'] ?? []),
                    'is_active' => true,
                    'updated_by' => $adminId,
                ]);

                // Kunci "catatan" tidak ada = pertahankan catatan yang sudah tersimpan; ada (termasuk kosong) = timpa.
                // Catatan editorial, bukan teks hukum, jadi tidak ikut memicu verifikasi ulang di bawah.
                if (array_key_exists('catatan', $row)) {
                    $payload['catatan'] = PasalTextNormalizer::normalizeCatatan($row['catatan']);
                }

                if ($payload['nomor'] === '' || $payload['isi'] === '') {
                    throw new \RuntimeException('Nomor dan isi pasal wajib diisi.');
                }

                // Teks hasil import belum tentu sesuai naskah resmi: pasal baru atau yang teksnya
                // berubah masuk antrean verifikasi. Pasal yang teksnya sama mempertahankan statusnya.
                $existing = Pasal::where('undang_undang_id', $uu->id)->where('nomor', $payload['nomor'])->first();
                $textChanged = ! $existing
                    || $existing->isi !== $payload['isi']
                    || $existing->penjelasan !== $payload['penjelasan']
                    || $existing->judul !== $payload['judul'];

                $pasal = Pasal::updateOrCreate(
                    ['undang_undang_id' => $uu->id, 'nomor' => $payload['nomor']],
                    $payload + ['created_by' => $adminId] + ($textChanged ? Pasal::unverified() : []),
                );

                $pasal->wasRecentlyCreated ? $created++ : $updated++;
                if ($textChanged) {
                    $needsVerification++;
                }
                $pasalByRow[$index] = $pasal;

                // Kunci "riwayat" ada = sumber import membawa riwayat lengkap; ganti semua versi lama.
                if (array_key_exists('riwayat', $row) && is_array($row['riwayat'])) {
                    $saved = $this->replaceHistory($pasal, $row['riwayat']);
                    if ($saved > 0) {
                        $historyPasal++;
                        $historyVersions += $saved;
                    }
                }
            } catch (\Throwable $e) {
                $errors[] = ['row' => $index + 1, 'message' => $e->getMessage()];
            }
        }

        foreach ($rows as $index => $row) {
            $sourcePasal = $pasalByRow[$index] ?? null;
            if (! $sourcePasal || empty($row['links']) || ! is_array($row['links'])) {
                continue;
            }

            foreach ($row['links'] as $link) {
                try {
                    $targetKode = $link['targetUU'] ?? $link['target_uu'] ?? $link['kode_uu'] ?? null;
                    $targetNomor = $link['targetNomor'] ?? $link['target_nomor'] ?? $link['nomor'] ?? null;
                    $targetUu = UndangUndang::where('kode', $targetKode)->first();
                    if (! $targetUu || ! $targetNomor) {
                        throw new \RuntimeException('Target link tidak lengkap atau UU target tidak ditemukan.');
                    }

                    $targetPasal = Pasal::where('undang_undang_id', $targetUu->id)
                        ->where('nomor', PasalTextNormalizer::normalizeNomor($targetNomor))
                        ->first();
                    if (! $targetPasal) {
                        throw new \RuntimeException('Pasal target tidak ditemukan.');
                    }

                    PasalLink::updateOrCreate(
                        ['source_pasal_id' => $sourcePasal->id, 'target_pasal_id' => $targetPasal->id],
                        [
                            'keterangan' => $link['keterangan'] ?? null,
                            'is_active' => true,
                            'created_by' => $adminId,
                        ],
                    );
                    $linkCreated++;
                } catch (\Throwable $e) {
                    $linkErrors[] = [
                        'row' => $index + 1,
                        'source' => $sourcePasal->nomor,
                        'target' => ($link['targetUU'] ?? $link['target_uu'] ?? '-').'|'.($link['targetNomor'] ?? $link['target_nomor'] ?? '-'),
                        'message' => $e->getMessage(),
                    ];
                }
            }
        }

        return compact('created', 'updated', 'errors')
            + [
                'needs_verification' => $needsVerification,
                'links' => ['created' => $linkCreated, 'errors' => $linkErrors],
                'riwayat' => ['pasal' => $historyPasal, 'versi' => $historyVersions],
            ];
    }

    public function importFile(UploadedFile $file, ?string $adminId = null, ?string $undangUndangId = null): array
    {
        $workbook = IOFactory::load($file->getRealPath());
        $mapped = $this->sheetRows($workbook->getSheetByName('import') ?? $workbook->getSheet(0));
        if ($undangUndangId) {
            // File hasil pipeline tidak punya kolom kode UU; UU dipilih admin saat upload.
            $mapped = array_map(fn ($item) => $item + ['undang_undang_id' => $undangUndangId], $mapped);
        }

        $historySheet = $workbook->getSheetByName('riwayat');
        if ($historySheet) {
            $history = [];
            foreach ($this->sheetRows($historySheet) as $version) {
                $history[(string) ($version['nomor'] ?? '')][] = $version;
            }
            foreach ($mapped as &$item) {
                $item['riwayat'] = $history[(string) ($item['nomor'] ?? '')] ?? [];
            }
            unset($item);
        }

        return $this->importRows($mapped, $adminId);
    }

    /** @return list<array<string, mixed>> */
    private function sheetRows(Worksheet $sheet): array
    {
        $rows = $sheet->toArray(null, true, true, true);
        $header = array_map(fn ($value) => strtolower(trim((string) $value)), array_shift($rows) ?? []);
        $mapped = [];

        foreach ($rows as $row) {
            $item = [];
            foreach ($header as $column => $field) {
                if ($field !== '') {
                    $item[$field] = $row[$column] ?? null;
                }
            }
            $mapped[] = $item;
        }

        return $mapped;
    }

    /** Simpan ulang seluruh riwayat satu pasal. Mengembalikan jumlah versi yang disimpan. */
    public function replaceHistory(Pasal $pasal, array $versions): int
    {
        $rows = [];
        foreach (array_values($versions) as $position => $version) {
            $status = strtolower(trim((string) ($version['status'] ?? '')));
            if (! in_array($status, PasalVersi::STATUSES, true)) {
                throw new \RuntimeException("Riwayat Pasal {$pasal->nomor}: status \"{$status}\" tidak dikenal.");
            }
            $sumber = trim((string) ($version['sumber'] ?? ''));
            $text = PasalTextNormalizer::normalizePayload([
                'isi' => (string) ($version['isi'] ?? ''),
                'penjelasan' => $version['penjelasan'] ?? null,
            ]);
            if ($sumber === '' || $text['isi'] === '') {
                throw new \RuntimeException("Riwayat Pasal {$pasal->nomor}: sumber dan isi wajib diisi.");
            }

            $rows[] = [
                'urutan' => (int) ($version['urutan'] ?? 0) ?: $position + 1,
                'status' => $status,
                'sumber' => $sumber,
                'judul_sumber' => $this->nullableString($version['judul_sumber'] ?? null),
                'diundangkan' => $this->nullableString($version['diundangkan'] ?? null),
                'berlaku_sejak' => $this->nullableString($version['berlaku_sejak'] ?? null),
                'naskah_resmi' => $this->nullableString($version['naskah_resmi'] ?? null),
                'isi' => $text['isi'],
                'penjelasan' => $text['penjelasan'] ?: null,
            ];
        }

        // Import ulang dengan riwayat yang sama tidak boleh menyentuh pasal (memicu sync ulang di mobile).
        $fields = array_keys($rows[0] ?? ['urutan' => null]);
        $existing = $pasal->versi()->get()
            ->map(fn (PasalVersi $versi) => array_map(
                fn ($value) => $value instanceof \DateTimeInterface ? $value->format('Y-m-d') : $value,
                $versi->only($fields),
            ))
            ->all();
        if ($existing == $rows) {
            return count($rows);
        }

        DB::transaction(function () use ($pasal, $rows) {
            $pasal->versi()->delete();
            foreach ($rows as $row) {
                $pasal->versi()->create($row);
            }
            $pasal->touch();
        });

        return count($rows);
    }

    private function nullableString(mixed $value): ?string
    {
        $value = trim((string) ($value ?? ''));

        return $value === '' ? null : $value;
    }

    private function normalizeKeywords(mixed $value): array
    {
        if (is_array($value)) {
            return array_values(array_filter(array_map('trim', $value)));
        }

        return array_values(array_filter(array_map('trim', explode(',', (string) $value))));
    }
}
