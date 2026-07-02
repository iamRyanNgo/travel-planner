const CACHE = 'wtn-v6';

self.addEventListener('install', e => {
  // No HTML precaching — navigation always goes to the network so the page
  // is never stale. Only assets (CDN scripts, fonts) get cached.
  e.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', e => {
  e.waitUntil(
    Promise.all([
      // Delete all old caches
      caches.keys().then(keys => Promise.all(
        keys.filter(k => k !== CACHE).map(k => caches.delete(k))
      )),
      // Enable navigation preload so the browser can start the network
      // request for the HTML page in parallel with SW boot (no SW latency)
      self.registration.navigationPreload?.enable().catch(() => {}),
      self.clients.claim(),
    ])
  );
});

self.addEventListener('fetch', e => {
  const {request} = e;
  const url = new URL(request.url);

  if (request.method !== 'GET') return;

  // Skip Supabase + Unsplash + geo/weather APIs — always live data
  if (url.hostname.includes('supabase.co') || url.hostname === 'api.unsplash.com' ||
      url.hostname.endsWith('openstreetmap.org') || url.hostname.endsWith('open-meteo.com') ||
      url.hostname.endsWith('frankfurter.dev') || url.hostname.endsWith('open.er-api.com')) return;

  // HTML navigation: network-first so the page is never stale, but keep the
  // last good copy so the app still opens with no connection (trip data is
  // then served from localStorage by the app itself).
  if (request.mode === 'navigate') {
    e.respondWith((async () => {
      try {
        const preload = await e.preloadResponse;
        const res = preload || await fetch(request);
        if (res && res.ok) {
          const cache = await caches.open(CACHE);
          cache.put('/', res.clone());
        }
        return res;
      } catch (err) {
        const cached = await caches.match('/');
        if (cached) return cached;
        throw err;
      }
    })());
    return;
  }

  // Never cache images — profile pictures change, and a cached corrupt
  // image shows broken avatars on every soft refresh.
  if (request.destination === 'image') return;

  // Cache-first for scripts, fonts, and other stable assets.
  e.respondWith(
    caches.open(CACHE).then(async cache => {
      const cached = await cache.match(request);
      if (cached) return cached;
      const res = await fetch(request);
      if (res.ok) cache.put(request, res.clone());
      return res;
    })
  );
});
