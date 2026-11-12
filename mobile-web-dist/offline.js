'use strict';

(() => {
  const version = '89dd0d86013a7cf914b97e753ad2f2ae305b29e4675854292a082f6d92c5ab7b';
  const root = new URL(document.baseURI);
  let registration;
  let preparing;
  let installPrompt;
  const standalone = matchMedia('(display-mode: standalone)');
  let state = { status: 'preparing', storagePersistent: false, updateAvailable: false, error: null,
    installStatus: standalone.matches || navigator.standalone === true ? 'installed' : 'manual' };
  const supported = isSecureContext && 'serviceWorker' in navigator && 'caches' in window;
  function publish(next) {
    state = { ...state, ...next };
    window.dispatchEvent(new CustomEvent('caripasal-offline-change', { detail: state }));
    return state;
  }
  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    installPrompt = event;
    publish({ installStatus: 'available' });
  });
  window.addEventListener('appinstalled', () => {
    installPrompt = null;
    publish({ installStatus: 'installed' });
  });
  standalone.addEventListener('change', () => {
    if (standalone.matches) publish({ installStatus: 'installed' });
  });
  function install() {
    if (state.installStatus === 'installed') return Promise.resolve('installed');
    if (!installPrompt) return Promise.resolve('manual');
    const prompt = installPrompt;
    installPrompt = null;
    // prompt() must run directly inside the user's click, before any await.
    try {
      return Promise.resolve(prompt.prompt()).then(() => prompt.userChoice).then((choice) => {
        if (state.installStatus !== 'installed') publish({ installStatus: 'manual' });
        return choice.outcome;
      }).catch(() => { publish({ installStatus: 'manual' }); return 'manual'; });
    } catch (_) {
      publish({ installStatus: 'manual' });
      return Promise.resolve('manual');
    }
  }
  function query(worker, type = 'OFFLINE_STATUS') {
    return new Promise((resolve, reject) => {
      const channel = new MessageChannel();
      const timeout = setTimeout(() => { channel.port1.close(); reject(new Error('Pemeriksaan file offline belum berhasil')); }, type === 'PREPARE_OFFLINE' ? 120000 : 10000);
      channel.port1.onmessage = (event) => {
        clearTimeout(timeout);
        channel.port1.close();
        resolve(event.data);
      };
      worker.postMessage({ type }, [channel.port2]);
    });
  }
  async function refresh() {
    if (!supported) return publish({ status: 'unsupported', error: 'Browser ini tidak mendukung penyimpanan aplikasi offline.' });
    try {
      const storagePersistent = navigator.storage?.persisted ? await navigator.storage.persisted() : false;
      const updateAvailable = !!registration?.waiting;
      const worker = navigator.serviceWorker.controller;
      if (!worker || !worker.scriptURL.startsWith(new URL('caripasal-sw.js', root).href)) {
        const pending = registration?.installing || registration?.waiting ||
          registration?.active?.scriptURL.startsWith(new URL('caripasal-sw.js', root).href);
        return publish({ status: pending ? 'preparing' : 'error', storagePersistent, updateAvailable,
          error: pending ? null : 'File aplikasi belum tersimpan. Sambungkan internet lalu pilih Siapkan offline.' });
      }
      const result = await query(worker);
      if (result.version !== version || !result.complete) {
        return publish({ status: 'error', storagePersistent, updateAvailable,
          error: 'File aplikasi offline belum lengkap. Sambungkan internet lalu pilih Siapkan offline.' });
      }
      return publish({ status: 'ready', storagePersistent, updateAvailable, error: null });
    } catch (_) {
      return publish({ status: 'error', error: 'Penyimpanan offline belum berhasil. Periksa koneksi dan ruang penyimpanan.' });
    }
  }
  async function register() {
    registration = await navigator.serviceWorker.register(new URL('caripasal-sw.js', root), {
      scope: root.pathname, updateViaCache: 'none',
    });
    function watch(worker) {
      worker?.addEventListener('statechange', () => {
        if (worker.state === 'redundant' && !registration.active) {
          publish({ status: 'error', error: 'File aplikasi gagal disimpan. Sambungkan internet dan coba lagi.' });
        } else if (worker.state === 'activated' || worker.state === 'installed') {
          refresh();
        }
      });
    }
    watch(registration.installing);
    registration.addEventListener('updatefound', () => watch(registration.installing));
    return refresh();
  }
  function prepare() {
    if (!supported) return refresh();
    if (preparing) return preparing;
    // Call from the user's button press; denial must not be presented as a grant.
    const persist = navigator.storage?.persist ? navigator.storage.persist().catch(() => false) : Promise.resolve(false);
    preparing = (async () => {
      publish({ status: 'preparing', error: null });
      await persist;
      try {
        await register();
        await registration.update().catch(() => {});
        const worker = navigator.serviceWorker.controller;
        if (worker) await query(worker, 'PREPARE_OFFLINE');
        return await refresh();
      } catch (_) {
        return publish({ status: 'error', error: 'Tidak dapat menyiapkan aplikasi offline. Sambungkan internet dan coba lagi.' });
      }
    })().finally(() => { preparing = null; });
    return preparing;
  }
  window.cariPasalOffline = { getState: () => state, prepare, refresh, install };
  if (supported) {
    navigator.serviceWorker.addEventListener('controllerchange', refresh);
    window.addEventListener('online', refresh);
    window.addEventListener('pageshow', refresh);
    register().catch(() => publish({ status: 'error', error: 'File aplikasi belum tersedia offline. Sambungkan internet lalu siapkan ulang.' }));
  } else {
    refresh();
  }
})();
