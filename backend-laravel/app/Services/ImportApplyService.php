<?php

namespace App\Services;

use App\Models\ImportRun;
use App\Models\ImportRunItem;
use App\Models\Pasal;
use App\Models\PasalLink;
use App\Models\UndangUndang;
use App\Support\PasalTextNormalizer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Menerapkan item terpilih dari run yang berstatus ready, dalam satu transaksi.
 *
 * - baru: buat pasal (atau pulihkan dari Sampah), perlu_verifikasi.
 * - berubah/konflik: ganti judul/isi/penjelasan/keywords; perlu_verifikasi jika teksnya berubah.
 * - riwayat: ganti seluruh riwayat versi pasal.
 * - hilang: hanya diakui, tidak ada yang dihapus.
 * Untuk item yang diterapkan: link otomatis ("Disebut dalam isi") disinkronkan dan source_snapshot diperbarui.
 * Item yang datanya sudah berubah sejak run dibuat dilewati, bukan ditimpa.
 */
class ImportApplyService
{
    public const AUTO_LINK_PREFIX = 'Disebut dalam isi';

    public function __construct(
        private readonly ImportDiffService $diff,
        private readonly ImportPasalService $importer,
        private readonly AuditService $audit,
    ) {}

    public function apply(ImportRun $run, Request $request): ImportRun
    {
        $adminId = $request->user()?->id;

        return DB::transaction(function () use ($run, $request, $adminId) {
            $locked = ImportRun::whereKey($run->id)->lockForUpdate()->firstOrFail();
            if ($locked->status !== ImportRun::READY) {
                abort(409, 'Run ini sudah tidak bisa diterapkan (status: '.$locked->status.').');
            }

            $stats = ['diterapkan' => 0, 'dilewati' => 0, 'diakui' => 0, 'link_ditambah' => 0, 'link_dihapus' => 0];
            $linkWork = [];

            $items = $locked->items()->where('selected', true)->whereIn('category', ImportDiffService::SELECTABLE)->get();
            foreach ($items as $item) {
                $pasal = match ($item->category) {
                    ImportDiffService::BARU => $this->applyBaru($locked, $item, $adminId),
                    ImportDiffService::BERUBAH, ImportDiffService::KONFLIK => $this->applyTeks($locked, $item, $adminId),
                    ImportDiffService::RIWAYAT => $this->applyRiwayat($locked, $item),
                    default => null,
                };

                if ($item->category === ImportDiffService::HILANG) {
                    $this->finish($item, 'Diakui. Pasal tidak dihapus.');
                    $stats['diakui']++;
                } elseif ($pasal === null) {
                    $stats['dilewati']++;
                } else {
                    $this->finish($item);
                    $stats['diterapkan']++;
                    if ($item->incoming_links !== null) {
                        $linkWork[] = [$pasal, $item->incoming_links];
                    }
                }
            }

            // Link setelah semua pasal ada, karena target bisa berupa pasal baru dari run yang sama.
            foreach ($linkWork as [$pasal, $links]) {
                [$added, $removed] = $this->syncAutoLinks($pasal, $links, $adminId);
                $stats['link_ditambah'] += $added;
                $stats['link_dihapus'] += $removed;
            }

            $locked->update([
                'status' => ImportRun::APPLIED,
                'applied_by' => $adminId,
                'applied_at' => now(),
                'summary' => ($locked->summary ?? []) + ['applied' => $stats],
            ]);

            $this->audit->log($request, 'IMPORT', 'import_runs', $locked->id, null, null, [
                'run_id' => $locked->id,
                'slug' => $locked->slug,
                'undang_undang_id' => $locked->undang_undang_id,
                'html_sha256' => $locked->html_sha256,
            ] + $stats);

            return $locked->fresh();
        });
    }

    private function applyBaru(ImportRun $run, ImportRunItem $item, ?string $adminId): ?Pasal
    {
        $incoming = $item->incoming;
        $existing = Pasal::withTrashed()
            ->where('undang_undang_id', $run->undang_undang_id)
            ->where('nomor', $item->nomor)
            ->first();

        if ($existing && ! $existing->trashed()) {
            $this->finish($item, 'Dilewati: pasal ini sudah ada sejak run dibuat.', false);

            return null;
        }

        $attributes = $this->textAttributes($incoming) + Pasal::unverified() + [
            'is_active' => true,
            'updated_by' => $adminId,
            'source_snapshot' => $this->snapshot($run, $incoming),
        ];

        if ($existing) {
            $existing->restore();
            $existing->update($attributes);
            $pasal = $existing;
        } else {
            $pasal = Pasal::create($attributes + [
                'undang_undang_id' => $run->undang_undang_id,
                'nomor' => $item->nomor,
                'created_by' => $adminId,
            ]);
        }
        $item->pasal_id = $pasal->id;

        $this->replaceRiwayat($pasal, $item);

        return $pasal;
    }

