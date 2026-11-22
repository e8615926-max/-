// Wall Play — push-уведомления (Firebase Cloud Messaging, HTTP v1) через функцию Vercel. Без зависимостей.
//
// Переменные окружения Vercel (Project → Settings → Environment Variables):
//   FIREBASE_SERVICE_ACCOUNT — СЕКРЕТ: JSON ключа сервисного аккаунта Firebase целиком (Project settings → Service accounts → Generate new private key)
//   FCM_VAPID_KEY            — публичный ключ Web Push (Project settings → Cloud Messaging → Web Push certificates → Key pair)
//   FIREBASE_APP_ID          — appId веб-приложения (Project settings → General → Your apps → appId, вида 1:629…:web:…)
//   FIREBASE_SENDER_ID       — Sender ID (Project settings → Cloud Messaging → Sender ID; это число из начала appId)
//   PUSH_ADMIN_KEY           — СЕКРЕТ: свой пароль для ручной рассылки (любая длинная строка)
//   CRON_SECRET              — СЕКРЕТ: любая длинная строка; Vercel сам подставляет его в ежедневный запуск по расписанию
// необязательно: FIREBASE_API_KEY, FIREBASE_DB_URL — если отличаются от вписанных в игру
//
// Запросы:
//   GET  /api/push?cfg=1                         → публичные настройки для страницы игры (без секретов)
//   POST /api/push { type:'freq', to, idToken }  → уведомление «заявка в друзья» (проверяется вход и сама заявка в базе)
//   POST /api/push (Authorization: Bearer PUSH_ADMIN_KEY) { title, body, url?, uid? } → ручная рассылка всем или одному
//   GET  /api/push?cron=daily (Authorization: Bearer CRON_SECRET) → ежедневное «новые скины дня» тем, кто не выключил
import { createSign, timingSafeEqual } from 'node:crypto';

const API_KEY = process.env.FIREBASE_API_KEY || 'AIzaSyAZ3PX79SZJBTdCwo7F8aNhUSq_2hbmtmc';
const DB = (process.env.FIREBASE_DB_URL || 'https://wall-play-4abb3-default-rtdb.europe-west1.firebasedatabase.app').replace(/\/$/, '');
const SITE = 'https://wall-play.vercel.app/';

