<?php

namespace App\Services;

use App\Models\ImportRun;
use App\Models\ImportRunItem;
use App\Models\Pasal;
use App\Models\UndangUndang;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;
use Symfony\Component\Process\Exception\ProcessTimedOutException;

/**
 * Menjalankan satu ImportRun: panggil pipeline, bandingkan 3 arah, simpan item.
 * Tidak mengubah tabel pasal; hanya import_runs dan import_run_items.
 */
class ImportRunProcessor
{
    /** Jumlah pasal di sumber tidak boleh turun lebih dari ini dibanding DB (sanity check). */
    private const MAX_DROP_RATIO = 0.02;

    public function __construct(
        private readonly DatahukumPipeline $pipeline,
        private readonly ImportDiffService $diff,
    ) {}

    public function process(ImportRun $run): void
    {
        $run->update(['status' => ImportRun::RUNNING, 'started_at' => now(), 'error' => null]);

        try {
            $previous = Pasal::where('undang_undang_id', $run->undang_undang_id)->count();
            $result = $this->pipeline->fetch($run->slug, $previous);
        } catch (ProcessTimedOutException) {
            $this->fail($run, 'Pengambilan data melewati batas waktu. Coba lagi nanti.');

            return;
        }

        $data = $result['data'];
        if ($result['exit'] === 2) {
            $this->fail($run, (string) ($data['error'] ?? 'Struktur halaman sumber tidak sesuai harapan.'));

            return;
        }
        if ($result['exit'] !== 0) {
            $this->fail($run, 'Pipeline import gagal (kode '.$result['exit'].')'.($result['stderr'] !== '' ? ': '.$result['stderr'] : '.'));

            return;
        }
        if ($data === null || ! is_array($data['pasal'] ?? null)) {
            $this->fail($run, 'Keluaran pipeline bukan JSON yang valid.');

            return;
        }

        $meta = [
            'source_url' => $data['source_url'] ?? null,
            'html_sha256' => $data['html_sha256'] ?? null,
            'warnings' => array_values((array) ($data['warnings'] ?? [])),
            'unknown_versions' => array_values((array) ($data['unknown_versions'] ?? [])),
        ];

        if ($meta['unknown_versions'] !== []) {
            $run->update($meta + [
                'status' => ImportRun::NEEDS_CONFIG,
                'finished_at' => now(),
                'error' => 'Sumber memuat versi UU yang belum dikonfigurasi ('.implode(', ', $meta['unknown_versions']).'). Minta developer menambahkannya di import-tools/laws. Tidak ada data yang diubah.',
            ]);

            return;
        }

        $uu = UndangUndang::find($run->undang_undang_id);
        if (! $uu) {
            $this->fail($run, 'Undang-undang untuk sumber ini tidak ada di database.', $meta);

            return;
        }

        try {
            $current = $this->currentRows($uu->id);
            $dbCount = count(array_filter($current, fn ($row) => ! $row['trashed']));
            $incomingCount = count($data['pasal']);

            if ($dbCount > 0 && $incomingCount < $dbCount * (1 - self::MAX_DROP_RATIO)) {
                $this->fail($run, "Jumlah pasal di sumber turun dari {$dbCount} menjadi {$incomingCount} (lebih dari 2%). Kemungkinan struktur halaman berubah, jadi hasilnya tidak dipakai.", $meta);

                return;
            }

            $items = $this->diff->diff($current, $data['pasal']);
            $summary = $this->diff->summarize($items, $dbCount, $incomingCount);
        } catch (InvalidArgumentException $e) {
            $this->fail($run, $e->getMessage(), $meta);

            return;
        }

        DB::transaction(function () use ($run, $items, $summary, $meta) {
            foreach ($items as $item) {
                ImportRunItem::create($item + ['import_run_id' => $run->id]);
            }
            $run->update($meta + [
                'status' => ImportRun::READY,
                'finished_at' => now(),
                'summary' => $summary,
            ]);
        });
    }

    public function fail(ImportRun $run, string $message, array $extra = []): void
    {
        $run->update($extra + ['status' => ImportRun::FAILED, 'finished_at' => now(), 'error' => $message]);
    }

    /** @return list<array<string, mixed>> */
    private function currentRows(string $undangUndangId): array
    {
        return Pasal::withTrashed()
            ->where('undang_undang_id', $undangUndangId)
            ->with('versi')
            ->get()
            ->map(fn (Pasal $pasal) => [
                'id' => $pasal->id,
                'nomor' => $pasal->nomor,
                'judul' => $pasal->judul,
                'isi' => $pasal->isi,
                'penjelasan' => $pasal->penjelasan,
                'keywords' => $pasal->keywords,
                'snapshot' => $pasal->source_snapshot,
                'trashed' => $pasal->trashed(),
                'riwayat' => $pasal->versi->map(fn ($versi) => [
                    'urutan' => $versi->urutan,
                    'status' => $versi->status,
                    'sumber' => $versi->sumber,
                    'judul_sumber' => $versi->judul_sumber,
                    'diundangkan' => $versi->diundangkan?->format('Y-m-d'),
                    'berlaku_sejak' => $versi->berlaku_sejak?->format('Y-m-d'),
                    'naskah_resmi' => $versi->naskah_resmi,
                    'isi' => $versi->isi,
                    'penjelasan' => $versi->penjelasan,
                ])->all(),
            ])
            ->all();
    }
}
