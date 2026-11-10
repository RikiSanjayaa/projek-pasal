const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { createHash, webcrypto } = require('node:crypto');
const vm = require('node:vm');
const path = require('node:path');

const template = readFileSync(path.join(__dirname, '../../tool/offline_worker.js'), 'utf8');
const hash = (text) => createHash('sha256').update(text).digest('hex');
const root = 'https://example.test/mobile/';

function worker(files = { 'index.html': '<p>Version one</p>', 'main.dart.js': 'versionOne();' }) {
  const stores = new Map();
  const handlers = {};
  const requests = [];
  let network = true;
  const key = (value) => typeof value === 'string' ? value : value.url;
  const caches = {
    async open(name) {
      if (!stores.has(name)) stores.set(name, new Map());
      const store = stores.get(name);
      return {
        async match(url) { return store.get(key(url))?.clone(); },
        async put(url, response) { store.set(key(url), response.clone()); },
      };
    },
    async keys() { return [...stores.keys()]; },
    async delete(name) { return stores.delete(name); },
  };
  vm.runInNewContext(template.replace('__CARIPASAL_MANIFEST__', JSON.stringify({
    version: 'one', assets: Object.fromEntries(Object.entries(files).map(([p, body]) => [p, hash(body)])),
  })), {
    URL, Response, crypto: webcrypto, caches,
    self: { registration: { scope: root }, clients: { async claim() {} },
      addEventListener(type, fn) { handlers[type] = fn; } },
    async fetch(url) {
      requests.push(url);
      if (!network) throw new Error('Network disconnected');
      const pathname = new URL(url).pathname.slice('/mobile/'.length);
      return new Response(files[pathname] ?? 'Not found', { status: pathname in files ? 200 : 404 });
    },
  });
  return {
    stores, requests, files, caches,
    offline() { network = false; },
    async install() {
      let work;
      handlers.install({ waitUntil(promise) { work = promise; } });
      await work;
    },
    async status() {
      let result, work;
      handlers.message({ data: { type: 'OFFLINE_STATUS' }, ports: [{ postMessage(value) { result = value; } }],
        waitUntil(promise) { work = promise; } });
      await work;
      return result;
    },
    fetch(pathname, { method = 'GET', mode = 'cors' } = {}) {
      let response;
      handlers.fetch({ request: { url: new URL(pathname, root).href, method, mode },
        respondWith(promise) { response = promise; } });
      return response;
    },
  };
}

test('cold document and runtime are served offline from the same complete release', async () => {
  const app = worker();
  await app.install();
  app.offline();
  assert.equal((await app.status()).complete, true);
  assert.equal(await (await app.fetch('./', { mode: 'navigate' })).text(), '<p>Version one</p>');
  assert.equal(await (await app.fetch('main.dart.js?v=one')).text(), 'versionOne();');
  assert.equal(app.requests.length, 2);
});

test('API, authentication mutations, and unknown assets bypass the shell', async () => {
  const app = worker();
  await app.install();
  for (const pathname of ['/api/mobile/me', '/api/mobile/sync/full', '/mobile/api/mobile/me', 'unknown.js']) {
    assert.equal(app.fetch(pathname), undefined);
  }
  assert.equal(app.fetch('/api', { mode: 'navigate' }), undefined);
  assert.equal(app.fetch('main.dart.js', { method: 'POST' }), undefined);
  assert.equal(app.fetch('https://other.test/main.dart.js'), undefined);
});

test('partial or mixed deployment never becomes ready and retains the previous release', async () => {
  const app = worker();
  const old = await app.caches.open('caripasal-shell-%2Fmobile%2F-old');
  await old.put(root + 'index.html', new Response('Previous version'));
  app.files['main.dart.js'] = 'versionTwo();';
  await assert.rejects(app.install(), /Versi file aplikasi tidak cocok/);
  assert.equal(app.stores.has('caripasal-shell-%2Fmobile%2F-one'), false);
  assert.equal(await (await old.match(root + 'index.html')).text(), 'Previous version');
});

test('eviction is reported and a newer network release cannot be mixed into an old shell', async () => {
  const app = worker();
  await app.install();
  app.stores.get('caripasal-shell-%2Fmobile%2F-one').delete(root + 'main.dart.js');
  assert.equal((await app.status()).complete, false);
  app.files['main.dart.js'] = 'versionTwo();';
  await assert.rejects(app.fetch('main.dart.js'), /File offline tidak tersedia/);
  assert.equal(app.stores.get('caripasal-shell-%2Fmobile%2F-one').has(root + 'main.dart.js'), false);
});
