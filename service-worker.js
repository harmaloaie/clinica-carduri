// Service Worker pentru Clinica Central PWA
// Versiunea cache-ului - INCREMENTEAZĂ când faci modificări la fișiere
const CACHE_VERSION = 'cc-v1.0.0';
const CACHE_NAME = `clinica-central-${CACHE_VERSION}`;

// Resurse esențiale pentru PWA (UI shell)
// Datele dinamice (Supabase) NU sunt cache-uite — vin live întotdeauna
const STATIC_ASSETS = [
  '/pacient.html',
  '/receptie.html',
  '/card.html',
  '/login.html',
  '/index.html',
  '/shared/supabase-client.js',
  '/shared/config.js',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  '/icons/icon-180.png',
  '/manifest-pacient.json',
  '/manifest-receptie.json'
];

// Install event — cache static assets
self.addEventListener('install', function(event) {
  console.log('[SW] Install', CACHE_VERSION);
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
      console.log('[SW] Caching static assets');
      // Cache-uim individual ca să nu eșueze tot dacă unul nu se găsește
      return Promise.all(
        STATIC_ASSETS.map(function(url) {
          return cache.add(url).catch(function(err) {
            console.warn('[SW] Failed to cache', url, err);
          });
        })
      );
    }).then(function() {
      // Skip waiting — activează imediat versiunea nouă
      return self.skipWaiting();
    })
  );
});

// Activate — cleanup vechile caches
self.addEventListener('activate', function(event) {
  console.log('[SW] Activate', CACHE_VERSION);
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(name) {
          if (name !== CACHE_NAME && name.startsWith('clinica-central-')) {
            console.log('[SW] Removing old cache', name);
            return caches.delete(name);
          }
        })
      );
    }).then(function() {
      // Take control of all open clients
      return self.clients.claim();
    })
  );
});

// Fetch — strategy: Network-first pentru API/dinamic, Cache-first pentru static
self.addEventListener('fetch', function(event) {
  const url = new URL(event.request.url);

  // NU intercepta cereri Supabase (API-ul trebuie mereu să fie live)
  if (url.hostname.indexOf('supabase.co') >= 0) return;

  // NU intercepta cereri non-GET
  if (event.request.method !== 'GET') return;

  // NU intercepta cereri cross-origin (CDN-uri externe etc.)
  if (url.origin !== self.location.origin) return;

  // Strategy: Network-first pentru HTML (ca să primești update-uri rapid)
  if (event.request.headers.get('accept').indexOf('text/html') >= 0) {
    event.respondWith(
      fetch(event.request)
        .then(function(response) {
          // Salvează în cache versiunea nouă
          var responseClone = response.clone();
          caches.open(CACHE_NAME).then(function(cache) {
            cache.put(event.request, responseClone);
          });
          return response;
        })
        .catch(function() {
          // Offline — servește din cache
          return caches.match(event.request).then(function(cached) {
            if (cached) return cached;
            // Fallback la pacient.html dacă nimic nu se găsește
            return caches.match('/pacient.html');
          });
        })
    );
    return;
  }

  // Strategy: Cache-first pentru assets statice (JS, CSS, imagini)
  event.respondWith(
    caches.match(event.request).then(function(cached) {
      if (cached) {
        // Întoarcă din cache, dar update silent în background
        fetch(event.request).then(function(response) {
          if (response.ok) {
            var responseClone = response.clone();
            caches.open(CACHE_NAME).then(function(cache) {
              cache.put(event.request, responseClone);
            });
          }
        }).catch(function() {/* offline, ok */});
        return cached;
      }
      // Nu e în cache — fetch from network
      return fetch(event.request).then(function(response) {
        if (response.ok) {
          var responseClone = response.clone();
          caches.open(CACHE_NAME).then(function(cache) {
            cache.put(event.request, responseClone);
          });
        }
        return response;
      });
    })
  );
});

// Listen for messages from client (e.g., manual update trigger)
self.addEventListener('message', function(event) {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
