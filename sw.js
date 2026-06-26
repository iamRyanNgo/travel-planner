const CACHE = 'wtn-v3';
const PRECACHE = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icons/icon.svg',
  '/icons/icon-maskable.svg',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => k !== CACHE).map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const {request} = e;
  const url = new URL(request.url);

  if (request.method !== 'GET') return;

  // Always go to the network for Supabase API and Unsplash (live data)
  if (url.hostname.includes('supabase.co') || url.hostname === 'api.unsplash.com') return;

  // Cache-first for CDN and fonts (they're versioned / rarely change)
  if (url.hostname !== self.location.hostname) {
    e.respondWith(
      caches.open(CACHE).then(async cache => {
        const cached = await cache.match(request);
        if (cached) return cached;
        const res = await fetch(request);
        if (res.ok) cache.put(request, res.clone());
        return res;
      })
    );
    return;
  }

  // Stale-while-revalidate for same-origin app shell:
  // Serve cached version immediately (instant), fetch update in background.
  // Next visit gets the fresh version. Eliminates blank-page-on-load.
  e.respondWith(
    caches.open(CACHE).then(async cache => {
      const cached = await cache.match(request);
      const networkFetch = fetch(request).then(res => {
        if (res && res.ok) cache.put(request, res.clone());
        return res;
      }).catch(() => null);

      if (cached) {
        // Serve stale immediately; update cache in background
        e.waitUntil(networkFetch);
        return cached;
      }
      // No cache yet — wait for network (first visit)
      return networkFetch || new Response('Offline — check your connection', {status: 503});
    })
  );
});
