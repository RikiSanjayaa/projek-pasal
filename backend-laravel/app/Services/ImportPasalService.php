<?php

namespace App\Services;

use App\Models\Pasal;
use App\Models\PasalLink;
use App\Models\UndangUndang;
use Illuminate\Http\UploadedFile;
use PhpOffice\PhpSpreadsheet\IOFactory;

class ImportPasalService
{
    public function importRows(array $rows, ?string $adminId = null): array
    {
        $created = 0;
        $updated = 0;
        $errors = [];
        $pasalByRow = [];
        $linkCreated = 0;
        $linkErrors = [];

        foreach ($rows as $index => $row) {
            try {
                $kode = $row['kode_uu'] ?? $row['kode'] ?? null;
                $uuId = $row['undang_undang_id'] ?? null;
                $uu = $uuId ? UndangUndang::find($uuId) : UndangUndang::where('kode', $kode)->first();
                if (! $uu) {
                    throw new \RuntimeException('Undang-undang tidak ditemukan.');
                }

                $payload = [
                    'undang_undang_id' => $uu->id,
                    'nomor' => (string) ($row['nomor'] ?? ''),
                    'judul' => $row['judul'] ?? null,
                    'isi' => (string) ($row['isi'] ?? ''),
                    'penjelasan' => $row['penjelasan'] ?? null,
                    'keywords' => $this->normalizeKeywords($row['keywords'] ?? []),
                    'is_active' => true,
                    'updated_by' => $adminId,
                ];

                if ($payload['nomor'] === '' || $payload['isi'] === '') {
                    throw new \RuntimeException('Nomor dan isi pasal wajib diisi.');
                }

                $pasal = Pasal::updateOrCreate(
                    ['undang_undang_id' => $uu->id, 'nomor' => $payload['nomor']],
                    $payload + ['created_by' => $adminId],
                );

                $pasal->wasRecentlyCreated ? $created++ : $updated++;
                $pasalByRow[$index] = $pasal;
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

                    $targetPasal = Pasal::where('undang_undang_id', $targetUu->id)->where('nomor', (string) $targetNomor)->first();
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

        return compact('created', 'updated', 'errors') + ['links' => ['created' => $linkCreated, 'errors' => $linkErrors]];
    }

    public function importFile(UploadedFile $file, ?string $adminId = null): array
    {
        $sheet = IOFactory::load($file->getRealPath())->getActiveSheet();
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

        return $this->importRows($mapped, $adminId);
    }

    private function normalizeKeywords(mixed $value): array
    {
        if (is_array($value)) {
            return array_values(array_filter(array_map('trim', $value)));
        }

        return array_values(array_filter(array_map('trim', explode(',', (string) $value))));
    }
}