const json = (o, status = 200, extra = {}) => new Response(JSON.stringify(o), { status, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...extra } });
const same = (a, b) => { if (!a || !b) return false; const x = Buffer.from(String(a)), y = Buffer.from(String(b)); return x.length === y.length && timingSafeEqual(x, y); };
const bearer = req => (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');

// ---------- доступ Google по ключу сервисного аккаунта (JWT → access token), кэш на время жизни экземпляра ----------
let SA = null, TOK = null;
function sa() {
  if (SA) return SA;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT; if (!raw) return null;
  try { const j = JSON.parse(raw.trim().startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8')); j.private_key = String(j.private_key || '').replace(/\\n/g, '\n'); SA = j; return j; } catch (e) { return null; }
}
async function token() {
  if (TOK && Date.now() < TOK.exp - 60000) return TOK.t;
  const s = sa(); if (!s) throw new Error('no service account');
  const now = Math.floor(Date.now() / 1000), b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  const head = b64({ alg: 'RS256', typ: 'JWT' }), body = b64({ iss: s.client_email, aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/firebase.database https://www.googleapis.com/auth/userinfo.email' });
  const sig = createSign('RSA-SHA256').update(head + '.' + body).sign(s.private_key).toString('base64url');
  const r = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=' + encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer') + '&assertion=' + head + '.' + body + '.' + sig });
  const j = await r.json(); if (!r.ok || !j.access_token) throw new Error('oauth ' + r.status);
  TOK = { t: j.access_token, exp: Date.now() + (j.expires_in || 3600) * 1000 }; return TOK.t;
}
// база — с правами администратора (правила для сервера не действуют)
async function db(method, path, body) {
  const r = await fetch(DB + '/' + path + '.json?access_token=' + encodeURIComponent(await token()), { method, body: body === undefined ? undefined : JSON.stringify(body) });
  if (!r.ok) throw new Error('db ' + r.status); return r.json();
}

// ---------- тексты на языке игрока ----------
const L = {
  freq: { ru: ['Заявка в друзья', '{n} хочет дружить в Wall Play!'], en: ['Friend request', '{n} wants to be friends in Wall Play!'], uk: ['Запит у друзі', '{n} хоче дружити у Wall Play!'], kk: ['Достық өтінімі', '{n} Wall Play-де дос болғысы келеді!'],
    es: ['Solicitud de amistad', '¡{n} quiere ser tu amigo en Wall Play!'], de: ['Freundschaftsanfrage', '{n} möchte dein Freund in Wall Play sein!'], fr: ["Demande d'ami", '{n} veut être ton ami dans Wall Play !'], pt: ['Pedido de amizade', '{n} quer ser seu amigo no Wall Play!'],
    it: ['Richiesta di amicizia', '{n} vuole essere tuo amico su Wall Play!'], tr: ['Arkadaşlık isteği', '{n} Wall Play\'de arkadaşın olmak istiyor!'], pl: ['Zaproszenie do znajomych', '{n} chce być twoim znajomym w Wall Play!'] },
  facc: { ru: ['Новый друг!', '{n} принял(а) твою заявку'], en: ['New friend!', '{n} accepted your request'], uk: ['Новий друг!', '{n} прийняв(ла) твій запит'], kk: ['Жаңа дос!', '{n} өтініміңді қабылдады'],
    es: ['¡Nuevo amigo!', '{n} aceptó tu solicitud'], de: ['Neuer Freund!', '{n} hat deine Anfrage angenommen'], fr: ['Nouvel ami !', '{n} a accepté ta demande'], pt: ['Novo amigo!', '{n} aceitou seu pedido'],
    it: ['Nuovo amico!', '{n} ha accettato la tua richiesta'], tr: ['Yeni arkadaş!', '{n} isteğini kabul etti'], pl: ['Nowy znajomy!', '{n} przyjął(-ęła) zaproszenie'] },
  daily: { ru: ['Новые скины дня!', 'Магазин обновился: скидки до −70% и бесплатная награда за вход'], en: ['New skins of the day!', 'The shop is updated: up to −70% off and a free daily reward'],
    uk: ['Нові скіни дня!', 'Магазин оновився: знижки до −70% і безкоштовна нагорода'], kk: ['Күннің жаңа скиндері!', 'Дүкен жаңарды: −70%-ға дейін жеңілдік'],
    es: ['¡Nuevas skins del día!', 'Tienda nueva: hasta −70% y premio diario gratis'], de: ['Neue Tages-Skins!', 'Shop aktualisiert: bis −70% und Gratis-Belohnung'], fr: ['Nouveaux skins du jour !', 'Boutique à jour : jusqu’à −70 % et cadeau gratuit'],
    pt: ['Novas skins do dia!', 'Loja atualizada: até −70% e prêmio diário grátis'], it: ['Nuove skin del giorno!', 'Negozio aggiornato: fino al −70% e premio gratis'], tr: ['Günün yeni kostümleri!', 'Mağaza yenilendi: %70’e varan indirim ve ücretsiz ödül'],
    pl: ['Nowe skórki dnia!', 'Sklep odświeżony: do −70% i darmowa nagroda'] },
};
const txt = (kind, lang, vars = {}) => { const t = (L[kind][lang] || L[kind].en).map(s => s.replace('{n}', String(vars.n || '').slice(0, 16))); return { title: t[0], body: t[1] }; };

// ---------- отправка одного сообщения; ответ «токен устарел» — убираем его из базы ----------
async function send(uid, rec, msg) {
  if (!rec || typeof rec.k !== 'string') return 'skip';
  const s = sa(), data = { title: String(msg.title).slice(0, 80), body: String(msg.body).slice(0, 200), url: msg.url || SITE, tag: msg.tag || 'wallplay' };
  const r = await fetch('https://fcm.googleapis.com/v1/projects/' + s.project_id + '/messages:send', { method: 'POST', headers: { authorization: 'Bearer ' + await token(), 'content-type': 'application/json' },
    body: JSON.stringify({ message: { token: rec.k, data, webpush: { headers: { Urgency: 'high', TTL: String(msg.ttl || 86400) } } } }) });
  if (r.ok) return 'ok';
  const e = await r.text().catch(() => '');
  if (r.status === 404 || /UNREGISTERED|registration-token-not-registered|INVALID_ARGUMENT/.test(e)) { await db('DELETE', 'push/' + uid).catch(() => {}); return 'gone'; }
  return 'err ' + r.status;
}
async function broadcast(build, filter = () => true) {
  const all = (await db('GET', 'push')) || {}, out = { ok: 0, gone: 0, err: 0, skip: 0 }, ids = Object.keys(all).filter(u => filter(all[u]));
  for (let i = 0; i < ids.length; i += 40) {   // по 40 параллельно — быстро и в лимитах FCM
    const res = await Promise.all(ids.slice(i, i + 40).map(u => send(u, all[u], build(all[u])).catch(() => 'err')));
    for (const r of res) out[r === 'ok' ? 'ok' : r === 'gone' ? 'gone' : r === 'skip' ? 'skip' : 'err']++;
  }
  return out;
}
// кто вызывает: проверяем вход Firebase игрока по его idToken
async function whoIs(idToken) {
  if (typeof idToken !== 'string' || idToken.length > 4000) return null;
  const r = await fetch('https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' + API_KEY, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ idToken }) });
  if (!r.ok) return null; const j = await r.json(); return (j.users && j.users[0] && j.users[0].localId) || null;
}

