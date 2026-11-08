<?php

namespace Tests\Unit;

use App\Services\ImportDiffService;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;

class ImportDiffServiceTest extends TestCase
{
    private ImportDiffService $service;

    protected function setUp(): void
    {
        $this->service = new ImportDiffService;
    }

    private function text(string $isi = 'Setiap orang dipidana.', array $keywords = ['pidana'], ?string $judul = null, ?string $penjelasan = null): array
    {
        return ['judul' => $judul, 'isi' => $isi, 'penjelasan' => $penjelasan, 'keywords' => $keywords];
    }

    /** Baris pasal di DB; snapshot default = isi sekarang. */
    private function db(string $nomor, array $current, ?array $snapshot = null, array $riwayat = [], bool $trashed = false): array
    {
        return ['id' => "id-{$nomor}", 'nomor' => $nomor, 'snapshot' => func_num_args() >= 3 ? $snapshot : $current, 'riwayat' => $riwayat, 'trashed' => $trashed] + $current;
    }

    private function src(string $nomor, array $text, array $extra = []): array
    {
        return ['nomor' => $nomor] + $text + $extra;
    }

    private function only(array $items): array
    {
        $this->assertCount(1, $items);

        return $items[0];
    }

    private function riwayat(string $isi): array
    {
        return [['urutan' => 1, 'status' => 'asli', 'sumber' => 'UU 1/2023', 'isi' => $isi]];
    }

    public function test_identical_everywhere_produces_no_item(): void
    {
        $t = $this->text();
        $this->assertSame([], $this->service->diff([$this->db('1', $t)], [$this->src('1', $t)]));
    }

    public function test_baru_when_missing_in_db(): void
    {
        $item = $this->only($this->service->diff([], [$this->src('1', $this->text())]));

        $this->assertSame('baru', $item['category']);
        $this->assertTrue($item['selected']);
        $this->assertNull($item['pasal_id']);
        $this->assertNull($item['base']);
    }

    public function test_baru_restores_trashed_pasal(): void
    {
        $item = $this->only($this->service->diff([$this->db('1', $this->text(), null, [], true)], [$this->src('1', $this->text())]));

        $this->assertSame('baru', $item['category']);
        $this->assertSame('id-1', $item['pasal_id']);
        $this->assertNotEmpty($item['notes']);
    }

    public function test_berubah_when_only_source_changed(): void
    {
        $old = $this->text('Isi lama.');
        $item = $this->only($this->service->diff([$this->db('1', $old)], [$this->src('1', $this->text('Isi baru.'))]));

        $this->assertSame('berubah', $item['category']);
        $this->assertTrue($item['selected']);
        $this->assertSame('Isi lama.', $item['base']['isi']);
        $this->assertSame('Isi baru.', $item['incoming']['isi']);
    }

    public function test_diedit_admin_when_only_current_changed(): void
    {
        $base = $this->text('Isi sumber.');
        $item = $this->only($this->service->diff(
            [$this->db('1', $this->text('Isi diedit admin.'), $base)],
            [$this->src('1', $base)],
        ));

        $this->assertSame('diedit_admin', $item['category']);
        $this->assertFalse($item['selected']);
    }

    public function test_konflik_when_both_changed(): void
    {
        $item = $this->only($this->service->diff(
            [$this->db('1', $this->text('Versi admin.'), $this->text('Versi lama.'))],
            [$this->src('1', $this->text('Versi sumber baru.'))],
        ));

        $this->assertSame('konflik', $item['category']);
        $this->assertFalse($item['selected']);
    }

    public function test_hilang_when_pasal_not_in_source(): void
    {
        $items = $this->service->diff([$this->db('1', $this->text()), $this->db('2', $this->text('Lain.'))], [$this->src('1', $this->text())]);
        $item = $this->only($items);

        $this->assertSame('hilang', $item['category']);
        $this->assertSame('2', $item['nomor']);
        $this->assertFalse($item['selected']);
        $this->assertNull($item['incoming']);
    }

    public function test_trashed_pasal_missing_in_source_is_not_hilang(): void
    {
        $this->assertSame([], $this->service->diff([$this->db('9', $this->text(), null, [], true)], []));
    }

    public function test_riwayat_when_text_same_but_history_differs(): void
    {
        $t = $this->text();
        $item = $this->only($this->service->diff(
            [$this->db('1', $t, $t, $this->riwayat('Lama.'))],
            [$this->src('1', $t, ['riwayat' => $this->riwayat('Baru.')])],
        ));

        $this->assertSame('riwayat', $item['category']);
        $this->assertTrue($item['selected']);
        $this->assertSame('Baru.', $item['incoming_riwayat'][0]['isi']);
        $this->assertSame('Lama.', $item['current_riwayat'][0]['isi']);
    }

    public function test_same_riwayat_produces_no_item_and_empty_source_riwayat_is_ignored(): void
    {
        $t = $this->text();
        $db = $this->db('1', $t, $t, $this->riwayat('Sama.'));

        $this->assertSame([], $this->service->diff([$db], [$this->src('1', $t, ['riwayat' => $this->riwayat('Sama.')])]));
        $this->assertSame([], $this->service->diff([$db], [$this->src('1', $t, ['riwayat' => []])]));
    }

