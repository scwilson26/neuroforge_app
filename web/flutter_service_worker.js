// Minimal app-shell cache; exclude large downloads (.zip)
const CACHE_NAME = 'spaced-shell-v1';
const SHELL_ASSETS = [
  '/',
  'index.html',
  'flutter.js',
  'flutter_bootstrap.js',
  'manifest.json',
  'favicon.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_ASSETS))
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.map((k) => k === CACHE_NAME ? null : caches.delete(k))))
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  // Bypass caching for ZIP and POST requests
  if (event.request.method !== 'GET' || url.pathname.endsWith('.zip')) {
    return;
  }
  event.respondWith(
    caches.match(event.request).then((resp) => resp || fetch(event.request))
  );
});