    private function applyTeks(ImportRun $run, ImportRunItem $item, ?string $adminId): ?Pasal
    {
        $pasal = $this->liveGuard($run, $item);
        if (! $pasal) {
            return null;
        }

        $incoming = $item->incoming;
        $live = $this->diff->snap($pasal->only(['judul', 'isi', 'penjelasan', 'keywords']));
        $textChanged = $live['judul'] !== $incoming['judul']
            || $live['isi'] !== $incoming['isi']
            || $live['penjelasan'] !== $incoming['penjelasan'];

        $pasal->update($this->textAttributes($incoming) + ($textChanged ? Pasal::unverified() : []) + [
            'updated_by' => $adminId,
            'source_snapshot' => $this->snapshot($run, $incoming),
        ]);
        $this->replaceRiwayat($pasal, $item);

        return $pasal;
    }

    private function applyRiwayat(ImportRun $run, ImportRunItem $item): ?Pasal
    {
        $pasal = $this->liveGuard($run, $item);
        if (! $pasal) {
            return null;
        }

        $pasal->update(['source_snapshot' => $this->snapshot($run, $item->incoming)]);
        $this->replaceRiwayat($pasal, $item);

        return $pasal;
    }

    /** Pasal yang masih sama dengan saat run dibuat; selain itu dilewati dan dicatat pada item. */
    private function liveGuard(ImportRun $run, ImportRunItem $item): ?Pasal
    {
        $pasal = $item->pasal_id ? Pasal::find($item->pasal_id) : null;
        if (! $pasal) {
            $this->finish($item, 'Dilewati: pasal tidak ditemukan atau sudah dihapus sejak run dibuat.', false);

            return null;
        }

        if ($item->category !== ImportDiffService::RIWAYAT) {
            $live = $pasal->only(['judul', 'isi', 'penjelasan', 'keywords']);
            if (! $this->diff->same($live, $item->current) && ! $this->diff->same($live, $item->incoming)) {
                $this->finish($item, 'Dilewati: pasal diedit sejak run dibuat. Periksa ulang lewat run baru.', false);

                return null;
            }
        }

        return $pasal;
    }

    private function replaceRiwayat(Pasal $pasal, ImportRunItem $item): void
    {
        // Sumber tanpa riwayat tidak menghapus riwayat yang ada (lihat ImportDiffService).
        if (! empty($item->incoming_riwayat)) {
            $this->importer->replaceHistory($pasal, $item->incoming_riwayat);
        }
    }

    /** @param array<string, mixed> $incoming */
    private function textAttributes(array $incoming): array
    {
        return [
            'judul' => $incoming['judul'],
            'isi' => $incoming['isi'],
            'penjelasan' => $incoming['penjelasan'],
            'keywords' => $incoming['keywords'],
        ];
    }

    /** @param array<string, mixed> $incoming */
    private function snapshot(ImportRun $run, array $incoming): array
    {
        return $this->textAttributes($incoming) + ['run_id' => $run->id, 'hash' => $run->html_sha256];
    }

    private function finish(ImportRunItem $item, ?string $note = null, bool $applied = true): void
    {
        $notes = $item->notes ?? [];
        if ($note) {
            $notes[] = $note;
        }
        $item->notes = $notes;
        $item->applied_at = $applied ? now() : null;
        $item->save();
    }

    /**
     * Samakan link otomatis satu pasal dengan hasil sumber. Link buatan admin (keterangan lain) tidak disentuh,
     * dan link yang pernah dihapus admin tidak dihidupkan lagi.
     *
     * @param  list<array<string, mixed>>  $links
     * @return array{0: int, 1: int} [ditambah, dihapus]
     */
    private function syncAutoLinks(Pasal $source, array $links, ?string $adminId): array
    {
        $desired = [];
        foreach ($links as $link) {
            $kode = $link['targetUU'] ?? $link['target_uu'] ?? null;
            $nomor = $link['targetNomor'] ?? $link['target_nomor'] ?? null;
            if (! $kode || ! $nomor) {
                continue;
            }
            $uu = UndangUndang::where('kode', $kode)->first();
            $target = $uu ? Pasal::where('undang_undang_id', $uu->id)->where('nomor', PasalTextNormalizer::normalizeNomor($nomor))->first() : null;
            if (! $target || $target->id === $source->id) {
                continue;
            }
            $desired[$target->id] ??= (string) ($link['keterangan'] ?? self::AUTO_LINK_PREFIX);
        }

        $added = 0;
        $removed = 0;
        $existing = PasalLink::withTrashed()->where('source_pasal_id', $source->id)->get()->keyBy('target_pasal_id');

        foreach ($existing as $targetId => $link) {
            if ($link->trashed() || ! $this->isAuto($link) || isset($desired[$targetId])) {
                continue;
            }
            $link->delete();
            $removed++;
        }

        foreach ($desired as $targetId => $keterangan) {
            $link = $existing->get($targetId);
            if (! $link) {
                PasalLink::create([
                    'source_pasal_id' => $source->id,
                    'target_pasal_id' => $targetId,
                    'keterangan' => $keterangan,
                    'is_active' => true,
                    'created_by' => $adminId,
                ]);
                $added++;
            } elseif (! $link->trashed() && $this->isAuto($link) && $link->keterangan !== $keterangan) {
                $link->update(['keterangan' => $keterangan]);
            }
        }

        return [$added, $removed];
    }

    private function isAuto(PasalLink $link): bool
    {
        return str_starts_with((string) $link->keterangan, self::AUTO_LINK_PREFIX);
    }
}