    public function test_keyword_order_does_not_matter_but_membership_does(): void
    {
        $base = $this->text(keywords: ['a', 'b']);
        $db = $this->db('1', $base);

        $this->assertSame([], $this->service->diff([$db], [$this->src('1', $this->text(keywords: ['b', 'a']))]));

        $item = $this->only($this->service->diff([$db], [$this->src('1', $this->text(keywords: ['a', 'c']))]));
        $this->assertSame('berubah', $item['category']);
    }

    public function test_incoming_text_is_normalized_like_the_importer(): void
    {
        $db = $this->db('121', $this->text("Setiap Orang dipidana paling lama 5 tahun."));
        $raw = "Setiap   Orang dipidana paling lama 5 tahun.\r\n";

        $this->assertSame([], $this->service->diff([$db], [$this->src('Pasal 121.', $this->text($raw))]));
    }

    public function test_normalizer_typo_fix_is_applied_to_incoming(): void
    {
        $item = $this->only($this->service->diff([], [$this->src('1', $this->text('Dipidana paling lama tqjuh tahun.'))]));

        $this->assertSame('Dipidana paling lama tujuh tahun.', $item['incoming']['isi']);
    }

    public function test_missing_snapshot_with_difference_is_konflik(): void
    {
        $item = $this->only($this->service->diff([$this->db('1', $this->text('A.'), null)], [$this->src('1', $this->text('B.'))]));

        $this->assertSame('konflik', $item['category']);
        $this->assertNull($item['base']);
    }

    public function test_current_already_equal_to_new_source_is_berubah_with_note(): void
    {
        $item = $this->only($this->service->diff(
            [$this->db('1', $this->text('Baru.'), $this->text('Lama.'))],
            [$this->src('1', $this->text('Baru.'))],
        ));

        $this->assertSame('berubah', $item['category']);
        $this->assertNotEmpty($item['notes']);
    }

    public function test_review_and_links_are_carried_to_item(): void
    {
        $links = [['targetUU' => 'KUHP', 'targetNomor' => '2', 'keterangan' => 'Disebut dalam isi: Pasal 2']];
        $item = $this->only($this->service->diff([], [$this->src('1', $this->text(), ['review' => ['perlu_review' => true], 'links' => $links])]));

        $this->assertTrue($item['review']['perlu_review']);
        $this->assertSame($links, $item['incoming_links']);
    }

    public function test_duplicate_or_empty_source_pasal_is_rejected(): void
    {
        $this->expectException(InvalidArgumentException::class);
        $this->service->diff([], [$this->src('1', $this->text()), $this->src('1', $this->text('Lain.'))]);
    }

    public function test_catatan_only_change_in_source_is_berubah(): void
    {
        $t = $this->text();
        $item = $this->only($this->service->diff(
            [$this->db('1', $t + ['catatan' => null])],
            [$this->src('1', $t, ['catatan' => "Bab ini tidak berlaku lagi.\r\n"])],
        ));

        $this->assertSame('berubah', $item['category']);
        $this->assertNull($item['base']['catatan']);
        $this->assertSame('Bab ini tidak berlaku lagi.', $item['incoming']['catatan']);
    }

    public function test_catatan_edited_by_admin_is_diedit_admin_and_both_sides_changed_is_konflik(): void
    {
        $t = $this->text();
        $item = $this->only($this->service->diff(
            [$this->db('1', $t + ['catatan' => 'Catatan admin.'], $t)],
            [$this->src('1', $t)],
        ));
        $this->assertSame('diedit_admin', $item['category']);

        $item = $this->only($this->service->diff(
            [$this->db('1', $t + ['catatan' => 'Catatan admin.'], $t)],
            [$this->src('1', $t, ['catatan' => 'Catatan sumber.'])],
        ));
        $this->assertSame('konflik', $item['category']);
    }

    public function test_missing_catatan_key_equals_null_and_empty_string(): void
    {
        $t = $this->text();

        $this->assertSame([], $this->service->diff([$this->db('1', $t)], [$this->src('1', $t, ['catatan' => null])]));
        $this->assertSame([], $this->service->diff([$this->db('1', $t + ['catatan' => ''])], [$this->src('1', $t)]));
        // Snapshot lama tanpa kunci catatan dibaca sebagai null.
        $this->assertSame([], $this->service->diff([$this->db('1', $t + ['catatan' => null], $t)], [$this->src('1', $t)]));
    }

    public function test_summary_counts_and_large_change_threshold(): void
    {
        $current = [];
        $incoming = [];
        for ($i = 1; $i <= 10; $i++) {
            $current[] = $this->db((string) $i, $this->text("Lama {$i}."));
            $incoming[] = $this->src((string) $i, $this->text($i <= 3 ? "Baru {$i}." : "Lama {$i}."), $i === 1 ? ['review' => ['perlu_review' => true]] : []);
        }

        $summary = $this->service->summarize($this->service->diff($current, $incoming), 10, 10);
        $this->assertSame(3, $summary['counts']['berubah']);
        $this->assertSame(3, $summary['selected']);
        $this->assertSame(1, $summary['pdf_flagged']);
        $this->assertFalse($summary['large_change']); // 3 dari 10 = 30%, belum lebih dari 30%

        $incoming[3] = $this->src('4', $this->text('Baru 4.'));
        $summary = $this->service->summarize($this->service->diff($current, $incoming), 10, 10);
        $this->assertTrue($summary['large_change']);
    }
}
