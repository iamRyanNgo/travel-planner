const CACHE = 'wtn-v4';

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

  // Skip Supabase + Unsplash — always live data
  if (url.hostname.includes('supabase.co') || url.hostname === 'api.unsplash.com') return;

  // HTML navigation requests: let them go straight to the network.
  // Using navigation preload means there's zero SW overhead — the browser
  // starts the fetch while the SW boots. Never caching HTML prevents the
  // blank-page-on-load issue caused by serving stale content.
  if (request.mode === 'navigate') {
    e.respondWith((async () => {
      try {
        const preload = await e.preloadResponse;
        if (preload) return preload;
      } catch {}
      return fetch(request);
    })());
    return;
  }

  // Cache-first for all other requests: CDN scripts, fonts, icons.
  // These are versioned/stable assets — safe to cache indefinitely.
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
