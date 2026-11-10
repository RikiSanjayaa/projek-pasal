"""Approved HTTPS downloads with public DNS validation and pinned connections."""

import http.client
import ipaddress
import os
from pathlib import Path
import socket
from urllib.parse import urljoin, urlsplit

SOURCE_HOSTS = frozenset({'datahukum.com', 'www.datahukum.com'})
PDF_HOSTS = frozenset({'peraturan.bpk.go.id', 'peraturan.go.id', 'jdih.setneg.go.id'})
MAX_BYTES = 40 * 1024 * 1024


def public_address(host: str) -> str:
    addresses = [entry[4][0] for entry in socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)]
    if not addresses or any(not ipaddress.ip_address(address).is_global for address in addresses):
        raise OSError('Sumber mengarah ke alamat jaringan nonpublik.')
    return addresses[0]


class PinnedHTTPSConnection(http.client.HTTPSConnection):
    def connect(self):
        address = public_address(self.host)
        self.sock = socket.create_connection((address, self.port), self.timeout)
        self.sock = self._context.wrap_socket(self.sock, server_hostname=self.host)


def download(url: str, path: Path) -> Path:
    allowed = SOURCE_HOSTS if urlsplit(url).hostname in SOURCE_HOSTS else PDF_HOSTS
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(path.name + '.part')
    try:
        for _ in range(6):
            parsed = urlsplit(url)
            if parsed.scheme != 'https' or parsed.hostname not in allowed or parsed.port not in (None, 443) or parsed.username or parsed.password:
                raise OSError('Tujuan unduhan atau pengalihan tidak diizinkan.')
            connection = PinnedHTTPSConnection(parsed.hostname, timeout=120)
            try:
                target = parsed.path or '/'
                if parsed.query:
                    target += '?' + parsed.query
                connection.request('GET', target, headers={'User-Agent': 'CariPasal import tool', 'Accept-Encoding': 'identity'})
                response = connection.getresponse()
                if response.status in (301, 302, 303, 307, 308):
                    location = response.getheader('Location')
                    if not location:
                        raise OSError('Pengalihan sumber tidak memiliki tujuan.')
                    url = urljoin(url, location)
                    continue
                if response.status != 200:
                    raise OSError(f'Unduhan sumber gagal: HTTP {response.status}.')
                size = 0
                with partial.open('wb') as output:
                    while chunk := response.read(64 * 1024):
                        size += len(chunk)
                        if size > MAX_BYTES:
                            raise OSError('Berkas sumber melampaui batas 40 MiB.')
                        output.write(chunk)
                os.replace(partial, path)
                return path
            finally:
                connection.close()
        raise OSError('Terlalu banyak pengalihan sumber.')
    finally:
        partial.unlink(missing_ok=True)
