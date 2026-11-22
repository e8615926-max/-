// Wall Play Skin Maker — Eldar Company. Свои скины и аватарки по клеткам, с анимацией и аурой; лента, лайки, поиск, профили, конкурс.
// Данные — в той же базе Firebase, что и игра (тот же сайт — тот же вход и ник игрока). Без сети работает на этом устройстве.
'use strict';
const FB_KEY = 'AIzaSyAZ3PX79SZJBTdCwo7F8aNhUSq_2hbmtmc', FB_DB = 'https://wall-play-4abb3-default-rtdb.europe-west1.firebasedatabase.app';
const G = 32;                 // клеток по стороне
const MAX_F = 4;              // кадров анимации
const ROUND0 = new Date(2026, 10, 22).getTime(), DAY = 864e5, SUBMIT_D = 10, FINAL_D = 1;
const $ = s => document.querySelector(s), el = (t, c, txt) => { const e = document.createElement(t); if (c) e.className = c; if (txt != null) e.textContent = txt; return e; };
const hash = n => { let x = Math.imul(n | 0, 2654435761) ^ 0x5bd1e995; x ^= x >>> 15; x = Math.imul(x, 2246822519); x ^= x >>> 13; return ((x >>> 0) % 100000) / 100000; };
const strHash = s => { let h = 7; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0; return h; };
const ls = { get(k, d) { try { const v = localStorage.getItem('sm_' + k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } }, set(k, v) { try { localStorage.setItem('sm_' + k, JSON.stringify(v)); } catch (e) {} } };
const lang = (() => { try { const v = JSON.parse(localStorage.getItem('wk3_lang') || 'null'); if (v) return v; } catch (e) {} return (navigator.language || 'ru').slice(0, 2); })();
const RU = lang === 'ru' || lang === 'uk' || lang === 'kk';
const T = (ru, en) => RU ? ru : en;

// ---------- шаблон: хомяк из игры, 4 кадра дыхания ----------
const TPL = {"pal":["#4a2410","#f0a040","#ff9fb0","#ffffff","#1a1010","#ffe6b0","#ff5a8a","#ff9ab8","#ff3d7f","#c01f5a","#c06a20"],"frames":["..........................................................................................................................................000....00000...................01110..0011110.................0111110.0112110.................012221000122210.................012211111111110..................01111111111100.................0011111111111100................0111111113411340................0111111114411440................0111111114411440................0111111115555566................0111111155555550................0111117755555550................8911111155555550...............9898888888888880................9..8888888888880...............8...0999999999990..............98...01115555511110.............9....01115555511110..................0111555555110...................0111555555100...................001155555500....................0aaaa55aaaaa0..................0aaaaaa0aaaaa0...................0aaaa00aaaaa0....................0000..00000..........................................................................","..........................................................................000....00000...................01110..0011110.................0111110.0112110.................012221000122210.................012211111111110..................01111111111100.................0011111111111100................0111111113411340................0111111114411440................0111111114411440................0111111115555566................0111111155555550................0111117755555550................0011111155555550.............98..08888888888880..............989..8888888888880................98909999999999910................8911115555551110.................011155555551110.................011155555551110.................01115555555510..................01115555555510..................00115555555500...................011155555510....................0aaaa55aaaaa0..................0aaaaaa1aaaaa0...................0aaaa00aaaaa0....................0000..00000..........................................................................","..........................................................................................................................................000....00000...................01110..0011110.................0111110.0112110.................012221000122210.................012211111111110..................01111111111100.................0011111111111100................0111111113411340................0111111114411440................0111111114411440................0111111115555566................0111111155555550................0111117755555550................0981111155555550................898888888888880................98.0888888888880................9..0999999999990..............98...01115555511110.............98...01115555511110..................0111555555110...................0111555555100...................001155555500....................0aaaa55aaaaa0..................0aaaaaa0aaaaa0...................0aaaa00aaaaa0....................0000..00000..........................................................................","..........................................................................................................................................000....00000...................01110..0011110.................0111110.0112110.................012221000122210.................012211111111110..................01111111111100.................0011111111111100................0111111111111110................0111111111111110................0111111114411440................0111111115555566................0111111155555550................0111117755555550................0011111155555550..............89.00888888888880..............9898.8888888888880..............9..898999999999990..................901115555511110..................01115555511110..................0111555555110...................0111555555100...................001155555500....................0aaaa55aaaaa0..................0aaaaaa0aaaaa0...................0aaaa00aaaaa0....................0000..00000.........................................................................."]};
const tplFrames = () => TPL.frames.map(s => [...s].map(ch => ch === '.' ? null : TPL.pal[parseInt(ch, 36)]));

// ---------- вход: игровой аккаунт (тот же сайт) или свой гость ----------
const ME = { uid: null, tok: null, exp: 0, nick: (() => { try { return JSON.parse(localStorage.getItem('wk3_mpnick') || 'null'); } catch (e) { return null; } })() || ls.get('nick', '') || ('PLAYER' + Math.floor(100 + Math.random() * 900)), online: false };
async function auth() {
  if (ME.tok && Date.now() < ME.exp - 60000) return ME.tok;
  let rt = null; try { const g = JSON.parse(localStorage.getItem('wk3_fbAuth') || 'null'); if (g && g.rt) rt = g.rt; } catch (e) {}
  if (!rt) { const s = ls.get('auth', null); if (s && s.rt) rt = s.rt; }
  let j = null;
  if (rt) { const r = await fetch('https://securetoken.googleapis.com/v1/token?key=' + FB_KEY, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'grant_type=refresh_token&refresh_token=' + encodeURIComponent(rt) }); if (r.ok) { const q = await r.json(); j = { tok: q.id_token, uid: q.user_id, exp: +q.expires_in }; } }
  if (!j) { const r = await fetch('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=' + FB_KEY, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{"returnSecureToken":true}' }); if (!r.ok) throw new Error('auth'); const q = await r.json(); j = { tok: q.idToken, uid: q.localId, exp: +q.expiresIn }; ls.set('auth', { rt: q.refreshToken }); }
  ME.tok = j.tok; ME.uid = j.uid; ME.exp = Date.now() + (j.exp || 3600) * 1000; return ME.tok;
}
async function db(method, path, body, q = '') {
  const tok = await auth(), r = await fetch(FB_DB + '/' + path + '.json?auth=' + tok + q, { method, headers: { 'Content-Type': 'application/json' }, body: body === undefined ? undefined : JSON.stringify(body) });
  if (!r.ok) { const e = new Error('db ' + r.status); e.status = r.status; throw e; } return r.json();
}

// ---------- NPC-авторы: свои скины и лайки (сайт живой, даже когда игроков мало) ----------
const BOTS = ['PIXELKING', 'LUNA_ART', 'MRBLACK_2008', 'KOTIK_MUR', 'ZOMBIE_MAX', 'STARGIRL', 'DRAKON777', 'NEO_HAMSTER', 'ARTEMKA', 'MILA_PIXEL', 'GAMER_PRO', 'SKY_WOLF', 'ICE_QUEEN', 'TOXIC_FOX', 'BANANA_BRO', 'NINJA_KZ'];
const BOT_IDEAS = [['ОГНЕННЫЙ ХОМЯК', 'FIRE HAMSTER', 'fire', '#ff5a1a', 0, 'horns'], ['ЛЕДЯНОЙ ПРИНЦ', 'ICE PRINCE', 'snow', '#7ad8ff', 200, 'crown'], ['КИБЕР-ХОМ', 'CYBER HAM', 'spark', '#3af0ff', 180, 'visor'], ['ЗОМБИ-ХОМЯК', 'ZOMBIE HAM', 'glow', '#7aff5a', 90, 'none'],
  ['ЗВЁЗДНЫЙ МАГ', 'STAR MAGE', 'spark', '#ffe24a', 270, 'wizard'], ['РОЗОВАЯ МЕЧТА', 'PINK DREAM', 'heart', '#ff7ad8', 320, 'bow'], ['НИНДЗЯ ТЕНЕЙ', 'SHADOW NINJA', 'glow', '#a64aff', 250, 'mask'], ['ДИДЖЕЙ', 'DJ HAM', 'rainbow', '#ffffff', 30, 'phones'],
  ['ПИРАТ', 'PIRATE', 'none', '#ffffff', 15, 'pirate'], ['КОРОЛЬ ЛЕСА', 'FOREST KING', 'glow', '#5ae05a', 110, 'crown'], ['ДРАКОН', 'DRAGON', 'fire', '#ff3a3a', 350, 'horns'], ['КОСМОНАВТ', 'ASTRONAUT', 'spark', '#9ad8ff', 210, 'visor'],
  ['ЛАВОВЫЙ', 'LAVA', 'fire', '#ffb02a', 20, 'none'], ['ПРИЗРАК', 'GHOST', 'glow', '#e8ecff', 230, 'none'], ['СОЛНЕЧНЫЙ', 'SUNNY', 'rainbow', '#ffd23a', 45, 'shades'], ['РЫЦАРЬ', 'KNIGHT', 'glow', '#c8d0e0', 220, 'helm']];
const ACC = {   // аксессуары ботов по клеткам (x, y, w, h, цвет)
  horns: [[11, 3, 2, 4, '#e8e0d0'], [19, 3, 2, 4, '#e8e0d0'], [12, 2, 1, 1, '#e8e0d0'], [19, 2, 1, 1, '#e8e0d0']],
  crown: [[11, 4, 10, 3, '#ffd23a'], [11, 2, 2, 2, '#ffd23a'], [15, 1, 2, 3, '#ffd23a'], [19, 2, 2, 2, '#ffd23a'], [15, 5, 2, 1, '#ff3a5a']],
  visor: [[12, 11, 9, 3, '#3af0ff'], [12, 11, 9, 1, '#ffffff']],
  wizard: [[10, 6, 12, 2, '#5a2aa0'], [12, 2, 8, 4, '#5a2aa0'], [14, 0, 4, 2, '#5a2aa0'], [15, 3, 2, 1, '#ffe24a']],
  bow: [[18, 4, 3, 3, '#ff3a8a'], [22, 4, 3, 3, '#ff3a8a'], [21, 5, 1, 1, '#ffffff']],
  mask: [[11, 11, 11, 2, '#1a1a24']],
  phones: [[10, 7, 12, 1, '#1a1a24'], [9, 9, 2, 4, '#ff3a5a'], [21, 9, 2, 4, '#ff3a5a']],
  pirate: [[11, 5, 11, 2, '#1a1a24'], [17, 10, 3, 3, '#1a1a24'], [15, 5, 2, 1, '#ffffff']],
  shades: [[12, 11, 4, 2, '#1a1a24'], [17, 11, 4, 2, '#1a1a24'], [16, 11, 1, 1, '#1a1a24']],
  helm: [[10, 4, 12, 4, '#a8b0c0'], [10, 8, 2, 5, '#a8b0c0'], [20, 8, 2, 5, '#a8b0c0'], [11, 4, 10, 1, '#e8eef8']],
  none: [],
};
const hueShift = (hex, deg) => { if (!hex) return hex; let r = parseInt(hex.slice(1, 3), 16) / 255, g = parseInt(hex.slice(3, 5), 16) / 255, b = parseInt(hex.slice(5, 7), 16) / 255; const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2; let h = 0, s = 0;
  if (mx !== mn) { const d = mx - mn; s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn); h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4; h /= 6; }
  h = (h + deg / 360) % 1; const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q, f = t => { t = (t + 1) % 1; return t < 1 / 6 ? p + (q - p) * 6 * t : t < 0.5 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p; };
  return '#' + [f(h + 1 / 3), f(h), f(h - 1 / 3)].map(v => Math.round(v * 255).toString(16).padStart(2, '0')).join(''); };
function botSkins() {
  const out = [], base = tplFrames(), now = Date.now();
  BOT_IDEAS.forEach((idea, i) => {
    const author = BOTS[i % BOTS.length], keep = new Set(['#4a2410', '#ffffff', '#1a1010']);
    const frames = base.map(fr => { const g = fr.map(c => c && !keep.has(c) ? hueShift(c, idea[4]) : c); for (const [x, y, w, h, col] of ACC[idea[5]]) for (let yy = y; yy < y + h; yy++) for (let xx = x - 2; xx < x - 2 + w; xx++) if (xx >= 0 && xx < G && yy >= 0 && yy < G) g[yy * G + xx] = col; return g; });
    const R = round(now), born = R.start + Math.floor(hash(i * 7 + 3 + R.n * 101) * (i < 5 ? 0.2 : SUBMIT_D) * DAY);   // в каждом конкурсе боты выкладывают скины в разные дни (пятеро — в первые часы)
    if (born > now) return;
    out.push({ id: 'b' + R.n + '_' + i, bot: true, u: 'bot_' + author, n: author, t: T(idea[0], idea[1]), d: T('СКИН ОТ ' + author + '. ЛАЙКНИ, ЕСЛИ НРАВИТСЯ!', 'A SKIN BY ' + author + '. LIKE IT IF YOU DO!'), k: i % 4 === 3 ? 'a' : 's', an: true, fps: 6, frames, au: { t: idea[2], c: idea[3] }, bg: '#3a2a6a', ts: born });
  });
  return out;
}
const botLikes = s => { const age = Math.max(0, (Date.now() - s.ts) / 36e5), h = hash(strHash(s.id) * 13 + 5); return Math.floor(Math.min(40 + h * 260, age * (0.25 + h * 1.6))); };   // NPC тоже лайкают — и чужие, и твои скины

// ---------- данные ----------
const S = { list: [], likes: {}, my: new Set(ls.get('myLikes', [])), view: 'new', q: '', online: false, plk: {}, myPl: new Set(ls.get('myPl', [])) };
function decode(id, v) {
  try { const j = typeof v.j === 'string' ? JSON.parse(v.j) : v; const pal = (j.p || []).slice(0, 64).filter(c => /^#[0-9a-f]{6}$/i.test(c));
    const frames = (j.fr || []).slice(0, MAX_F).map(s => [...String(s).slice(0, G * G)].map(ch => ch === '.' ? null : (pal[parseInt(ch, 36)] || null)));
    if (!frames.length) return null; while (frames[0].length < G * G) frames[0].push(null);
    return { id, u: String(v.u || j.u || ''), n: String(j.n || 'PLAYER').slice(0, 20), t: String(j.t || '').slice(0, 30), d: String(j.d || '').slice(0, 160), k: j.k === 'a' ? 'a' : 's', an: !!j.an && frames.length > 1, fps: Math.max(2, Math.min(12, +j.fps || 6)), frames, au: { t: String((j.au || {}).t || 'none'), c: /^#[0-9a-f]{6}$/i.test((j.au || {}).c) ? j.au.c : '#ffd23a' }, bg: /^#[0-9a-f]{6}$/i.test(j.bg) ? j.bg : '#3a2a6a', ts: +v.ts || Date.now() };
  } catch (e) { return null; }
}
function encode(sk) {
  const pal = []; const fr = sk.frames.map(f => f.map(c => { if (!c) return '.'; let i = pal.indexOf(c); if (i < 0) { pal.push(c); i = pal.length - 1; } return i.toString(36); }).join(''));
  return JSON.stringify({ n: ME.nick, t: sk.t, d: sk.d, k: sk.k, an: sk.an, fps: sk.fps, p: pal, fr, au: sk.au, bg: sk.bg });
}
async function load() {
  const local = ls.get('local', []).map(v => decode(v.id, v)).filter(Boolean);
  let remote = [];
  try { await auth(); const d = await db('GET', 'sm/s', undefined, '&orderBy=%22ts%22&limitToLast=300'); remote = Object.entries(d || {}).map(([id, v]) => decode(id, v)).filter(Boolean); const c = await db('GET', 'sm/c'); S.likes = c || {}; S.online = true;
    for (const s of remote) if (s.u === ME.uid) ls.set('local', ls.get('local', []).filter(v => v.id !== s.id));
  } catch (e) { S.online = false; }
  const ids = new Set(remote.map(s => s.id));
  S.list = [...remote, ...local.filter(s => !ids.has(s.id)), ...botSkins()];
}
const likesOf = s => (S.likes[s.id] | 0) + botLikes(s) + (S.my.has(s.id) && !S.online ? 1 : 0);
async function toggleLike(s, btn) {
  const on = !S.my.has(s.id); if (on) S.my.add(s.id); else S.my.delete(s.id); ls.set('myLikes', [...S.my]);
  if (btn) { btn.classList.toggle('on', on); btn.querySelector('b').textContent = likesOf(s); btn.animate([{ transform: 'scale(1.4)' }, { transform: 'scale(1)' }], 300); if (on) heartBurst(btn); }
  if (s.bot || !S.online) return;
  try { await db('PUT', 'sm/l/' + s.id + '/' + ME.uid, on ? true : null); const cur = (await db('GET', 'sm/c/' + s.id)) | 0; await db('PUT', 'sm/c/' + s.id, Math.max(0, cur + (on ? 1 : -1))); S.likes[s.id] = Math.max(0, cur + (on ? 1 : -1)); if (btn) btn.querySelector('b').textContent = likesOf(s); } catch (e) {}
}
async function publish(sk) {
  const j = encode(sk), id = (ME.uid ? ME.uid.slice(0, 6) : 'loc') + Date.now().toString(36);
  try { if (j.length > 14000) throw new Error('big'); await db('PUT', 'sm/s/' + id, { u: ME.uid, j, ts: { '.sv': 'timestamp' } }); try { await db('PUT', 'sm/u/' + ME.uid, ME.nick.slice(0, 20)); } catch (e) {} return { id, online: true }; }
  catch (e) { const L = ls.get('local', []); L.unshift({ id, u: ME.uid || 'me', j, ts: Date.now() }); ls.set('local', L.slice(0, 40)); return { id, online: false }; }
}

// ---------- предпросмотр: кадры + аура, анимация одним циклом ----------
const PREV = new Set();
function drawSkin(c, s, t, opt = {}) {
  const g = c.getContext('2d'), W = c.width, H = c.height, f = s.an ? Math.floor(t * s.fps) % s.frames.length : 0, cell = Math.floor(Math.min(W, H) * (opt.fill || 0.78) / G), ox = Math.floor((W - cell * G) / 2), oy = Math.floor((H - cell * G) / 2);
  g.clearRect(0, 0, W, H);
  if (s.k === 'a') { g.fillStyle = s.bg; g.beginPath(); g.roundRect(ox - cell, oy - cell, cell * (G + 2), cell * (G + 2), cell * 4); g.fill(); }
  aura(g, s.au, W / 2, H / 2, cell * G * 0.5, t, false);
  const fr = s.frames[f] || s.frames[0];
  for (let i = 0; i < G * G; i++) { const col = fr[i]; if (!col) continue; g.fillStyle = col; g.fillRect(ox + (i % G) * cell, oy + Math.floor(i / G) * cell, cell, cell); }
  aura(g, s.au, W / 2, H / 2, cell * G * 0.5, t, true);
}
function aura(g, au, cx, cy, R, t, front) {
  if (!au || au.t === 'none') return; const c = au.c;
  if (!front) {
    if (au.t === 'glow' || au.t === 'rainbow') { const gr = g.createRadialGradient(cx, cy, R * 0.2, cx, cy, R * 1.1); const col = au.t === 'rainbow' ? `hsl(${(t * 80) % 360},90%,60%)` : c; gr.addColorStop(0, col + (au.t === 'rainbow' ? '' : '')); gr.addColorStop(1, 'transparent'); g.globalAlpha = 0.45 + Math.sin(t * 4) * 0.12; g.fillStyle = gr; g.beginPath(); g.arc(cx, cy, R * 1.1, 0, 7); g.fill(); g.globalAlpha = 1; }
    if (au.t === 'fire') for (let i = 0; i < 9; i++) { const q = (t * 1.3 + i / 9) % 1, x = cx + Math.sin(i * 2.3 + t * 3) * R * 0.6; g.globalAlpha = (1 - q) * 0.8; g.fillStyle = q < 0.4 ? '#ffe24a' : q < 0.7 ? c : '#a01a0a'; const s = R * 0.12 * (1 - q * 0.6); g.fillRect(x - s / 2, cy + R * 0.7 - q * R * 1.8, s, s); }
    g.globalAlpha = 1; return;
  }
  const P = R * 0.07;
  if (au.t === 'spark') for (let i = 0; i < 6; i++) { const a = t * 1.6 + i * 1.05, x = cx + Math.cos(a) * R * 0.95, y = cy + Math.sin(a) * R * 0.8, tw = Math.max(0, Math.sin(t * 6 + i * 2)); g.globalAlpha = 0.4 + tw * 0.6; g.fillStyle = i % 2 ? c : '#ffffff'; g.fillRect(x - P / 2, y - P * 1.5, P, P * 3); g.fillRect(x - P * 1.5, y - P / 2, P * 3, P); }
  if (au.t === 'heart') for (let i = 0; i < 4; i++) { const q = (t * 0.5 + i / 4) % 1, x = cx + Math.sin(i * 2.1 + t) * R * 0.8, y = cy + R * 0.6 - q * R * 1.7; g.globalAlpha = 1 - q; heart(g, x, y, P * 1.4, c); }
  if (au.t === 'snow') for (let i = 0; i < 8; i++) { const q = (t * 0.35 + i / 8) % 1, x = cx + (hash(i * 9) - 0.5) * R * 2 + Math.sin(t * 2 + i) * P * 2, y = cy - R + q * R * 2; g.globalAlpha = 0.9; g.fillStyle = '#ffffff'; g.fillRect(x, y, P, P); }
  if (au.t === 'rainbow') for (let i = 0; i < 6; i++) { const a = t * 2 + i * 1.05; g.globalAlpha = 0.85; g.fillStyle = `hsl(${i * 60 + t * 120},95%,65%)`; g.fillRect(cx + Math.cos(a) * R * 0.95 - P / 2, cy + Math.sin(a) * R * 0.75 - P / 2, P * 1.4, P * 1.4); }
  g.globalAlpha = 1;
}
function heart(g, x, y, s, c) { g.fillStyle = c; g.fillRect(x - s, y - s * 0.5, s * 0.9, s); g.fillRect(x + s * 0.1, y - s * 0.5, s * 0.9, s); g.fillRect(x - s * 0.6, y + s * 0.4, s * 1.2, s * 0.6); g.fillRect(x - s * 0.2, y + s * 0.9, s * 0.4, s * 0.4); }
let t0 = performance.now(), lastPrev = 0;
(function loop(n) { requestAnimationFrame(loop); if (n - lastPrev < 1000 / 30) return; lastPrev = n; const t = (n - t0) / 1000; for (const p of PREV) { if (!p.c.isConnected) { PREV.delete(p); continue; } if (p.vis === false) continue; drawSkin(p.c, p.s, t, p.opt); } })(0);
const io = new IntersectionObserver(es => es.forEach(e => { const p = [...PREV].find(q => q.c === e.target); if (p) p.vis = e.isIntersecting; }));
function preview(s, size, opt) { const c = el('canvas'); c.width = c.height = size * 2; c.style.width = c.style.height = size + 'px'; const p = { c, s, opt, vis: true }; PREV.add(p); io.observe(c); drawSkin(c, s, 0, opt); return c; }
function heartBurst(at) { const r = at.getBoundingClientRect(); for (let i = 0; i < 8; i++) { const h = el('i', 'hb', '❤'); h.style.left = r.left + r.width / 2 + 'px'; h.style.top = r.top + 'px'; h.style.setProperty('--dx', (Math.random() - 0.5) * 120 + 'px'); h.style.setProperty('--dy', -40 - Math.random() * 80 + 'px'); document.body.appendChild(h); setTimeout(() => h.remove(), 900); } }
function toast(txt) { const t = el('div', 'toast', txt); document.body.appendChild(t); setTimeout(() => t.classList.add('out'), 1800); setTimeout(() => t.remove(), 2300); }

// ---------- конкурс ----------
function round(now = Date.now()) {
  const d = (now - ROUND0) / DAY, n = Math.max(0, Math.floor(d / (SUBMIT_D + FINAL_D))), start = ROUND0 + n * (SUBMIT_D + FINAL_D) * DAY, sEnd = start + SUBMIT_D * DAY, fEnd = sEnd + FINAL_D * DAY;
  return { n, start, sEnd, fEnd, phase: now < start ? 'soon' : now < sEnd ? 'submit' : 'final' };
}
const inRound = (s, R) => s.ts >= R.start && s.ts < R.sEnd;
const top3 = R => S.list.filter(s => inRound(s, R)).sort((a, b) => likesOf(b) - likesOf(a)).slice(0, 3);
const left = ms => { ms = Math.max(0, ms); const d = Math.floor(ms / DAY), h = Math.floor(ms % DAY / 36e5), m = Math.floor(ms % 36e5 / 6e4), s = Math.floor(ms % 6e4 / 1000); return (d ? d + T(' ДН. ', 'D ') : '') + [h, m, s].map(v => String(v).padStart(2, '0')).join(':'); };

// ---------- экраны ----------
function card(s) {
  const c = el('div', 'card' + (s.k === 'a' ? ' av' : '')); c.appendChild(preview(s, 132, { fill: s.k === 'a' ? 0.7 : 0.82 }));
  const info = el('div', 'ci'); info.append(el('div', 'ct', s.t || T('БЕЗ НАЗВАНИЯ', 'UNTITLED')));
  const au = el('a', 'ca', '@' + s.n); au.onclick = e => { e.stopPropagation(); go('#u=' + encodeURIComponent(s.u)); }; info.appendChild(au);
  const row = el('div', 'cr'); const lk = el('button', 'lk' + (S.my.has(s.id) ? ' on' : '')); lk.append(el('span', '', '❤'), el('b', '', String(likesOf(s)))); lk.onclick = e => { e.stopPropagation(); toggleLike(s, lk); };
  const tag = el('span', 'tag', s.k === 'a' ? T('АВАТАРКА', 'AVATAR') : T('СКИН', 'SKIN')); if (s.an) tag.textContent += ' · ' + T('АНИМ.', 'ANIM');
  row.append(lk, tag); info.appendChild(row); c.appendChild(info);
  c.onclick = () => go('#s=' + s.id); return c;
}
function grid(list) { const g = el('div', 'grid'); if (!list.length) g.appendChild(el('div', 'empty', T('ТУТ ПОКА ПУСТО — НАЖМИ «+» И СДЕЛАЙ ПЕРВЫЙ!', 'NOTHING HERE YET — TAP «+» AND MAKE THE FIRST!'))); list.forEach(s => g.appendChild(card(s))); return g; }
function viewFeed() {
  const m = $('#main'); m.innerHTML = '';
  const R = round(), hero = el('div', 'hero'); hero.innerHTML = `<div class="ht">${T('КОНКУРС СКИНОВ', 'SKIN CONTEST')} #${R.n + 1}</div><div class="hs">${R.phase === 'submit' ? T('ВЫКЛАДЫВАЙ СКИНЫ — ТОП-3 ПО ЛАЙКАМ ПРОЙДУТ В ФИНАЛ. ДО ФИНАЛА: ', 'POST SKINS — TOP 3 BY LIKES GO TO THE FINAL. FINAL IN: ') + left(R.sEnd - Date.now()) : T('ФИНАЛ! ВЫБЕРИ ЛУЧШИЙ ИЗ ТРЁХ. ОСТАЛОСЬ: ', 'FINAL! PICK THE BEST OF THREE. LEFT: ') + left(R.fEnd - Date.now())}</div><div class="hp">${T('ПОБЕДИТЕЛЬ ПОПАДЁТ В ИГРУ WALL PLAY!', 'THE WINNER GETS INTO WALL PLAY!')}</div>`;
  hero.onclick = () => go('#contest'); m.appendChild(hero);
  const tabs = el('div', 'tabs'); [['new', T('НОВЫЕ', 'NEW')], ['top', T('ПОПУЛЯРНЫЕ', 'TOP')], ['s', T('СКИНЫ', 'SKINS')], ['a', T('АВАТАРКИ', 'AVATARS')], ['mine', T('МОИ', 'MINE')]].forEach(([k, n]) => { const b = el('button', 'tab' + (S.view === k ? ' on' : ''), n); b.onclick = () => { S.view = k; viewFeed(); }; tabs.appendChild(b); }); m.appendChild(tabs);
  let L = S.list.slice(); const q = S.q.trim().toLowerCase();
  if (q) L = L.filter(s => (s.t + ' ' + s.d + ' ' + s.n).toLowerCase().includes(q));
  if (S.view === 's' || S.view === 'a') L = L.filter(s => s.k === S.view);
  if (S.view === 'mine') L = L.filter(s => s.u === ME.uid || (!s.bot && s.u === 'me'));
  L.sort(S.view === 'top' ? (a, b) => likesOf(b) - likesOf(a) : (a, b) => b.ts - a.ts);
  if (q) m.appendChild(el('div', 'sub', T('НАЙДЕНО: ', 'FOUND: ') + L.length));
  m.appendChild(grid(L));
  if (!S.online) m.appendChild(el('div', 'note', T('НЕТ СВЯЗИ С БАЗОЙ — ТВОИ СКИНЫ СОХРАНЯЮТСЯ НА ЭТОМ УСТРОЙСТВЕ И ВЫЙДУТ В ОБЩУЮ ЛЕНТУ, КОГДА СВЯЗЬ ПОЯВИТСЯ.', 'NO DATABASE CONNECTION — YOUR SKINS ARE SAVED ON THIS DEVICE.')));
}
function viewSkin(id) {
  const s = S.list.find(q => q.id === id); const m = $('#main'); m.innerHTML = '';
  if (!s) { m.appendChild(el('div', 'empty', T('СКИН НЕ НАЙДЕН', 'SKIN NOT FOUND'))); return; }
  const box = el('div', 'detail'); box.appendChild(preview(s, Math.min(300, innerWidth - 60), { fill: 0.8 }));
  box.append(el('div', 'dt', s.t || T('БЕЗ НАЗВАНИЯ', 'UNTITLED')), el('div', 'dd', s.d || ''));
  const au = el('a', 'ca big', '@' + s.n); au.onclick = () => go('#u=' + encodeURIComponent(s.u)); box.appendChild(au);
  const row = el('div', 'drow'); const lk = el('button', 'lk big' + (S.my.has(s.id) ? ' on' : '')); lk.append(el('span', '', '❤'), el('b', '', String(likesOf(s)))); lk.onclick = () => toggleLike(s, lk);
  const sh = el('button', 'btn blue', T('ПОДЕЛИТЬСЯ', 'SHARE')); sh.onclick = () => share(s);
  row.append(lk, sh);
  if (s.u === ME.uid && !s.bot) { const del = el('button', 'btn red', T('УДАЛИТЬ', 'DELETE')); del.onclick = async () => { if (!confirm(T('УДАЛИТЬ ЭТОТ СКИН?', 'DELETE THIS SKIN?'))) return; try { await db('DELETE', 'sm/s/' + s.id); } catch (e) {} ls.set('local', ls.get('local', []).filter(v => v.id !== s.id)); S.list = S.list.filter(q => q.id !== s.id); go('#'); }; row.appendChild(del); }
  box.appendChild(row);
  const info = el('div', 'meta', (s.k === 'a' ? T('АВАТАРКА', 'AVATAR') : T('СКИН', 'SKIN')) + ' · ' + (s.an ? T('АНИМАЦИЯ ', 'ANIMATION ') + s.frames.length + T(' КАДРА', ' FRAMES') : T('БЕЗ АНИМАЦИИ', 'STATIC')) + ' · ' + T('АУРА: ', 'AURA: ') + auraName(s.au.t) + ' · ' + new Date(s.ts).toLocaleDateString());
  box.appendChild(info); m.appendChild(box);
}
async function share(s) {
  const url = location.origin + location.pathname + '#s=' + s.id, txt = T('Смотри мой скин «', 'Check out my skin «') + (s.t || 'Wall Play') + T('» в Wall Play Skin Maker!', '» in Wall Play Skin Maker!');
  try { if (navigator.share) { await navigator.share({ title: 'Wall Play Skin Maker', text: txt, url }); return; } } catch (e) { if (e && e.name === 'AbortError') return; }
  try { await navigator.clipboard.writeText(txt + ' ' + url); toast(T('ССЫЛКА СКОПИРОВАНА — ОТПРАВЬ ДРУГУ!', 'LINK COPIED — SEND IT TO A FRIEND!')); } catch (e) { prompt(T('СКОПИРУЙ ССЫЛКУ:', 'COPY THE LINK:'), url); }
}
async function viewUser(uid) {
  const m = $('#main'); m.innerHTML = ''; const mine = S.list.filter(s => s.u === uid); const nick = (mine[0] && mine[0].n) || (uid === ME.uid ? ME.nick : uid.replace(/^bot_/, ''));
  const head = el('div', 'phead'); const avs = mine.find(s => s.k === 'a') || mine[0];
  const ava = avs ? preview(avs, 96, { fill: 0.75 }) : el('div', 'noav', '?'); head.appendChild(ava);
  const info = el('div', 'pi'); info.append(el('div', 'pn', '@' + nick), el('div', 'ps', mine.length + T(' РАБОТ · ', ' WORKS · ') + mine.reduce((a, s) => a + likesOf(s), 0) + T(' ❤ НА РАБОТАХ', ' ❤ ON WORKS')));
  let plk = 0; if (uid.startsWith('bot_')) plk = Math.floor(30 + hash(strHash(uid)) * 400); else { try { const d = await db('GET', 'sm/pl/' + uid); plk = Object.keys(d || {}).length; } catch (e) {} plk += Math.floor(hash(strHash(uid)) * 6); }
  const lk = el('button', 'lk big' + (S.myPl.has(uid) ? ' on' : '')); lk.append(el('span', '', '❤'), el('b', '', String(plk + (S.myPl.has(uid) && !S.online ? 1 : 0))));
  lk.title = T('ЛАЙК ПРОФИЛЮ — ЗА ИДЕИ СКИНОВ И АВАТАРОК', 'LIKE THIS PROFILE');
  lk.onclick = async () => { const on = !S.myPl.has(uid); if (on) S.myPl.add(uid); else S.myPl.delete(uid); ls.set('myPl', [...S.myPl]); lk.classList.toggle('on', on); const b = lk.querySelector('b'); b.textContent = (+b.textContent) + (on ? 1 : -1); if (on) heartBurst(lk); if (!uid.startsWith('bot_') && S.online) try { await db('PUT', 'sm/pl/' + uid + '/' + ME.uid, on ? true : null); } catch (e) {} };
  if (uid !== ME.uid) info.appendChild(lk); else info.appendChild(el('div', 'ps', T('ЭТО ТВОЙ ПРОФИЛЬ · ', 'THIS IS YOU · ') + plk + ' ❤'));
  head.appendChild(info); m.appendChild(head); m.appendChild(grid(mine.sort((a, b) => b.ts - a.ts)));
}
async function viewContest() {
  const m = $('#main'); m.innerHTML = ''; const R = round();
  const h = el('div', 'hero big'); h.innerHTML = `<div class="ht">${T('КОНКУРС', 'CONTEST')} #${R.n + 1}</div><div class="hs">${R.phase === 'submit' ? T('ЭТАП 1 ИЗ 2: ВЫКЛАДЫВАЙ СКИНЫ И СОБИРАЙ ЛАЙКИ. 10 ДНЕЙ.', 'STAGE 1 OF 2: POST SKINS AND COLLECT LIKES. 10 DAYS.') : T('ЭТАП 2 ИЗ 2: ФИНАЛ — ГОЛОСУЙ ЗА ЛУЧШИЙ ИЗ ТОП-3. 1 ДЕНЬ.', 'STAGE 2 OF 2: FINAL — VOTE FOR THE BEST OF THE TOP 3. 1 DAY.')}</div><div class="cd" id="cd"></div><div class="hp">${T('ПОБЕДИТЕЛЬ ПОПАДЁТ В ИГРУ WALL PLAY!', 'THE WINNER GETS INTO WALL PLAY!')}</div>`;
  m.appendChild(h); const cd = $('#cd'); const tick = () => { if (!cd.isConnected) return; cd.textContent = '⏳ ' + left((R.phase === 'submit' ? R.sEnd : R.fEnd) - Date.now()); setTimeout(tick, 1000); }; tick();
  const T3 = top3(R); m.appendChild(el('div', 'sub', R.phase === 'submit' ? T('СЕЙЧАС В ТОП-3:', 'TOP 3 RIGHT NOW:') : T('ФИНАЛИСТЫ — ВЫБЕРИ ОДНОГО:', 'FINALISTS — PICK ONE:')));
  let votes = {}, myVote = ls.get('vote' + R.n, null);
  if (R.phase === 'final') { try { const d = await db('GET', 'sm/v/' + R.n); for (const v of Object.values(d || {})) votes[v] = (votes[v] | 0) + 1; if (d && d[ME.uid]) myVote = d[ME.uid]; } catch (e) {} }
  const pod = el('div', 'podium'); T3.forEach((s, i) => { const w = el('div', 'pod p' + i); w.append(el('div', 'pm', ['🥇', '🥈', '🥉'][i])); w.appendChild(card(s));
    if (R.phase === 'final') { const bv = votes[s.id] | 0, bb = Math.floor(hash(strHash(s.id) + R.n) * 30); const v = el('button', 'btn ' + (myVote === s.id ? 'gold' : 'green'), myVote === s.id ? T('ТВОЙ ГОЛОС ✓', 'YOUR VOTE ✓') : T('ГОЛОСОВАТЬ', 'VOTE')); v.disabled = !!myVote;
      v.onclick = async () => { myVote = s.id; ls.set('vote' + R.n, s.id); try { await db('PUT', 'sm/v/' + R.n + '/' + ME.uid, s.id); } catch (e) {} toast(T('ГОЛОС ПРИНЯТ!', 'VOTE COUNTED!')); viewContest(); }; w.append(v, el('div', 'vc', (bv + bb) + T(' ГОЛОСОВ', ' VOTES'))); }
    pod.appendChild(w); });
  if (!T3.length) pod.appendChild(el('div', 'empty', T('ПОКА НИКТО НЕ ВЫЛОЖИЛ СКИН В ЭТОМ КОНКУРСЕ — БУДЬ ПЕРВЫМ!', 'NO ENTRIES YET — BE THE FIRST!')));
  m.appendChild(pod);
  if (R.n > 0) { const P = { n: R.n - 1, start: R.start - (SUBMIT_D + FINAL_D) * DAY, sEnd: R.start - FINAL_D * DAY }; const w = top3(P)[0]; if (w) { m.appendChild(el('div', 'sub', T('ПОБЕДИТЕЛЬ ПРОШЛОГО КОНКУРСА:', 'LAST CONTEST WINNER:'))); m.appendChild(grid([w])); } }
  m.appendChild(el('div', 'note', T('КАК ЭТО РАБОТАЕТ: 10 ДНЕЙ ВСЕ ВЫКЛАДЫВАЮТ СКИНЫ И СТАВЯТ ЛАЙКИ. ПОТОМ ТРИ СКИНА С БОЛЬШИМ ЧИСЛОМ ЛАЙКОВ ВЫХОДЯТ В ФИНАЛ, И 1 ДЕНЬ ВСЕ ВЫБИРАЮТ ЛУЧШИЙ. ПОБЕДИТЕЛЬ ПОЯВИТСЯ В ИГРЕ.', 'HOW IT WORKS: FOR 10 DAYS EVERYONE POSTS SKINS AND LIKES. THEN THE TOP 3 GO TO THE FINAL, AND FOR 1 DAY EVERYONE PICKS THE BEST. THE WINNER APPEARS IN THE GAME.')));
}
const AURAS = [['none', 'НЕТ', 'NONE'], ['glow', 'СИЯНИЕ', 'GLOW'], ['fire', 'ОГОНЬ', 'FIRE'], ['spark', 'ИСКРЫ', 'SPARKS'], ['heart', 'СЕРДЕЧКИ', 'HEARTS'], ['snow', 'СНЕГ', 'SNOW'], ['rainbow', 'РАДУГА', 'RAINBOW']];
const auraName = t => { const a = AURAS.find(q => q[0] === t) || AURAS[0]; return T(a[1], a[2]); };

// ---------- редактор ----------
const PAL = ['#1a1010', '#4a2410', '#ffffff', '#c8c8d0', '#6a6a7a', '#2a2a34', '#ff3a3a', '#c01a1a', '#ff8a1e', '#ffd23a', '#fff6a0', '#3ae05a', '#1a9a3a', '#3ab0ff', '#1a5ac0', '#a64aff', '#5a1aa0', '#ff7ad8', '#ffb0c8', '#f0a040', '#c06a20', '#ffe6b0', '#8a5a2a', '#3af0ff'];
function viewEditor(kind) {
  const m = $('#main'); m.innerHTML = '';
  const st = { k: kind, frames: kind === 's' ? tplFrames() : [Array(G * G).fill(null)], f: 0, tool: 'pen', col: '#ff3a3a', mirror: false, onion: true, an: kind === 's', fps: 6, au: { t: 'none', c: '#ffd23a' }, bg: '#3a2a6a', undo: [], redo: [], playing: false };
  if (kind === 'a') { const tf = tplFrames()[0]; st.frames = [tf.slice()]; }
  const wrap = el('div', 'ed'); m.appendChild(wrap);
  wrap.appendChild(el('div', 'edt', kind === 's' ? T('НОВЫЙ СКИН', 'NEW SKIN') : T('НОВАЯ АВАТАРКА', 'NEW AVATAR')));
  // холст
  const cw = Math.min(480, innerWidth - 24), cell = Math.floor(cw / G), cv = el('canvas', 'grid32'); cv.width = cv.height = cell * G; wrap.appendChild(cv);
  const g = cv.getContext('2d');
  const fr = () => st.frames[st.f];
  const paint = () => {
    g.clearRect(0, 0, cv.width, cv.height);
    for (let y = 0; y < G; y++) for (let x = 0; x < G; x++) { g.fillStyle = (x + y) % 2 ? '#2e2450' : '#352a5c'; if (kind === 'a') g.fillStyle = st.bg; g.fillRect(x * cell, y * cell, cell, cell); }
    if (st.onion && st.f > 0) { g.globalAlpha = 0.25; st.frames[st.f - 1].forEach((c, i) => { if (c) { g.fillStyle = c; g.fillRect((i % G) * cell, Math.floor(i / G) * cell, cell, cell); } }); g.globalAlpha = 1; }
    fr().forEach((c, i) => { if (c) { g.fillStyle = c; g.fillRect((i % G) * cell, Math.floor(i / G) * cell, cell, cell); } });
    g.strokeStyle = 'rgba(255,255,255,0.06)'; g.lineWidth = 1; for (let i = 0; i <= G; i++) { g.beginPath(); g.moveTo(i * cell + 0.5, 0); g.lineTo(i * cell + 0.5, G * cell); g.stroke(); g.beginPath(); g.moveTo(0, i * cell + 0.5); g.lineTo(G * cell, i * cell + 0.5); g.stroke(); }
    if (st.mirror) { g.strokeStyle = '#ffd23a88'; g.beginPath(); g.moveTo(G / 2 * cell, 0); g.lineTo(G / 2 * cell, G * cell); g.stroke(); }
    strip(); live.s = skinObj();
  };
  const snap = () => { st.undo.push(JSON.stringify(st.frames)); if (st.undo.length > 60) st.undo.shift(); st.redo = []; };
  const setPx = (x, y, c) => { if (x < 0 || y < 0 || x >= G || y >= G) return; fr()[y * G + x] = c; if (st.mirror) fr()[y * G + (G - 1 - x)] = c; };
  const fill = (x, y, c) => { const F = fr(), t = F[y * G + x]; if (t === c) return; const q = [[x, y]]; while (q.length) { const [a, b] = q.pop(); if (a < 0 || b < 0 || a >= G || b >= G || F[b * G + a] !== t) continue; F[b * G + a] = c; q.push([a + 1, b], [a - 1, b], [a, b + 1], [a, b - 1]); } };
  let down = false;
  const at = e => { const r = cv.getBoundingClientRect(); return [Math.floor((e.clientX - r.left) / r.width * G), Math.floor((e.clientY - r.top) / r.height * G)]; };
  const act = (e, first) => { const [x, y] = at(e); if (st.tool === 'pick') { const c = fr()[y * G + x]; if (c) { st.col = c; st.tool = 'pen'; tools(); colors(); } return; } if (st.tool === 'fill') { if (first) { snap(); fill(x, y, st.col); paint(); } return; } setPx(x, y, st.tool === 'erase' ? null : st.col); paint(); };
  cv.addEventListener('pointerdown', e => { e.preventDefault(); cv.setPointerCapture(e.pointerId); down = true; if (st.tool !== 'fill' && st.tool !== 'pick') snap(); act(e, true); });
  cv.addEventListener('pointermove', e => { if (down && st.tool !== 'fill' && st.tool !== 'pick') act(e); });
  cv.addEventListener('pointerup', () => { down = false; });
  // инструменты
  const tb = el('div', 'tools'); wrap.appendChild(tb);
  const TOOLS = [['pen', '✏️', T('КИСТЬ', 'PEN')], ['erase', '🧽', T('ЛАСТИК', 'ERASER')], ['fill', '🪣', T('ЗАЛИВКА', 'FILL')], ['pick', '💧', T('ПИПЕТКА', 'PICKER')]];
  function tools() { tb.innerHTML = ''; TOOLS.forEach(([k, ic, n]) => { const b = el('button', 'tl' + (st.tool === k ? ' on' : '')); b.append(el('span', '', ic), el('i', '', n)); b.onclick = () => { st.tool = k; tools(); }; tb.appendChild(b); });
    const mi = el('button', 'tl' + (st.mirror ? ' on' : '')); mi.append(el('span', '', '🪞'), el('i', '', T('ЗЕРКАЛО', 'MIRROR'))); mi.onclick = () => { st.mirror = !st.mirror; tools(); paint(); }; tb.appendChild(mi);
    const un = el('button', 'tl'); un.append(el('span', '', '↩️'), el('i', '', T('НАЗАД', 'UNDO'))); un.onclick = () => { if (!st.undo.length) return; st.redo.push(JSON.stringify(st.frames)); st.frames = JSON.parse(st.undo.pop()); st.f = Math.min(st.f, st.frames.length - 1); paint(); }; tb.appendChild(un);
    const re = el('button', 'tl'); re.append(el('span', '', '↪️'), el('i', '', T('ВПЕРЁД', 'REDO'))); re.onclick = () => { if (!st.redo.length) return; st.undo.push(JSON.stringify(st.frames)); st.frames = JSON.parse(st.redo.pop()); paint(); }; tb.appendChild(re);
    const tp = el('button', 'tl'); tp.append(el('span', '', '🐹'), el('i', '', T('ШАБЛОН', 'TEMPLATE'))); tp.onclick = () => { snap(); const T0 = tplFrames(); st.frames = st.an ? T0.slice(0, Math.max(1, st.frames.length)).map(f => f.slice()) : [T0[0].slice()]; st.f = 0; paint(); }; tb.appendChild(tp);
    const cl = el('button', 'tl'); cl.append(el('span', '', '🗑️'), el('i', '', T('ОЧИСТИТЬ', 'CLEAR'))); cl.onclick = () => { snap(); st.frames[st.f] = Array(G * G).fill(null); paint(); }; tb.appendChild(cl); }
  tools();
  // цвета
  const cb = el('div', 'colors'); wrap.appendChild(cb);
  function colors() { cb.innerHTML = ''; PAL.forEach(c => { const b = el('button', 'sw' + (st.col === c ? ' on' : '')); b.style.background = c; b.onclick = () => { st.col = c; if (st.tool === 'erase' || st.tool === 'pick') st.tool = 'pen'; tools(); colors(); }; cb.appendChild(b); });
    const cu = el('input'); cu.type = 'color'; cu.value = st.col; cu.className = 'cpick'; cu.oninput = () => { st.col = cu.value; colors(); }; cb.appendChild(cu); }
  colors();
  // кадры
  const fs = el('div', 'frames'); wrap.appendChild(fs);
  function strip() {
    fs.innerHTML = '';
    const an = el('label', 'chk'); const ac = el('input'); ac.type = 'checkbox'; ac.checked = st.an; ac.onchange = () => { st.an = ac.checked; if (!st.an) { st.frames = [st.frames[0]]; st.f = 0; } paint(); }; an.append(ac, el('span', '', T('АНИМАЦИЯ', 'ANIMATION'))); fs.appendChild(an);
    if (st.an) {
      st.frames.forEach((F, i) => { const c = el('canvas', 'fth' + (i === st.f ? ' on' : '')); c.width = c.height = G; const q = c.getContext('2d'); F.forEach((col, j) => { if (col) { q.fillStyle = col; q.fillRect(j % G, Math.floor(j / G), 1, 1); } }); c.onclick = () => { st.f = i; paint(); }; fs.appendChild(c); });
      if (st.frames.length < MAX_F) { const add = el('button', 'btn small', T('+ КАДР', '+ FRAME')); add.onclick = () => { snap(); st.frames.splice(st.f + 1, 0, fr().slice()); st.f++; paint(); }; fs.appendChild(add); }
      if (st.frames.length > 1) { const del = el('button', 'btn small red', '✕'); del.onclick = () => { snap(); st.frames.splice(st.f, 1); st.f = Math.max(0, st.f - 1); paint(); }; fs.appendChild(del); }
      const on = el('label', 'chk'); const oc = el('input'); oc.type = 'checkbox'; oc.checked = st.onion; oc.onchange = () => { st.onion = oc.checked; paint(); }; on.append(oc, el('span', '', T('КАЛЬКА', 'ONION'))); fs.appendChild(on);
      const sp = el('label', 'chk'); const si = el('input'); si.type = 'range'; si.min = 2; si.max = 12; si.value = st.fps; si.oninput = () => { st.fps = +si.value; live.s = skinObj(); sp.lastChild.textContent = st.fps + T(' К/С', ' FPS'); }; sp.append(si, el('span', '', st.fps + T(' К/С', ' FPS'))); fs.appendChild(sp);
    }
  }
  // аура и фон
  const ab = el('div', 'aura'); wrap.appendChild(ab);
  ab.appendChild(el('div', 'lbl', T('АУРА', 'AURA')));
  const ar = el('div', 'arow'); AURAS.forEach(([k, ru, en]) => { const b = el('button', 'chip' + (st.au.t === k ? ' on' : ''), T(ru, en)); b.onclick = () => { st.au.t = k; [...ar.children].forEach(x => x.classList.remove('on')); b.classList.add('on'); live.s = skinObj(); }; ar.appendChild(b); });
  const ac2 = el('input'); ac2.type = 'color'; ac2.value = st.au.c; ac2.className = 'cpick'; ac2.oninput = () => { st.au.c = ac2.value; live.s = skinObj(); }; ar.appendChild(ac2); ab.appendChild(ar);
  if (kind === 'a') { ab.appendChild(el('div', 'lbl', T('ФОН АВАТАРКИ', 'AVATAR BACKGROUND'))); const bg = el('input'); bg.type = 'color'; bg.value = st.bg; bg.className = 'cpick'; bg.oninput = () => { st.bg = bg.value; paint(); }; ab.appendChild(bg); }
  // живой предпросмотр
  const pv = el('div', 'pv'); pv.appendChild(el('div', 'lbl', T('ТАК БУДЕТ ВЫГЛЯДЕТЬ', 'PREVIEW'))); const skinObj = () => ({ id: 'edit', k: kind, an: st.an && st.frames.length > 1, fps: st.fps, frames: st.frames, au: { ...st.au }, bg: st.bg }); const pc = preview(skinObj(), 150, { fill: 0.78 }); const live = [...PREV].find(p => p.c === pc); pv.appendChild(pc); wrap.appendChild(pv);
  // название и публикация
  const form = el('div', 'form'); const nm = el('input', 'inp'); nm.placeholder = T('НАЗВАНИЕ (ДО 30)', 'TITLE (UP TO 30)'); nm.maxLength = 30; const ds = el('textarea', 'inp'); ds.placeholder = T('ОПИСАНИЕ (ДО 140)', 'DESCRIPTION (UP TO 140)'); ds.maxLength = 140;
  const pub = el('button', 'btn gold big', T('ОПУБЛИКОВАТЬ', 'PUBLISH'));
  pub.onclick = async () => {
    const title = nm.value.replace(/[<>]/g, '').trim(); if (title.length < 2) { toast(T('НАПИШИ НАЗВАНИЕ', 'ADD A TITLE')); nm.focus(); return; }
    if (!st.frames.some(F => F.some(Boolean))) { toast(T('НАРИСУЙ ХОТЬ ЧТО-НИБУДЬ', 'DRAW SOMETHING')); return; }
    pub.disabled = true; pub.textContent = T('ПУБЛИКУЮ…', 'PUBLISHING…');
    const sk = { ...skinObj(), t: title, d: ds.value.replace(/[<>]/g, '').trim() }, r = await publish(sk);
    S.list.unshift({ ...sk, id: r.id, u: ME.uid || 'me', n: ME.nick, ts: Date.now() });
    toast(r.online ? T('ГОТОВО! СКИН В ОБЩЕЙ ЛЕНТЕ', 'DONE! YOUR SKIN IS LIVE') : T('СОХРАНЕНО НА УСТРОЙСТВЕ', 'SAVED ON THIS DEVICE')); go('#s=' + r.id);
  };
  form.append(nm, ds, pub); wrap.appendChild(form);
  paint();
}
function chooser() {
  const ov = el('div', 'modal'); const box = el('div', 'mbox'); box.appendChild(el('div', 'edt', T('ЧТО СДЕЛАЕМ?', 'WHAT SHALL WE MAKE?')));
  const a = el('button', 'big-choice'); a.append(preview({ id: 'c1', k: 's', an: true, fps: 5, frames: tplFrames(), au: { t: 'spark', c: '#ffd23a' } }, 90), el('b', '', T('СКИН ГЕРОЯ', 'HERO SKIN')), el('i', '', T('С АНИМАЦИЕЙ И АУРОЙ', 'WITH ANIMATION AND AURA')));
  const b = el('button', 'big-choice'); b.append(preview({ id: 'c2', k: 'a', an: false, fps: 5, frames: [tplFrames()[0]], au: { t: 'glow', c: '#ff7ad8' }, bg: '#5a2aa0' }, 90, { fill: 0.7 }), el('b', '', T('АВАТАРКА', 'AVATAR')), el('i', '', T('С АНИМАЦИЕЙ ИЛИ БЕЗ', 'ANIMATED OR STATIC')));
  a.onclick = () => { ov.remove(); go('#new=s'); }; b.onclick = () => { ov.remove(); go('#new=a'); };
  const x = el('button', 'btn red small', '✕'); x.onclick = () => ov.remove();
  box.append(a, b, x); ov.appendChild(box); ov.onclick = e => { if (e.target === ov) ov.remove(); }; document.body.appendChild(ov);
}
// ---------- маршруты ----------
function go(h) { if (location.hash === h) route(); else location.hash = h; }
function route() {
  const h = location.hash.slice(1), [k, v] = h.split('='); window.scrollTo(0, 0);
  $('#fab').style.display = k === 'new' ? 'none' : '';
  if (k === 's' && v) viewSkin(v); else if (k === 'u' && v) viewUser(decodeURIComponent(v)); else if (k === 'contest') viewContest(); else if (k === 'new') viewEditor(v === 'a' ? 'a' : 's'); else viewFeed();
}
// ---------- старт: заставка Eldar Company, загрузка ----------
(async function start() {
  const bar = $('#ldbar i'), msg = $('#ldmsg'); let p = 0; const pr = setInterval(() => { p = Math.min(92, p + 3 + Math.random() * 5); bar.style.width = p + '%'; }, 90);
  msg.textContent = T('ЗАГРУЖАЕМ СКИНЫ…', 'LOADING SKINS…');
  await Promise.all([load(), new Promise(r => setTimeout(r, 2400))]);
  clearInterval(pr); bar.style.width = '100%'; msg.textContent = T('ГОТОВО!', 'READY!');
  await new Promise(r => setTimeout(r, 350)); $('#intro').classList.add('out'); setTimeout(() => $('#intro').remove(), 600);
  $('#me').textContent = '@' + ME.nick; $('#me').onclick = () => go('#u=' + encodeURIComponent(ME.uid || 'me'));
  $('#q').oninput = e => { S.q = e.target.value; if (location.hash && location.hash !== '#') location.hash = '#'; else viewFeed(); };
  $('#q').placeholder = T('ПОИСК СКИНОВ, АВТОРОВ…', 'SEARCH SKINS, AUTHORS…');
  $('#fab').onclick = chooser; $('#home').onclick = () => go('#'); $('#cbtn').onclick = () => go('#contest'); $('#cbtn').textContent = '🏆 ' + T('КОНКУРС', 'CONTEST');
  addEventListener('hashchange', route); route();
})();
