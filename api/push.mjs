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
//   GET  /api/push?cron=remind (Authorization: Bearer CRON_SECRET) → напоминание раз в 3 часа (5 сообщений по кругу), ночью у игрока — нет
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
// напоминания раз в 3 часа: 5 сообщений по кругу, у каждого игрока — на его языке
const REMIND = {"ru": [["Награды тебя ждут! 🎁", "Загляни в игру — монеты и подарки уже на месте"], ["Можно крутить колесо! 🎡", "Бесплатный спин готов — испытай удачу"], ["Новые квесты! 📜", "Свежие задания и опыт для Pass ждут тебя"], ["Сундук уже готов! 🧰", "Открой его, пока не опередили друзья"], ["Победы дня уже обновились! 🏆", "Новые призы за победы — начни забег"]], "en": [["Rewards are waiting! 🎁", "Hop in — coins and gifts are ready for you"], ["You can spin the wheel! 🎡", "A free spin is ready — try your luck"], ["New quests! 📜", "Fresh tasks and Pass XP are waiting"], ["Your chest is ready! 🧰", "Open it before your friends get ahead"], ["Daily wins are refreshed! 🏆", "New prizes for wins — start a run"]], "uk": [["Нагороди чекають! 🎁", "Зазирни в гру — монети й подарунки вже тут"], ["Можна крутити колесо! 🎡", "Безкоштовний спін готовий — спробуй удачу"], ["Нові квести! 📜", "Свіжі завдання й досвід для Pass чекають"], ["Скриня вже готова! 🧰", "Відкрий її, поки друзі не випередили"], ["Перемоги дня оновилися! 🏆", "Нові призи за перемоги — починай забіг"]], "kk": [["Сыйлықтар сені күтеді! 🎁", "Ойынға кір — тиындар мен сыйлықтар дайын"], ["Дөңгелекті айналдыруға болады! 🎡", "Тегін айналдыру дайын — бағыңды сына"], ["Жаңа тапсырмалар! 📜", "Жаңа тапсырмалар мен Pass тәжірибесі күтіп тұр"], ["Сандық дайын! 🧰", "Достарың озып кетпей тұрып аш"], ["Күн жеңістері жаңарды! 🏆", "Жеңістер үшін жаңа жүлделер — жүгіруді баста"]], "es": [["¡Te esperan recompensas! 🎁", "Entra — monedas y regalos listos para ti"], ["¡Puedes girar la ruleta! 🎡", "Tienes un giro gratis — prueba tu suerte"], ["¡Nuevas misiones! 📜", "Tareas nuevas y XP del Pass te esperan"], ["¡El cofre está listo! 🧰", "Ábrelo antes de que tus amigos te adelanten"], ["¡Victorias del día renovadas! 🏆", "Nuevos premios por ganar — empieza una partida"]], "de": [["Belohnungen warten! 🎁", "Schau rein — Münzen und Geschenke sind bereit"], ["Das Glücksrad wartet! 🎡", "Ein Gratis-Dreh ist bereit — versuch dein Glück"], ["Neue Aufgaben! 📜", "Frische Aufgaben und Pass-XP warten auf dich"], ["Deine Truhe ist bereit! 🧰", "Öffne sie, bevor deine Freunde vorbeiziehen"], ["Tagessiege sind neu! 🏆", "Neue Preise für Siege — starte einen Lauf"]], "fr": [["Des récompenses t’attendent ! 🎁", "Viens jouer — pièces et cadeaux sont prêts"], ["Tu peux tourner la roue ! 🎡", "Un tour gratuit t’attend — tente ta chance"], ["Nouvelles quêtes ! 📜", "Nouvelles missions et XP du Pass t’attendent"], ["Ton coffre est prêt ! 🧰", "Ouvre-le avant que tes amis ne te dépassent"], ["Victoires du jour renouvelées ! 🏆", "Nouveaux prix pour tes victoires — lance une partie"]], "pt": [["Recompensas te esperam! 🎁", "Entre — moedas e presentes estão prontos"], ["Você pode girar a roleta! 🎡", "Um giro grátis está pronto — teste a sorte"], ["Novas missões! 📜", "Tarefas novas e XP do Pass esperam por você"], ["O baú está pronto! 🧰", "Abra antes que seus amigos passem na frente"], ["Vitórias do dia renovadas! 🏆", "Novos prêmios por vitórias — comece uma corrida"]], "it": [["Ti aspettano ricompense! 🎁", "Entra — monete e regali sono pronti"], ["Puoi girare la ruota! 🎡", "Un giro gratis è pronto — tenta la fortuna"], ["Nuove missioni! 📜", "Nuovi compiti e XP del Pass ti aspettano"], ["Il forziere è pronto! 🧰", "Aprilo prima che i tuoi amici ti superino"], ["Vittorie del giorno rinnovate! 🏆", "Nuovi premi per le vittorie — inizia una corsa"]], "tr": [["Ödüller seni bekliyor! 🎁", "Oyuna gir — altınlar ve hediyeler hazır"], ["Çarkı çevirebilirsin! 🎡", "Ücretsiz çevirme hazır — şansını dene"], ["Yeni görevler! 📜", "Yeni görevler ve Pass XP seni bekliyor"], ["Sandık hazır! 🧰", "Arkadaşların geçmeden onu aç"], ["Günün zaferleri yenilendi! 🏆", "Zaferler için yeni ödüller — koşuya başla"]], "pl": [["Nagrody czekają! 🎁", "Wpadnij — monety i prezenty są gotowe"], ["Możesz zakręcić kołem! 🎡", "Darmowy obrót czeka — sprawdź swoje szczęście"], ["Nowe zadania! 📜", "Świeże zadania i XP do Passa czekają"], ["Skrzynia jest gotowa! 🧰", "Otwórz ją, zanim znajomi cię wyprzedzą"], ["Wygrane dnia odświeżone! 🏆", "Nowe nagrody za wygrane — zacznij bieg"]]};
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
      if (u.searchParams.get('cron') === 'remind') {
        if (!process.env.CRON_SECRET || !same(bearer(req), process.env.CRON_SECRET)) return json({ error: 'unauthorized' }, 401);
        const slot = Math.floor(Date.now() / (3 * 3600e3)), now = Date.now();
        // ночь у игрока (23:00–8:00 по его часам; z — смещение пояса в минутах, по умолчанию Москва) — не будим
        const awake = r => { const z = typeof r.z === 'number' && Math.abs(r.z) <= 840 ? r.z : 180, h = new Date(now + z * 60000).getUTCHours(); return h >= 8 && h < 23; };
        return json(await broadcast(r => { const m = (REMIND[r.l] || REMIND.en)[slot % 5]; return { title: m[0], body: m[1], tag: 'remind', ttl: 3 * 3600 }; }, r => r.r !== false && awake(r)));
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
