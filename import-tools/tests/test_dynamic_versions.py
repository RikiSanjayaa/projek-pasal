import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from datahukum_pipeline import PipelineError, run_json
from source_config import load_config

FIXTURE = Path(__file__).parent / 'fixtures' / 'uud_1945.html'


class DynamicVersionsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config_data = {'slug': 'constitution', 'kode': 'UUD_1945', 'label': 'UUD 1945', 'nama': 'UUD 1945', 'nama_lengkap': 'Undang-Undang Dasar Negara Republik Indonesia Tahun 1945', 'tahun': 1945, 'datahukum_url': 'https://www.datahukum.com/peraturan/UUD_1945.html', 'amendments_from_html': True}

    def config(self, **extra):
        path = self.root / 'config.json'
        path.write_text(json.dumps(self.config_data | extra), encoding='utf-8')
        return load_config(path)

    def run_html(self, html, **extra):
        config = self.config(**extra)
        key = hashlib.sha256(config.datahukum_url.encode()).hexdigest()[:12]
        (self.root / f'datahukum_{config.slug}_{key}.html').write_text(html, encoding='utf-8')
        with patch('datahukum_pipeline.CACHE_DIR', self.root), patch('secure_fetch.public_address', side_effect=AssertionError('Network forbidden')):
            return run_json(config, False)

    def test_full_constitution_keeps_all_articles_and_four_amendments_without_manual_marker(self):
        result = self.run_html(FIXTURE.read_text(encoding='utf-8'))
        rows = {p['nomor']: p for p in result['pasal']}
        self.assertEqual(len(rows), 79)
        self.assertEqual(len(result['pasal']), 79)
        self.assertEqual(result['unknown_versions'], [])
        self.assertIn('Kedaulatan berada di tangan rakyat', rows['1']['isi'])
        self.assertIn('(3) Jika Presiden dan Wakil Presiden mangkat', rows['8']['isi'])
        self.assertIn('Presiden membentuk suatu dewan pertimbangan', rows['16']['isi'])
        self.assertIn('25E', rows)
        self.assertNotIn('25A', rows)
        self.assertEqual(rows['IV (ATURAN PERALIHAN)']['isi'], 'Dihapus.')
        self.assertIn('Majelis Permusyawaratan Rakyat ditugasi', rows['I (ATURAN TAMBAHAN)']['isi'])
        self.assertIn('Segala peraturan perundang-undangan', rows['I (ATURAN PERALIHAN)']['isi'])
        self.assertEqual(rows['II (ATURAN TAMBAHAN)']['riwayat'][0]['status'], 'disisipkan')
        histories = [h for p in rows.values() for h in p['riwayat']]
        for label, date in [('Amandemen I', '19 Oktober 1999'), ('Amandemen II', '18 Agustus 2000'), ('Amandemen III', '9 November 2001'), ('Amandemen IV', '10 Agustus 2002')]:
            matching = [h for h in histories if h['sumber'] == label]
            self.assertTrue(matching, label)
            self.assertTrue(all(date in h['judul_sumber'] for h in matching), label)
            self.assertTrue(all(h['diundangkan'] == '' for h in matching), label)

    def test_generic_title_is_preserved_without_fabricating_regulation_number(self):
        html = FIXTURE.read_text(encoding='utf-8').replace('Amandemen I</h5>', 'Perubahan Konstitusi Pertama</h5>')
        result = self.run_html(html)
        history = next(p for p in result['pasal'] if p['nomor'] == '5')['riwayat']
        self.assertEqual(history[-1]['sumber'], 'Perubahan Konstitusi Pertama')
        self.assertNotIn('Undang-Undang Nomor 1 Tahun 1945', history[-1]['judul_sumber'])

    def test_conflicting_original_marker_is_rejected(self):
        with self.assertRaises(PipelineError):
            self.run_html(FIXTURE.read_text(encoding='utf-8'), doc_class='uu-wrong')

    def test_duplicate_version_identity_is_rejected(self):
        html = FIXTURE.read_text(encoding='utf-8').replace('uu-21945', 'uu-11945')
        with self.assertRaises(PipelineError):
            self.run_html(html)

    def test_reversed_known_dates_are_rejected_instead_of_reordering_versions(self):
        html = FIXTURE.read_text(encoding='utf-8').replace('19 Oktober 1999', '19 Oktober 2003')
        with self.assertRaises(PipelineError):
            self.run_html(html)


    def test_registry_year_order_does_not_mistake_decree_signature_for_publication(self):
        html = FIXTURE.read_text(encoding='utf-8').replace('Amandemen I</h5>', '1. Staatsblad No. 108 Tahun 1999</h5>').replace('Amandemen II</h5>', '2. Staatsblad No. 53 Tahun 2000</h5>').replace('18 Agustus 2000', '18 Agustus 1998')
        result = self.run_html(html)
        history = next(p for p in result['pasal'] if p['nomor'] == '18')['riwayat']
        self.assertEqual(history[-1]['sumber'], 'Stb. 2000 No. 53')
        self.assertIn('18 Agustus 1998', history[-1]['judul_sumber'])
        self.assertEqual(history[-1]['diundangkan'], '')
    def test_unmapped_content_version_is_not_silently_discarded(self):
        html = FIXTURE.read_text(encoding='utf-8').replace('section class="uu-31945"', 'section class="uu-unmapped"', 1)
        result = self.run_html(html)
        self.assertEqual(result['unknown_versions'], ['uu-unmapped'])

    def test_ambiguous_original_identity_requires_explicit_configuration(self):
        html = FIXTURE.read_text(encoding='utf-8').replace('class="uu uu--original uu-01945"', 'class="uu uu--original uu-01945 uu-11945"')
        with self.assertRaises(PipelineError):
            self.run_html(html)


if __name__ == '__main__':
    unittest.main()
