import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from datahukum_pipeline import PipelineError, parse_datahukum, run_json
from source_config import load_config
from secure_fetch import download, public_address

HTML = '''<div class="batangtubuh"><div class="pasal"><div class="pasal-header"><h5>Pasal 1</h5></div><div class="content"><section class="uu-122024"><p>Setiap orang wajib menjaga data.</p></section></div><div class="penjelasan"><section class="uu-122024"><p>Cukup jelas.</p></section></div></div></div>'''


class SourceConfigTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = {'slug': 'a-new-law', 'kode': 'NEW', 'label': 'UU 12/2024', 'nama': 'New Law', 'nama_lengkap': 'New Law', 'tahun': 2024, 'datahukum_url': 'https://www.datahukum.com/peraturan/UU_12_Tahun_2024.html', 'doc_class': 'uu-122024', 'amendments_from_html': True}

    def load(self, data):
        path = self.root / 'source.json'
        path.write_text(json.dumps(data), encoding='utf-8')
        return load_config(path)

    def test_unregistered_law_parses_original_text_and_history_without_network(self):
        config = self.load(self.config)
        key = hashlib.sha256(config.datahukum_url.encode()).hexdigest()[:12]
        (self.root / f'datahukum_{config.slug}_{key}.html').write_text(HTML, encoding='utf-8')
        with patch('datahukum_pipeline.CACHE_DIR', self.root), patch('secure_fetch.public_address', side_effect=AssertionError('Network forbidden')):
            result = run_json(config, False)
        self.assertEqual(result['pasal'][0]['nomor'], '1')
        self.assertEqual(result['pasal'][0]['isi'], 'Setiap orang wajib menjaga data.')
        self.assertIsNone(result['pasal'][0]['review']['cakupan_isi_pdf'])

    def test_all_migrated_configs_load_with_corrections_and_reviewed_ite_rule(self):
        migration = Path(__file__).resolve().parents[2] / 'backend-laravel/database/data/import_sources.json'
        configs = json.loads(migration.read_text())
        loaded = [self.load(config) for config in configs]
        kuhap = next(c for c in loaded if c.kode == 'KUHAP')
        html = self.root / 'kuhap.html'
        html.write_text(HTML.replace('uu-122024', kuhap.doc_class).replace('Setiap orang wajib menjaga data.', 'alau hak terpidana'), encoding='utf-8')
        records, _ = parse_datahukum(html, kuhap, [], set(), strict_fixes=False)
        self.assertEqual(records[0].isi, 'atau hak terpidana')
        ite = next(c for c in loaded if c.kode == 'UU-ITE')
        rule = ite.amendment_overrides['uu-12026']['derive']
        self.assertEqual(rule('28', '(1) Tetap berlaku.\n(2) Ketentuan lama.'), '(1) Tetap berlaku.\n(2) Dicabut.')

    def test_rejects_unknown_code_rules_paths_and_unapproved_urls(self):
        for extra in [{'slug': '../escape'}, {'derive': 'run arbitrary code'}, {'datahukum_url': 'https://127.0.0.1/admin'}, {'bpk_pdf_url': 'https://www.datahukum.com/private.pdf'}, {'amendments': [{'derive_rule': 'eval'}]}, {'official_pdf_path': '/etc/passwd'}]:
            with self.subTest(extra=extra), self.assertRaises(PipelineError):
                self.load(self.config | extra)

    def test_local_document_must_be_inside_private_document_root(self):
        pdf = self.root / 'original.pdf'
        pdf.write_bytes(b'%PDF-1.4')
        with patch.dict(os.environ, {'IMPORT_DOCUMENTS_DIR': str(self.root)}):
            self.assertEqual(self.load(self.config | {'official_pdf_path': str(pdf)}).official_pdf_path, str(pdf))
        with patch.dict(os.environ, {'IMPORT_DOCUMENTS_DIR': str(self.root / 'another-root')}), self.assertRaises(PipelineError):
            self.load(self.config | {'official_pdf_path': str(pdf)})

    def test_public_dns_rejects_private_or_mixed_public_private_answers(self):
        for addresses in [['127.0.0.1'], ['169.254.169.254'], ['93.184.216.34', '10.0.0.1'], ['::1']]:
            answers = [(0, 0, 0, '', (address, 443)) for address in addresses]
            with self.subTest(addresses=addresses), patch('socket.getaddrinfo', return_value=answers), self.assertRaises(OSError):
                public_address('www.datahukum.com')

    def test_redirect_cannot_escape_approved_source_hosts(self):
        class Redirect:
            status = 302
            def getheader(self, name):
                return 'https://127.0.0.1/secret'
        class Connection:
            def __init__(self, *args, **kwargs): pass
            def request(self, *args, **kwargs): pass
            def getresponse(self): return Redirect()
            def close(self): pass
        path = self.root / 'download.html'
        with patch('secure_fetch.PinnedHTTPSConnection', Connection), self.assertRaises(OSError):
            download(self.config['datahukum_url'], path)
        self.assertFalse(path.exists())
        self.assertFalse(path.with_name(path.name+'.part').exists())


if __name__ == '__main__':
    unittest.main()
