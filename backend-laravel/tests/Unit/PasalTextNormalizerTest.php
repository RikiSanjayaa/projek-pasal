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
}
