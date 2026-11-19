// This worker is retired. It unregisters itself and clears every cache it made,
// so a browser that picked it up earlier stops serving an old copy of the app.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => {
  e.waitUntil((async () => {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
    } catch (_) {}
    try { await self.registration.unregister(); } catch (_) {}
    const clients = await self.clients.matchAll({ type: "window" });
    clients.forEach((c) => c.navigate(c.url).catch(() => {}));
  })());
});
self.addEventListener("fetch", () => {});