const CORS = { 'access-control-allow-origin': SITE.slice(0, -1), 'access-control-allow-methods': 'GET, POST', 'access-control-allow-headers': 'content-type' };

export default {
  async fetch(req) {
    const u = new URL(req.url);
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
    if (req.method === 'GET' && u.searchParams.get('cfg')) {
      const s = sa(), cfg = { on: !!(s && process.env.FCM_VAPID_KEY && process.env.FIREBASE_APP_ID), apiKey: API_KEY, projectId: (s && s.project_id) || 'wall-play-4abb3',
        senderId: process.env.FIREBASE_SENDER_ID || String(process.env.FIREBASE_APP_ID || '').split(':')[1] || '', appId: process.env.FIREBASE_APP_ID || '', vapid: process.env.FCM_VAPID_KEY || '' };
      return json(cfg, 200, { ...CORS, 'cache-control': 'public, max-age=300' });
    }
    if (!sa()) return json({ error: 'FIREBASE_SERVICE_ACCOUNT is not set' }, 503, CORS);
    try {
      // ежедневная рассылка по расписанию Vercel
      if (u.searchParams.get('cron') === 'daily') {
        if (!process.env.CRON_SECRET || !same(bearer(req), process.env.CRON_SECRET)) return json({ error: 'unauthorized' }, 401);
        return json(await broadcast(r => ({ ...txt('daily', r.l), tag: 'daily', ttl: 6 * 3600 }), r => r.d !== false));
      }
      if (req.method !== 'POST') return json({ error: 'method' }, 405, CORS);
      const b = await req.json().catch(() => ({}));
      // ручная рассылка администратора
      if (process.env.PUSH_ADMIN_KEY && same(bearer(req), process.env.PUSH_ADMIN_KEY)) {
        if (!b.title || !b.body) return json({ error: 'title and body required' }, 400);
        const m = { title: b.title, body: b.body, url: b.url, tag: b.tag || 'news' };
        if (b.uid) return json({ r: await send(b.uid, await db('GET', 'push/' + encodeURIComponent(b.uid)), m) });
        return json(await broadcast(() => m));
      }
      // друзья: заявка или «принял заявку». Проверяем вход, наличие свежей записи в базе и не чаще раза в минуту на адресата
      if (b.type === 'freq' && typeof b.to === 'string' && /^[A-Za-z0-9_-]{6,64}$/.test(b.to)) {
        const me = await whoIs(b.idToken); if (!me || me === b.to) return json({ error: 'auth' }, 401, CORS);
        const q = await db('GET', 'freq/' + b.to + '/' + me);
        if (!q || typeof q.t !== 'number' || Date.now() - q.t > 120000) return json({ r: 'no request' }, 200, CORS);
        const rec = await db('GET', 'push/' + b.to);
        if (!rec || rec.f === false) return json({ r: 'off' }, 200, CORS);
        if (rec.lf && Date.now() - rec.lf < 60000) return json({ r: 'later' }, 200, CORS);
        await db('PATCH', 'push/' + b.to, { lf: Date.now() });
        return json({ r: await send(b.to, rec, { ...txt(q.ok ? 'facc' : 'freq', rec.l, { n: q.n }), url: SITE + '#friends', tag: 'friend-' + me }) }, 200, CORS);
      }
      return json({ error: 'bad request' }, 400, CORS);
    } catch (e) { return json({ error: String(e && e.message || e) }, 500, CORS); }
  },
};
