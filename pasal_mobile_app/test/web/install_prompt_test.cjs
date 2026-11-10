const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = readFileSync(path.join(__dirname, '../../web/offline.js'), 'utf8');

function client(installed = false, serviceWorker) {
  const handlers = new Map();
  const window = {
    addEventListener(name, handler) { handlers.set(name, handler); },
    dispatchEvent() {},
  };
  if (serviceWorker) window.caches = {};
  vm.runInNewContext(source, {
    window, URL, document: { baseURI: 'https://example.test/' },
    navigator: serviceWorker ? { serviceWorker } : {}, isSecureContext: !!serviceWorker,
    matchMedia: () => ({ matches: installed, addEventListener() {} }),
    CustomEvent: class {},
  });
  return { bridge: window.cariPasalOffline, emit: (name, event) => handlers.get(name)?.(event) };
}

test('dismissal consumes the prompt and does not claim installation or offline readiness', async () => {
  const app = client();
  let calls = 0;
  let cancelledDefault = false;
  app.emit('beforeinstallprompt', {
    preventDefault() { cancelledDefault = true; },
    prompt() { calls++; }, userChoice: Promise.resolve({ outcome: 'dismissed' }),
  });
  assert.equal(cancelledDefault, true);
  assert.equal(calls, 0);
  assert.equal(app.bridge.getState().installStatus, 'available');
  const first = app.bridge.install();
  assert.equal(calls, 1); // Called synchronously while the click's activation is available.
  assert.equal(await first, 'dismissed');
  assert.equal(app.bridge.getState().installStatus, 'manual');
  assert.equal(await app.bridge.install(), 'manual');
  assert.equal(calls, 1);
  assert.notEqual(app.bridge.getState().status, 'ready');
});

test('accepted prompt alone is not proof of installation; appinstalled confirms it', async () => {
  const app = client();
  app.emit('beforeinstallprompt', {
    preventDefault() {}, prompt() {}, userChoice: Promise.resolve({ outcome: 'accepted' }),
  });
  assert.equal(await app.bridge.install(), 'accepted');
  assert.equal(app.bridge.getState().installStatus, 'manual');
  app.emit('appinstalled');
  assert.equal(app.bridge.getState().installStatus, 'installed');
  assert.equal(await app.bridge.install(), 'installed');
});

test('standalone starts installed and browsers without a prompt retain manual guidance', async () => {
  assert.equal(client(true).bridge.getState().installStatus, 'installed');
  const app = client();
  assert.equal(await app.bridge.install(), 'manual');
  assert.equal(app.bridge.getState().installStatus, 'manual');
});

test('failed preparation stays retryable after refresh and can return to preparing', async () => {
  let statechange;
  const installing = { state: 'installing', addEventListener(name, handler) { statechange = handler; } };
  const registration = { installing, addEventListener() {}, async update() {} };
  const app = client(false, { addEventListener() {}, async register() { return registration; } });
  await app.bridge.prepare();
  assert.equal(app.bridge.getState().status, 'preparing');
  installing.state = 'redundant';
  registration.installing = null;
  statechange();
  assert.equal(app.bridge.getState().status, 'error');
  await app.bridge.refresh();
  assert.equal(app.bridge.getState().status, 'error');
  assert.ok(app.bridge.getState().error);
  installing.state = 'installing';
  registration.installing = installing;
  await app.bridge.prepare();
  assert.equal(app.bridge.getState().status, 'preparing');
  assert.equal(app.bridge.getState().error, null);
});
