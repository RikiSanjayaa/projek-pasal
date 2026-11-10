'use strict';

const BUILD = __CARIPASAL_MANIFEST__;
const ROOT = new URL(self.registration.scope);
const CACHE_PREFIX = 'caripasal-shell-' + encodeURIComponent(ROOT.pathname) + '-';
const CACHE_NAME = CACHE_PREFIX + BUILD.version;
const assetUrl = (path) => new URL(path, ROOT).href;
const assets = new Map(Object.entries(BUILD.assets).map(([path, hash]) => [assetUrl(path), hash]));

async function digest(bytes) {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)))
    .map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

async function cacheAssets() {
  const cache = await caches.open(CACHE_NAME);
  const entries = [...assets.entries()];
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(4, entries.length) }, async () => {
    while (next < entries.length) {
      const [url, expected] = entries[next++];
      if (await cache.match(url)) continue;
      const fetchUrl = new URL(url);
      fetchUrl.searchParams.set('v', BUILD.version);
      const response = await fetch(fetchUrl.href, { cache: 'no-store', credentials: 'omit' });
      if (!response.ok || response.type === 'opaque') throw new Error('Unduhan file aplikasi gagal');
      if (await digest(await response.clone().arrayBuffer()) !== expected) {
        throw new Error('Versi file aplikasi tidak cocok');
      }
      await cache.put(url, response);
    }
  }));
}

self.addEventListener('install', (event) => {
  // Never skipWaiting: existing tabs keep their complete previous version.
  event.waitUntil(cacheAssets().catch(async (error) => {
    await caches.delete(CACHE_NAME);
    throw error;
  }));
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Activation normally waits for the previous version's clients to close.
    for (const key of await caches.keys()) {
      if (key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

function isApi(url) {
  return url.pathname === '/api' || url.pathname.startsWith('/api/') ||
    url.pathname === ROOT.pathname + 'api' || url.pathname.startsWith(ROOT.pathname + 'api/');
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== ROOT.origin || isApi(url)) return;
  const canonical = url.origin + url.pathname;
  const navigation = request.mode === 'navigate' && url.pathname.startsWith(ROOT.pathname);
  if (!navigation && !assets.has(canonical)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const key = navigation ? assetUrl('index.html') : canonical;
    const cached = await cache.match(key);
    if (cached) return cached;
    // Eviction must not silently combine this shell with a different release.
    const response = await fetch(key, { cache: 'no-store', credentials: 'omit' });
    if (!response.ok || await digest(await response.clone().arrayBuffer()) !== assets.get(key)) {
      throw new Error('File offline tidak tersedia; sambungkan internet dan siapkan ulang');
    }
    await cache.put(key, response.clone());
    return response;
  })());
});

self.addEventListener('message', (event) => {
  if (!['OFFLINE_STATUS', 'PREPARE_OFFLINE'].includes(event.data?.type) || !event.ports[0]) return;
  event.waitUntil((async () => {
    try {
      if (event.data.type === 'PREPARE_OFFLINE') await cacheAssets();
      const cache = await caches.open(CACHE_NAME);
      let complete = true;
      for (const url of assets.keys()) {
        if (!await cache.match(url)) { complete = false; break; }
      }
      event.ports[0].postMessage({ version: BUILD.version, complete });
    } catch (_) {
      event.ports[0].postMessage({ version: BUILD.version, complete: false });
    }
  })());
});
