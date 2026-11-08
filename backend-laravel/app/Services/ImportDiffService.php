<?php

namespace App\Services;

use App\Support\PasalTextNormalizer;
use InvalidArgumentException;

/**
 * Perbandingan 3 arah untuk import datahukum: snapshot sumber terakhir (base), data sekarang (current),
 * dan sumber baru (incoming). Fungsi murni: array masuk, array keluar, tanpa database.
 *
 * Bentuk masukan `current` (satu elemen per pasal di DB, termasuk yang di Sampah):
 *   ['id', 'nomor', 'judul', 'isi', 'penjelasan', 'catatan', 'keywords' => [], 'snapshot' => array|null,
 *    'riwayat' => [baris pasal_versi], 'trashed' => bool]
 * Bentuk masukan `incoming`: elemen `pasal` dari keluaran pipeline (lihat prepare_import.py --json).
 */
class ImportDiffService
{
    public const BARU = 'baru';

    public const HILANG = 'hilang';

    public const KONFLIK = 'konflik';

    public const BERUBAH = 'berubah';

    public const DIEDIT_ADMIN = 'diedit_admin';

    public const RIWAYAT = 'riwayat';

    public const CATEGORIES = [self::BARU, self::HILANG, self::KONFLIK, self::BERUBAH, self::DIEDIT_ADMIN, self::RIWAYAT];

    /** Kategori yang bisa dipilih admin untuk diterapkan. diedit_admin hanya informasi. */
    public const SELECTABLE = [self::BARU, self::HILANG, self::KONFLIK, self::BERUBAH, self::RIWAYAT];

    private const SELECTED_BY_DEFAULT = [self::BARU, self::BERUBAH, self::RIWAYAT];

    private const RIWAYAT_FIELDS = ['urutan', 'status', 'sumber', 'judul_sumber', 'diundangkan', 'berlaku_sejak', 'naskah_resmi', 'isi', 'penjelasan'];

    /**
     * @param  list<array<string, mixed>>  $current
     * @param  list<array<string, mixed>>  $incoming
     * @return list<array<string, mixed>> item siap disimpan; pasal yang sama di ketiganya tidak muncul
     */
    public function diff(array $current, array $incoming): array
    {
        $currentByNomor = [];
        foreach ($current as $row) {
            $currentByNomor[(string) $row['nomor']] = $row;
        }

        $items = [];
        $seen = [];
        $order = 0;

        foreach ($incoming as $row) {
            $payload = PasalTextNormalizer::normalizePayload([
                'nomor' => (string) ($row['nomor'] ?? ''),
                'judul' => $row['judul'] ?? null,
                'isi' => (string) ($row['isi'] ?? ''),
                'penjelasan' => $row['penjelasan'] ?? null,
                'catatan' => $row['catatan'] ?? null,
            ]);
            $nomor = $payload['nomor'];
            if ($nomor === '' || $payload['isi'] === '') {
                throw new InvalidArgumentException('Sumber memuat pasal tanpa nomor atau isi'.($nomor !== '' ? " (Pasal {$nomor})" : '').'.');
            }
            if (isset($seen[$nomor])) {
                throw new InvalidArgumentException("Sumber memuat Pasal {$nomor} lebih dari sekali.");
            }
            $seen[$nomor] = true;
            $order++;

            $incomingSnap = $this->snap($payload + ['keywords' => $row['keywords'] ?? []]);
            $incomingRiwayat = self::normalizeRiwayat((array) ($row['riwayat'] ?? []));
            $review = isset($row['review']) && is_array($row['review']) ? $row['review'] : null;
            $links = array_values((array) ($row['links'] ?? []));

            $item = $this->classify($currentByNomor[$nomor] ?? null, $incomingSnap, $incomingRiwayat);
            if ($item === null) {
                continue;
            }

            $items[] = $item + [
                'nomor' => $nomor,
                'incoming' => $incomingSnap,
                'incoming_riwayat' => $incomingRiwayat === [] ? null : $incomingRiwayat,
                'incoming_links' => $links,
                'review' => $review,
                'sort_key' => $order,
            ];
        }

        foreach ($current as $row) {
            $nomor = (string) $row['nomor'];
            if (isset($seen[$nomor]) || ! empty($row['trashed'])) {
                continue;
            }
            $order++;
            $snapshot = isset($row['snapshot']) && is_array($row['snapshot']) ? $this->snap($row['snapshot']) : null;
            $items[] = [
                'nomor' => $nomor,
                'pasal_id' => $row['id'] ?? null,
                'category' => self::HILANG,
                'selected' => false,
                'base' => $snapshot,
                'current' => $this->snap($row),
                'incoming' => null,
                'incoming_riwayat' => null,
                'current_riwayat' => self::normalizeRiwayat((array) ($row['riwayat'] ?? [])) ?: null,
                'incoming_links' => null,
                'review' => null,
                'notes' => [$snapshot === null
                    ? 'Pasal tidak ada di sumber dan tidak punya snapshot sumber (kemungkinan dibuat manual). Tidak akan dihapus.'
                    : 'Pasal tidak ada lagi di sumber. Tidak akan dihapus otomatis.'],
                'sort_key' => $order,
            ];
        }

        return $items;
    }

