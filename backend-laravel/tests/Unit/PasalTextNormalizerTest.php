<?php

namespace Tests\Unit;

use App\Support\PasalTextNormalizer;
use PHPUnit\Framework\TestCase;

class PasalTextNormalizerTest extends TestCase
{
    public function test_it_normalizes_pasal_number_prefix(): void
    {
        $this->assertSame('121', PasalTextNormalizer::normalizeNomor('Pasal 121.'));
        $this->assertSame('479b', PasalTextNormalizer::normalizeNomor('479 b'));
    }

    public function test_it_cleans_common_ocr_noise(): void
    {
        $text = PasalTextNormalizer::normalizeBody(
            "PTIESIDEN REPUBUK INDONESIA\n(1) Setiap   Orang dipidana paling lama tqjuh tahy.\nPRESIDEN REPUBLIK INDONESIA"
        );

        $this->assertStringNotContainsString('PRESIDEN REPUBLIK INDONESIA', $text);
        $this->assertStringContainsString('tujuh tahun', $text);
        $this->assertStringNotContainsString('tqjuh', $text);
        $this->assertStringNotContainsString('tahy', $text);
        $this->assertStringNotContainsString('   ', $text);
    }

    public function test_it_keeps_inline_references_to_ayat_and_huruf(): void
    {
        $isi = "(1) Ketentuan sebagaimana dimaksud dalam Pasal 1 ayat (1) tidak mengurangi berlakunya hukum.\n"
            ."(2) Pidana denda paling banyak kategori I. Ketentuan pada ayat (2) huruf c. tidak berlaku.\n"
            ."a. melakukan Tindak Pidana kembali dalam waktu 5 (lima) tahun setelah menjalani pidana.\n"
            .'b. konvensi yang disahkan pada tanggal 10 Desember 1984. Indonesia telah meratifikasinya.';

        $this->assertSame($isi, PasalTextNormalizer::normalizeBody($isi));
    }

    public function test_it_still_splits_list_items_flattened_by_ocr(): void
    {
        $text = PasalTextNormalizer::normalizeBody('Pidana denda dijatuhkan jika: a. tanpa Korban; b. Korban tidak mempermasalahkan.');

        $this->assertSame("Pidana denda dijatuhkan jika:\na. tanpa Korban;\nb. Korban tidak mempermasalahkan.", $text);
    }

    public function test_it_keeps_penjelasan_labels_and_paragraphs_on_their_own_lines(): void
    {
        $penjelasan = "Ayat (1) Cukup jelas.\nAyat (2)\nHuruf a Cukup jelas.\nHuruf b Yang dimaksud dengan \"makam\" adalah liang.\n"
            ."Ayat ini mengandung pedoman dalam menetapkan hukum pidana adat.\nCatatan Putusan MK Nomor 1/PUU-I/2026: tidak mengikat.";

        $this->assertSame($penjelasan, PasalTextNormalizer::normalizeBody($penjelasan));
    }

    public function test_it_rejoins_ocr_line_wraps_inside_a_sentence(): void
    {
        $text = PasalTextNormalizer::normalizeBody("(1) Hukum sebagaimana dimaksud pada\nayat (1) berlaku dalam tempat hukum itu hidup.");

        $this->assertSame('(1) Hukum sebagaimana dimaksud pada ayat (1) berlaku dalam tempat hukum itu hidup.', $text);
    }

    public function test_it_is_stable_when_applied_again(): void
    {
        // Teks sumber UU ITE Pasal 17: ayat sisipan (2a) menempel di baris "(2)". Satu putaran saja
        // belum stabil, sehingga import lewat dashboard (dinormalisasi dua kali) dan lewat file berbeda.
        $once = PasalTextNormalizer::normalizeBody("(1) Penyelenggaraan Transaksi Elektronik dapat dilakukan dalam lingkup publik atau privat.\n"
            ."(2) Para pihak yang melakukan Transaksi Elektronik sebagaimana dimaksud pada ayat (1) wajib beriktikad baik dalam melakukan interaksi dan/atau pertukaran Informasi Elektronik dan/atau Dokumen Elektronik selama transaksi berlangsung.\n"
            ."(2) (2a)\nTransaksi Elektronik yang memiliki risiko tinggi bagi para pihak menggunakan Tanda Tangan Elektronik yang diamankan dengan Sertifikat Elektronik.\n"
            .'(3) Ketentuan lebih lanjut mengenai penyelenggaraan Transaksi Elektronik sebagaimana dimaksud pada ayat (1), ayat (2), dan ayat (2a) diatur dalam Peraturan Pemerintah.');

        $this->assertSame($once, PasalTextNormalizer::normalizeBody($once));
    }
}
