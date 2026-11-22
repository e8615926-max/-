// Кэш для игры без интернета: только свои файлы, чужие сайты не трогаем
const CACHE = 'wall-play-v104';
const FILES = ['./', './index.html', './manifest.webmanifest', './icon.svg'];
const NET_WAIT = 3500;   // медленная сеть: если есть копия в кэше, не ждём дольше — открываем её, а свежую версию докачиваем в фоне
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== self.location.origin) return;
  const net = fetch(e.request).then(r => {
    if (r.ok && r.type === 'basic') { const copy = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)).catch(() => {}); }
    return r;
  });
  const cached = () => caches.match(e.request, { ignoreSearch: true }).then(r => r || (e.request.mode === 'navigate' ? caches.match('./index.html') : undefined));
  e.waitUntil(net.catch(() => {}));   // скачивание не обрывается, даже если ответили из кэша
  e.respondWith(new Promise(done => {
    let settled = false;
    const finish = r => { if (!settled && r) { settled = true; done(r); } };
    const timer = setTimeout(() => cached().then(finish), NET_WAIT);
    net.then(r => { clearTimeout(timer); finish(r); }, () => { clearTimeout(timer); cached().then(r => { if (r) finish(r); else if (!settled) { settled = true; done(Response.error()); } }); });
  }));
});

// ---------- Push-уведомления (Firebase Cloud Messaging): приходят, даже когда сайт закрыт ----------
// сервер (api/push) шлёт только данные { title, body, url, tag } — уведомление показываем сами, одинаково на всех телефонах
self.addEventListener('push', e => {
  let p = {}; try { p = e.data ? e.data.json() : {}; } catch (x) { p = { data: { body: e.data ? e.data.text() : '' } }; }
  const d = Object.assign({}, p.notification || {}, p.data || {});
  const title = d.title || 'Wall Play', url = d.url || './';
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
    // игра открыта и на экране — не мешаем системным уведомлением, игра покажет его сама сверху
    const vis = list.find(c => c.visibilityState === 'visible' && c.focused);
    if (vis) { vis.postMessage({ wpPush: { title, body: d.body || '', url } }); return; }
    return self.registration.showNotification(title, { body: d.body || '', icon: 'icon-192.png', badge: 'icon-192.png', tag: d.tag || 'wallplay', renotify: true, data: { url }, vibrate: [80, 40, 80] });
  }));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = new URL((e.notification.data && e.notification.data.url) || './', self.location.href).href;
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
    const c = list.find(w => new URL(w.url).origin === self.location.origin);
    if (c) { c.postMessage({ wpOpen: url }); return c.focus(); }
    return self.clients.openWindow(url);
  }));
});