    /**
     * @param  list<array<string, mixed>>  $items keluaran diff()
     * @return array{counts: array<string, int>, selected: int, total_pasal: int, large_change: bool, pdf_flagged: int}
     */
    public function summarize(array $items, int $dbPasalCount, int $totalPasal): array
    {
        $counts = array_fill_keys(self::CATEGORIES, 0);
        $selected = 0;
        $pdfFlagged = 0;
        foreach ($items as $item) {
            $counts[$item['category']]++;
            $selected += ! empty($item['selected']) ? 1 : 0;
            $pdfFlagged += ! empty($item['review']['perlu_review']) ? 1 : 0;
        }

        $changed = $counts[self::BERUBAH] + $counts[self::KONFLIK] + $counts[self::BARU] + $counts[self::HILANG];
        $large = $dbPasalCount > 0 ? $changed > $dbPasalCount * 0.3 : $changed > 0;

        return [
            'counts' => $counts,
            'selected' => $selected,
            'total_pasal' => $totalPasal,
            'large_change' => $large,
            'pdf_flagged' => $pdfFlagged,
        ];
    }

    /**
     * Bentuk baku isi pasal untuk perbandingan dan penyimpanan.
     *
     * @param  array<string, mixed>  $row
     * @return array{judul: ?string, isi: string, penjelasan: ?string, catatan: ?string, keywords: list<string>}
     */
    public function snap(array $row): array
    {
        $judul = trim((string) ($row['judul'] ?? ''));
        $penjelasan = (string) ($row['penjelasan'] ?? '');
        $catatan = (string) ($row['catatan'] ?? '');

        return [
            'judul' => $judul === '' ? null : $judul,
            'isi' => (string) ($row['isi'] ?? ''),
            'penjelasan' => trim($penjelasan) === '' ? null : $penjelasan,
            'catatan' => trim($catatan) === '' ? null : $catatan,
            'keywords' => $this->keywordList($row['keywords'] ?? []),
        ];
    }

    /** Dua isi pasal sama jika judul, isi, penjelasan, catatan, dan himpunan keyword sama (urutan keyword diabaikan). */
    public function same(?array $a, ?array $b): bool
    {
        if ($a === null || $b === null) {
            return $a === $b;
        }

        $a = $this->snap($a);
        $b = $this->snap($b);
        sort($a['keywords']);
        sort($b['keywords']);

        return $a === $b;
    }

    /**
     * Samakan baris riwayat dari pipeline dan dari DB supaya bisa dibandingkan dan disimpan. Aturannya
     * mengikuti ImportPasalService::replaceHistory, tapi tidak melempar error: status/sumber yang
     * salah baru ditolak saat diterapkan.
     *
     * @param  list<array<string, mixed>>  $rows
     * @return list<array<string, mixed>>
     */
    public static function normalizeRiwayat(array $rows): array
    {
        $result = [];
        foreach (array_values($rows) as $position => $row) {
            $text = PasalTextNormalizer::normalizePayload([
                'isi' => (string) ($row['isi'] ?? ''),
                'penjelasan' => $row['penjelasan'] ?? null,
            ]);
            $result[] = [
                'urutan' => (int) ($row['urutan'] ?? 0) ?: $position + 1,
                'status' => strtolower(trim((string) ($row['status'] ?? ''))),
                'sumber' => trim((string) ($row['sumber'] ?? '')),
                'judul_sumber' => self::nullableString($row['judul_sumber'] ?? null),
                'diundangkan' => self::nullableString($row['diundangkan'] ?? null),
                'berlaku_sejak' => self::nullableString($row['berlaku_sejak'] ?? null),
                'naskah_resmi' => self::nullableString($row['naskah_resmi'] ?? null),
                'isi' => $text['isi'],
                'penjelasan' => $text['penjelasan'] ?: null,
            ];
        }
        usort($result, fn ($x, $y) => $x['urutan'] <=> $y['urutan']);

        return $result;
    }

