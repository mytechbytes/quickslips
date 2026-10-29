// Bump VERSION whenever a cached file (wasm/fonts) changes.
const VERSION = "v1"
const CACHE = `quickslips-static-${VERSION}`

self.addEventListener("install", (event) => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((key) => key.startsWith("quickslips-static-") && key !== CACHE).map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  )
})

// Cache-first for the big static files; everything else goes straight to the network.
self.addEventListener("fetch", (event) => {
  const { request } = event
  const url = new URL(request.url)

  const cacheable = url.origin === location.origin && (url.pathname.startsWith("/wasm/") || url.pathname.startsWith("/fonts/"))
  if (request.method !== "GET" || !cacheable) return

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const hit = await cache.match(request)
      if (hit) return hit
      const response = await fetch(request)
      if (response.ok) cache.put(request, response.clone())
      return response
    }),
  )
})
