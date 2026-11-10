"""Strict declarative configuration for the shared datahukum parser."""

from dataclasses import fields
from pathlib import Path
import json
import os
import re
from urllib.parse import urlsplit

from datahukum_pipeline import Amendment, CatatanRule, LawConfig, PipelineError
from reviewed_rules import _derive_2026

SOURCE_HOSTS = frozenset({'datahukum.com', 'www.datahukum.com'})
PDF_HOSTS = frozenset({'peraturan.bpk.go.id', 'peraturan.go.id', 'jdih.setneg.go.id'})


def validate_url(url: str, hosts: frozenset[str]) -> str:
    try:
        parsed = urlsplit(url)
        valid = parsed.scheme == 'https' and parsed.hostname in hosts and parsed.port in (None, 443) and not parsed.username and not parsed.password
    except (ValueError, TypeError):
        valid = False
    if not valid:
        raise PipelineError('URL sumber harus HTTPS pada situs yang diizinkan, tanpa kredensial atau port khusus.')
    return url


def safe_filename(value: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r'[a-zA-Z0-9_.-]+', value) or value in ('.', '..'):
        raise PipelineError('Nama berkas cache tidak valid.')
    return value


def amendment(value: dict) -> Amendment:
    value = dict(value)
    rule = value.pop('derive_rule', None)
    if rule not in (None, 'ite-2026'):
        raise PipelineError('Aturan konsolidasi tidak dikenal.')
    if 'derive' in value or set(value) - {f.name for f in fields(Amendment)}:
        raise PipelineError('Konfigurasi perubahan tidak dikenal.')
    if rule:
        value['derive'] = _derive_2026
    if value.get('pdf_url'):
        validate_url(value['pdf_url'], PDF_HOSTS)
    if value.get('pdf'):
        safe_filename(value['pdf'])
    return Amendment(**value)


def load_config(path: Path) -> LawConfig:
    try:
        value = json.loads(path.read_text(encoding='utf-8'))
        if not isinstance(value, dict) or set(value) - {f.name for f in fields(LawConfig)}:
            raise PipelineError('Kolom konfigurasi sumber tidak dikenal.')
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,119}', value.get('slug', '')):
            raise PipelineError('Slug sumber tidak valid.')
        validate_url(value['datahukum_url'], SOURCE_HOSTS)
        if value.get('bpk_pdf_url'):
            validate_url(value['bpk_pdf_url'], PDF_HOSTS)
        if value.get('doc_class') and not re.fullmatch(r'[a-z0-9-]+', value['doc_class']):
            raise PipelineError('Penanda versi asli tidak valid.')
        for key in ('body_pages', 'penjelasan_pages'):
            pair = value.get(key, [0, 0])
            if not isinstance(pair, list) or len(pair) != 2 or any(type(n) is not int or n < 0 for n in pair) or pair[0] > pair[1] or ((pair[0] == 0) != (pair[1] == 0)):
                raise PipelineError('Rentang halaman PDF tidak valid.')
            value[key] = tuple(pair)
        value['amendments'] = tuple(amendment(a) for a in value.get('amendments', []))
        overrides = {}
        for key, raw in value.get('amendment_overrides', {}).items():
            # Overrides have the same fields as Amendment except identity may come from HTML.
            checked = amendment({'doc_class': key, 'label': '', 'title': '', 'full_title': '', **raw})
            overrides[key] = {k: getattr(checked, k) for k in raw if k != 'derive_rule'}
            if raw.get('derive_rule'):
                overrides[key]['derive'] = checked.derive
        value['amendment_overrides'] = overrides
        value['catatan_rules'] = tuple(CatatanRule(**r) for r in value.get('catatan_rules', []))
        if value.get('official_pdf_path'):
            root = Path(os.environ.get('IMPORT_DOCUMENTS_DIR', '/var/www/html/storage/app/private/law-documents')).resolve()
            pdf = Path(value['official_pdf_path']).resolve(strict=True)
            if not pdf.is_relative_to(root) or not pdf.is_file() or pdf.suffix.lower() != '.pdf':
                raise PipelineError('Lokasi dokumen asli tidak valid.')
            value['official_pdf_path'] = str(pdf)
        safe_filename(value.get('xlsx_name', value['slug']+'.xlsx'))
        value.setdefault('xlsx_name', value['slug']+'.xlsx')
        return LawConfig(**value)
    except (KeyError, TypeError, ValueError, OSError) as error:
        raise PipelineError(f'Konfigurasi sumber tidak valid: {error}') from error
