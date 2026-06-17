// ═══════════════════════════════════════════════════════════════
// Service Worker pentru Clinica Central PWA
//
// STRATEGIE:
// - HTML și JS/CSS: NETWORK-FIRST (cere mereu de pe server)
//   evită cache prost, utilizatorul primește mereu update-uri
// - Imagini, icons: CACHE-FIRST (rapid, nu se schimbă)
// - Supabase API: NU se interceptează (vine direct de pe server)
//
// AUTO-UPDATE:
// - Service Worker activează imediat versiunea nouă
// - Notifică client-ul prin postMessage
// ═══════════════════════════════════════════════════════════════

const CACHE_VERSION = 'cc-v1.0.2'; // INCREMENTEAZĂ când faci modificări mari
const CACHE_NAME = `clinica-central-${CACHE_VERSION}`;

const STATIC_ASSETS = [
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  '/icons/icon-180.png',
  '/icons/icon-152.png',
  '/icons/icon-167.png',
  '/icons/icon-32.png',
  '/icons/icon-16.png',
  '/manifest-pacient.json',
  '/manifest-receptie.json',
  '/favicon.ico'
];

// ─── INSTALL ───
self.addEventListener('install', function(event) {
  console.log('[SW] Install', CACHE_VERSION);
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
      return Promise.all(
        STATIC_ASSETS.map(function(url) {
          return cache.add(url).catch(function() {
            console.warn('[SW] Failed to cache', url);
          });
        })
      );
    }).then(function() {
      return self.skipWaiting();
    })
  );
});

// ─── ACTIVATE ───
self.addEventListener('activate', function(event) {
  console.log('[SW] Activate', CACHE_VERSION);
  event.waitUntil(
    Promise.all([
      caches.keys().then(function(cacheNames) {
        return Promise.all(
          cacheNames.map(function(name) {
            if (name !== CACHE_NAME && name.indexOf('clinica-central-') === 0) {
              console.log('[SW] Removing old cache', name);
              return caches.delete(name);
            }
          })
        );
      }),
      self.clients.claim()
    ]).then(function() {
      return self.clients.matchAll().then(function(clients) {
        clients.forEach(function(client) {
          client.postMessage({ type: 'SW_UPDATED', version: CACHE_VERSION });
        });
      });
    })
  );
});

// ─── FETCH ───
self.addEventListener('fetch', function(event) {
  const url = new URL(event.request.url);

  // NU intercepta Supabase API
  if (url.hostname.indexOf('supabase.co') >= 0) return;

  // NU intercepta non-GET
  if (event.request.method !== 'GET') return;

  // NU intercepta cross-origin
  if (url.origin !== self.location.origin) return;

  const acceptHeader = event.request.headers.get('accept') || '';
  const isHTML = acceptHeader.indexOf('text/html') >= 0;
  const isJS = url.pathname.endsWith('.js');
  const isCSS = url.pathname.endsWith('.css');
  const isImage = /\.(png|jpg|jpeg|gif|svg|webp|ico)$/i.test(url.pathname);
  const isManifest = url.pathname.endsWith('.json');

  // STRATEGIE: Network-first pentru cod (HTML, JS, CSS, JSON)
  if (isHTML || isJS || isCSS || isManifest) {
    event.respondWith(
      fetch(event.request)
        .then(function(response) {
          if (response.ok) {
            var clone = response.clone();
            caches.open(CACHE_NAME).then(function(cache) {
              cache.put(event.request, clone);
            });
          }
          return response;
        })
        .catch(function() {
          return caches.match(event.request).then(function(cached) {
            if (cached) return cached;
            if (isHTML) {
              return caches.match('/pacient.html')
                .then(function(c) { return c || caches.match('/receptie.html'); });
            }
            return new Response('Offline', { status: 503 });
          });
        })
    );
    return;
  }

  // STRATEGIE: Cache-first pentru imagini
  if (isImage) {
    event.respondWith(
      caches.match(event.request).then(function(cached) {
        if (cached) {
          // Update silent în background
          fetch(event.request).then(function(response) {
            if (response.ok) {
              var clone = response.clone();
              caches.open(CACHE_NAME).then(function(cache) {
                cache.put(event.request, clone);
              });
            }
          }).catch(function() {});
          return cached;
        }
        return fetch(event.request).then(function(response) {
          if (response.ok) {
            var clone = response.clone();
            caches.open(CACHE_NAME).then(function(cache) {
              cache.put(event.request, clone);
            });
          }
          return response;
        });
      })
    );
    return;
  }

  // Restul — direct la network
});

// ─── MESSAGES ───
self.addEventListener('message', function(event) {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  if (event.data && event.data.type === 'CLEAR_CACHE') {
    caches.keys().then(function(cacheNames) {
      return Promise.all(cacheNames.map(function(name) {
        return caches.delete(name);
      }));
    });
  }
});