    /**
     * @param  array<string, mixed>|null  $currentRow
     * @param  array{judul: ?string, isi: string, penjelasan: ?string, catatan: ?string, keywords: list<string>}  $incoming
     * @param  list<array<string, mixed>>  $incomingRiwayat
     * @return array<string, mixed>|null null jika identik di semua sisi
     */
    private function classify(?array $currentRow, array $incoming, array $incomingRiwayat): ?array
    {
        if ($currentRow === null || ! empty($currentRow['trashed'])) {
            return [
                'pasal_id' => $currentRow['id'] ?? null,
                'category' => self::BARU,
                'selected' => true,
                'base' => null,
                'current' => null,
                'current_riwayat' => null,
                'notes' => $currentRow !== null ? ['Pasal ini ada di Sampah. Menerapkan akan memulihkannya dengan isi dari sumber.'] : [],
            ];
        }

        $current = $this->snap($currentRow);
        $currentRiwayat = self::normalizeRiwayat((array) ($currentRow['riwayat'] ?? []));
        $base = isset($currentRow['snapshot']) && is_array($currentRow['snapshot']) ? $this->snap($currentRow['snapshot']) : null;
        $notes = [];

        // Sumber yang tidak membawa riwayat tidak boleh menghapus riwayat buatan admin.
        $riwayatDiffers = $incomingRiwayat !== [] && $incomingRiwayat !== $currentRiwayat;

        $sourceChanged = $base === null ? ! $this->same($current, $incoming) : ! $this->same($base, $incoming);
        $adminChanged = $base === null ? $sourceChanged : ! $this->same($base, $current);
        if ($base === null && $sourceChanged) {
            $notes[] = 'Snapshot sumber belum ada, jadi tidak bisa dipastikan apakah data sekarang pernah diedit. Diperlakukan sebagai konflik.';
        }

        if ($sourceChanged && $this->same($current, $incoming)) {
            // Admin sudah mengetik teks yang sama dengan sumber baru; hanya snapshot yang tertinggal.
            $category = self::BERUBAH;
            $notes[] = 'Data sekarang sudah sama dengan sumber baru. Menerapkan hanya memperbarui snapshot.';
        } elseif ($sourceChanged) {
            $category = $adminChanged ? self::KONFLIK : self::BERUBAH;
        } elseif ($adminChanged) {
            $category = self::DIEDIT_ADMIN;
        } elseif ($riwayatDiffers) {
            $category = self::RIWAYAT;
        } else {
            return null;
        }

        if ($riwayatDiffers && $category !== self::RIWAYAT) {
            $notes[] = $category === self::DIEDIT_ADMIN
                ? 'Riwayat versi di sumber juga berbeda, tetapi pasal ini tidak diterapkan karena sudah diedit admin.'
                : 'Riwayat versi di sumber juga berbeda dan ikut diganti saat diterapkan.';
        }

        return [
            'pasal_id' => $currentRow['id'] ?? null,
            'category' => $category,
            'selected' => in_array($category, self::SELECTED_BY_DEFAULT, true),
            'base' => $base,
            'current' => $current,
            'current_riwayat' => $currentRiwayat === [] ? null : $currentRiwayat,
            'notes' => $notes,
        ];
    }

    /** @return list<string> */
    private function keywordList(mixed $value): array
    {
        $items = is_array($value) ? $value : explode(',', (string) $value);

        return array_values(array_filter(array_map(fn ($item) => trim((string) $item), $items), fn ($item) => $item !== ''));
    }

    private static function nullableString(mixed $value): ?string
    {
        $value = trim((string) ($value ?? ''));

        return $value === '' ? null : $value;
    }
}
