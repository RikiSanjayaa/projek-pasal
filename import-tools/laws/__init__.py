"""Daftar undang-undang yang bisa disiapkan lewat `import-tools/prepare_import.py`."""

from laws import kuhap_2025, kuhp_2023

LAWS = {config.slug: config for config in (kuhp_2023.CONFIG, kuhap_2025.CONFIG)}
