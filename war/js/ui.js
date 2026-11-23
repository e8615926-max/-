// Input (touch + keyboard/mouse), HUD, minimap, shop, menus
import * as THREE from '../lib/three.module.min.js';
import { G, ALLY, ENEMY, clamp } from './state.js';
import { MAP, BASES } from './world.js';
import { WEAPONS, SHOP, CHARACTERS } from './data.js';
import * as SFX from './audio.js';

const $ = id => document.getElementById(id);
const pressed = new Set();
export const input = {
  mx: 0, my: 0, lookX: 0, lookY: 0, lookXRaw: 0, lookYRaw: 0, fire: false, aim: false, sprint: false, mg: false, up: false, down: false,
  take(n) { if (pressed.has(n)) { pressed.delete(n); return true; } return false; },
  press(n) { pressed.add(n); },
  clear() { pressed.clear(); this.fire = this.mg = this.up = this.down = this.sprint = false; this.mx = this.my = 0; },
};
const keys = {};
let app, hooks = {};

// ======================= INPUT =======================
export function initInput(h) {
  hooks = h; app = $('app');
  const touchLayer = $('touch');
  const joy = { id: null, ox: 0, oy: 0 }, looks = new Map();
  const joyBase = $('joy'), joyKnob = $('joyKnob');
  const R = 56;
  const rect = () => app.getBoundingClientRect();
  touchLayer.addEventListener('pointerdown', e => {
    if (e.pointerType === 'mouse') return;
    e.preventDefault();
    const btn = e.target.closest('[data-act]');
    const r = rect(); const x = e.clientX - r.left, y = e.clientY - r.top;
    if (btn) {
      const act = btn.dataset.act; btn.classList.add('down');
      handleButton(act, true, btn);
      if (act === 'fire') looks.set(e.pointerId, { x: e.clientX, y: e.clientY, btn });
      else looks.set(e.pointerId, { x: e.clientX, y: e.clientY, btn, noLook: true });
      touchLayer.setPointerCapture(e.pointerId);
      return;
    }
    if (x < r.width * 0.48 && y > r.height * 0.42 && joy.id === null) {
      joy.id = e.pointerId; joy.ox = x; joy.oy = y;
      joyBase.style.left = (x - R) + 'px'; joyBase.style.top = (y - R) + 'px'; joyBase.classList.add('on');
      joyKnob.style.transform = 'translate(0px,0px)';
    } else looks.set(e.pointerId, { x: e.clientX, y: e.clientY });
    touchLayer.setPointerCapture(e.pointerId);
  }, { passive: false });
  touchLayer.addEventListener('pointermove', e => {
    if (e.pointerType === 'mouse') return;
    if (e.pointerId === joy.id) {
      const r = rect(); let dx = e.clientX - r.left - joy.ox, dy = e.clientY - r.top - joy.oy;
      const l = Math.hypot(dx, dy);
      input.sprint = dy < -R * 1.35;
      if (l > R) { dx = dx / l * R; dy = dy / l * R; }
      input.mx = dx / R; input.my = dy / R;
      joyKnob.style.transform = `translate(${dx}px,${dy}px)`;
      joyBase.classList.toggle('sprint', input.sprint);
      return;
    }
    const L = looks.get(e.pointerId);
    if (L && !L.noLook) {
      const k = 2.3 * (G.mode === 'drone' ? 1.1 : 1);
      const dx = (e.clientX - L.x) * k, dy = (e.clientY - L.y) * k;
      input.lookX += dx; input.lookY += dy; input.lookXRaw += dx; input.lookYRaw += dy;
      L.x = e.clientX; L.y = e.clientY;
    }
  }, { passive: false });
  const up = e => {
    if (e.pointerType === 'mouse') return;
    if (e.pointerId === joy.id) { joy.id = null; input.mx = input.my = 0; input.sprint = false; joyBase.classList.remove('on', 'sprint'); return; }
    const L = looks.get(e.pointerId);
    if (L && L.btn) { L.btn.classList.remove('down'); handleButton(L.btn.dataset.act, false, L.btn); }
    looks.delete(e.pointerId);
  };
  touchLayer.addEventListener('pointerup', up); touchLayer.addEventListener('pointercancel', up);
  // mouse buttons on the on-screen controls (desktop clicks)
  touchLayer.addEventListener('click', e => {
    const btn = e.target.closest('[data-act]'); if (!btn || e.pointerType === 'touch' || e.detail === 0) return;
    if (G.settings.mobile) return;
    const act = btn.dataset.act; if (['fire', 'mg', 'up', 'down', 'aim'].includes(act)) return;
    handleButton(act, true, btn); handleButton(act, false, btn);
  });

  // keyboard & mouse
  const canvas = $('c');
  canvas.addEventListener('click', () => { if (G.running && !G.paused && !G.settings.mobile && document.pointerLockElement !== canvas) canvas.requestPointerLock?.(); });
  document.addEventListener('pointerlockchange', () => { if (document.pointerLockElement !== canvas && G.running && !G.paused && !G.over && !G.settings.mobile && !shopOpen && !droneMenuOpen && !G.dead && !(G.player && G.player.state === 'down')) hooks.pause?.(true); });
  document.addEventListener('mousemove', e => { if (document.pointerLockElement === canvas) { input.lookX += e.movementX; input.lookY += e.movementY; input.lookXRaw += e.movementX; input.lookYRaw += e.movementY; } });
  canvas.addEventListener('mousedown', e => { if (document.pointerLockElement !== canvas) return; if (e.button === 0) { input.fire = true; input.press('fire'); } if (e.button === 2) input.aim = true; });
  document.addEventListener('mouseup', e => { if (e.button === 0) input.fire = false; if (e.button === 2) input.aim = false; });
  canvas.addEventListener('contextmenu', e => e.preventDefault());
  document.addEventListener('wheel', e => { if (document.pointerLockElement === canvas && G.mode === 'foot') input.press('switch'); }, { passive: true });
  addEventListener('keydown', e => {
    if (e.repeat) return;
    if (droneMenuOpen) { if (e.code === 'Digit1') closeDroneMenu('fpv'); else if (e.code === 'Digit2') closeDroneMenu('bomber'); else if (e.code === 'Escape' || e.code === 'KeyF') closeDroneMenu(null); return; }
    if (shopOpen) { if (e.code === 'Escape' || e.code === 'KeyB') closeShop(); return; }
    if (G.player && G.player.state === 'down') { if (e.code === 'Enter') $('giveUpBtn').click(); return; }
    if (G.dead) { if (e.code === 'Enter' || e.code === 'Space') $('respawnBtn').click(); return; }
    keys[e.code] = true;
    const m = G.mode;
    switch (e.code) {
      case 'Space': if (m === 'foot') input.press('jump'); if (m === 'drone') input.up = true; if (m === 'tank') input.mg = true; e.preventDefault(); break;
      case 'KeyC': case 'ControlLeft': if (m === 'foot') input.press('crouch'); if (m === 'drone') input.down = true; break;
      case 'KeyR': input.press(m === 'tank' ? 'repair' : 'reload'); break;
      case 'KeyG': input.press('grenade'); break;
      case 'KeyE': input.press('act'); break;
      case 'KeyF': if (m === 'foot') input.press('drone'); break;
      case 'KeyB': input.press('shop'); break;
      case 'KeyH': input.press('heal'); break;
      case 'KeyV': input.press(m === 'drone' ? 'droneMode' : 'view'); break;
      case 'Digit1': input.press('w0'); break; case 'Digit2': input.press('w1'); break; case 'Digit3': input.press('w2'); break; case 'Digit4': input.press('w3'); break;
      case 'KeyQ': input.press('switch'); break;
      case 'Escape': if (shopOpen) closeShop(); break;
      case 'KeyP': hooks.pause?.(!G.paused); break;
    }
    updateKeysMove();
  });
  addEventListener('keyup', e => {
    keys[e.code] = false;
    if (e.code === 'Space') { input.up = false; input.mg = false; }
    if (e.code === 'KeyC' || e.code === 'ControlLeft') input.down = false;
    updateKeysMove();
  });
  addEventListener('blur', () => { input.clear(); });
}
function updateKeysMove() {
  if (G.settings.mobile) return;
  input.mx = (keys.KeyD ? 1 : 0) - (keys.KeyA ? 1 : 0);
  input.my = (keys.KeyS ? 1 : 0) - (keys.KeyW ? 1 : 0);
  input.sprint = !!keys.ShiftLeft;
}

let aimToggle = false;
function handleButton(act, down) {
  if (down && !['fire', 'mg', 'up', 'down'].includes(act)) SFX.uiClick();
  switch (act) {
    case 'fire': input.fire = down; if (down) input.press('fire'); break;
    case 'aim': if (down) { aimToggle = !aimToggle; input.aim = aimToggle; $('bAim').classList.toggle('active', aimToggle); } break;
    case 'mg': input.mg = down; break;
    case 'up': input.up = down; break;
    case 'down': input.down = down; break;
    case 'pause': if (down) hooks.pause?.(true); break;
    default: if (down) input.press(act);
  }
}
export function resetAimToggle() { aimToggle = false; input.aim = false; $('bAim')?.classList.remove('active'); }

// ======================= HUD =======================
const feed = [], chats = [];
let msgT = 0, noticeT = 0, subT = 0, rewardQ = [];
let dmgFlash = 0, suppress = 0, hitT = 0;
const grenWarn = [];
const proj = new THREE.Vector3();
let mmT = 0, staticLevel = 0;

export const ui = {
  killfeed(a, at, v, vt, w, head) {
    const el = document.createElement('div'); el.className = 'kf';
    el.innerHTML = `<b class="t${at}">${esc(a)}</b> <span class="kw">${esc(w || '✕')}${head ? ' ☠' : ''}</span> <b class="t${vt}">${esc(v)}</b>`;
    $('killfeed').prepend(el); feed.push(el);
    while ($('killfeed').children.length > 5) $('killfeed').lastChild.remove();
    setTimeout(() => el.classList.add('fade'), 5000); setTimeout(() => el.remove(), 6000);
  },
  hit(kill, head, armor) {
    const h = $('hitmarker'); h.className = 'show' + (kill ? ' kill' : head ? ' head' : armor ? ' armor' : '');
    hitT = kill ? 0.35 : 0.15; SFX.hitMarker(kill);
  },
  reward(n, reason) {
    const el = document.createElement('div'); el.className = 'reward'; el.innerHTML = `+${n} <span>🪙</span><small>${esc(reason || '')}</small>`;
    $('rewards').appendChild(el); setTimeout(() => el.remove(), 1600);
  },
  notice(t) { const el = $('notice'); el.textContent = t; el.classList.add('show'); noticeT = 1.6; },
  message(t, d = 2.5) { const el = $('msg'); el.textContent = t; el.classList.add('show'); msgT = d; },
  subtitle(who, text, team) { const el = $('subtitle'); el.innerHTML = `<b class="t${team}">${esc(who)}:</b> «${esc(text)}»`; el.classList.add('show'); subT = 4.2; },
  chat(name, text, team) {
    const el = document.createElement('div'); el.className = 'chat'; el.innerHTML = `<b class="t${team}">${esc(name)}:</b> ${esc(text)}`;
    $('chats').appendChild(el); while ($('chats').children.length > 3) $('chats').firstChild.remove();
    setTimeout(() => el.remove(), 4000);
  },
  suppress(k) { suppress = Math.min(1, suppress + k); },
  damageFrom(pos) {
    const P = G.player; if (!P) return;
    const ang = Math.atan2(-(pos.x - G.camera.position.x), -(pos.z - G.camera.position.z));
    const rel = ang - P.camYaw;
    const el = document.createElement('div'); el.className = 'ddir'; el.style.transform = `rotate(${-rel}rad)`;
    $('dmgDirs').appendChild(el); setTimeout(() => el.remove(), 1400);
  },
  damaged(dmg, part, vehicle) {
    dmgFlash = Math.min(1, dmgFlash + dmg / 40);
    if (part) { const el = $('p-' + part); if (el) { el.classList.remove('flash'); void el.getBoundingClientRect(); el.classList.add('flash'); } }
    if (vehicle) $('vehHud').classList.add('hitflash'), setTimeout(() => $('vehHud').classList.remove('hitflash'), 200);
  },
  grenadeWarn(g) { if (!grenWarn.includes(g)) grenWarn.push(g); },
  playerDown(on) {
    $('downScreen').classList.toggle('show', on); app.classList.toggle('isdown', on);
    if (on) { input.clear(); if (document.pointerLockElement) document.exitPointerLock(); }
  },
  playerDead() { hooks.dead?.(); },
  reinforceTimer(t) { const el = $('reinf'); const s = Math.ceil(t); if (el.dataset.v != s) { el.dataset.v = s; el.textContent = `Подкрепление: ${s}с`; } },
  openShop() { openShop(); },
  droneMenu() {
    const P = G.player; droneMenuOpen = true; input.clear(); resetAimToggle();
    if (document.pointerLockElement) document.exitPointerLock();
    $('droneMenu').classList.add('show'); $('dmFpv').textContent = `1 · FPV-камикадзе ×${P.fpv}`; $('dmBomber').textContent = `2 · Бомбер ×${P.bombers}`;
  },
  setMode(m) {
    app.classList.remove('mode-foot', 'mode-tank', 'mode-aa', 'mode-drone'); app.classList.add('mode-' + m);
    resetAimToggle();
    const L = { foot: ['ОГОНЬ', 'ПРИЦЕЛ'], tank: ['ПУШКА', 'ЗУМ'], aa: ['ОГОНЬ', 'ЗУМ'], drone: ['', ''] }[m];
    $('bFire').querySelector('span').textContent = m === 'drone' ? (G.vehicle && G.vehicle.type === 'fpv' ? 'ПОДРЫВ' : 'СБРОС') : L[0];
    $('bAim').querySelector('span').textContent = L[1];
  },
  droneStatic(l) { staticLevel = Math.max(staticLevel, l); },
  scope(on) { on = !!on; $('scope').classList.toggle('show', on); $('crosshair').classList.toggle('hide', on); },
};
function esc(s) { return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }

function toScreen(v, out) {
  proj.copy(v).project(G.camera);
  const r = app.getBoundingClientRect();
  out.x = (proj.x * 0.5 + 0.5) * r.width; out.y = (-proj.y * 0.5 + 0.5) * r.height; out.vis = proj.z < 1 && proj.z > -1;
  return out;
}

const setText = (el, v) => { if (el._v !== v) { el._v = v; el.textContent = v; } };
const setW = (el, v) => { const s = Math.round(v * 1000) / 10 + '%'; if (el._w !== s) { el._w = s; el.style.width = s; } };
const scr = { x: 0, y: 0, vis: false };
const els = {};
const partEls = {};

export function updateHUD(dt, extra) {
  const P = G.player; if (!P) return;
  if (!els.hp) for (const id of ['hpFill', 'armFill', 'hpText', 'coins', 'tickA', 'tickE', 'wName', 'ammo', 'gren', 'band', 'actBtn', 'bleed', 'moraleFill', 'vignette', 'suppress', 'crosshair', 'vehHud', 'vhName', 'vhHp', 'vhReload', 'vhInfo', 'gunMark', 'droneHud', 'dAlt', 'dSpd', 'dBat', 'dSig', 'dDist', 'dMode', 'dBombs', 'dImpact', 'leads', 'static', 'grenW', 'compass', 'downTime', 'flagsRow', 'hpBar']) els[id.replace('Fill', '')] = $(id);
  // timers
  if ((msgT -= dt) <= 0) $('msg').classList.remove('show');
  if ((noticeT -= dt) <= 0) $('notice').classList.remove('show');
  if ((subT -= dt) <= 0) $('subtitle').classList.remove('show');
  if ((hitT -= dt) <= 0) $('hitmarker').className = '';
  // vitals
  setW(els.hp, clamp(P.hp / P.maxHp, 0, 1));
  els.hp.style.background = P.hp < P.maxHp * 0.3 ? '#ff3b30' : P.hp < P.maxHp * 0.6 ? '#ffb020' : '#4cd964';
  setW(els.arm, clamp(P.armor.vest / 220, 0, 1));
  setText(els.hpText, `${Math.max(0, Math.ceil(P.hp))}${P.armor.helmet ? ' ⛑' : ''}${P.armor.vest > 0 ? ' 🛡' + Math.ceil(P.armor.vest) : ''}`);
  els.bleed.classList.toggle('show', P.bleed > 0.05 && P.state === 'alive');
  setText(els.coins, P.coins);
  setText(els.tickA, G.teams[ALLY].tickets); setText(els.tickE, G.teams[ENEMY].tickets);
  setW(els.morale, G.teams[ALLY].morale / 100);
  // body diagram
  const sev = { head: 0, torso: 0, armL: 0, armR: 0, legL: 0, legR: 0 };
  for (const w of P.wounds) sev[w.part] = (sev[w.part] || 0) + w.sev;
  for (const k in sev) {
    const el = partEls[k] || (partEls[k] = $('p-' + k)); if (!el) continue;
    const s = sev[k]; const c = s <= 0 ? 'rgba(255,255,255,.28)' : s < 20 ? '#ffd23d' : s < 45 ? '#ff8a20' : '#ff2a20';
    if (el._c !== c) { el._c = c; el.style.fill = c; }
  }
  // flags
  for (const f of G.flags) {
    const el = $('flag' + f.name); if (!el) continue;
    const cls = 'flag ' + (f.owner === ALLY ? 'own' : f.owner === ENEMY ? 'enemy' : 'neutral') + (f.contested ? ' contested' : '');
    if (el.className !== cls) el.className = cls;
    el.style.setProperty('--p', ((f.progress + 1) / 2 * 100).toFixed(0) + '%');
  }
  // weapon info
  if (G.mode === 'foot') {
    const w = WEAPONS[P.weapon]; const a = P.ammo[P.weapon];
    setText(els.wName, w.name);
    setText(els.ammo, P.reloadT > 0 ? 'ПЕРЕЗАРЯДКА' : `${a.mag} / ${a.reserve}`);
    els.ammo.classList.toggle('low', a.mag <= Math.ceil(w.mag * 0.2));
  }
  setText(els.gren, `💣${P.grenades}  🩹${P.bandages}${P.medkits ? '  ✚' + P.medkits : ''}  🛸${P.fpv + P.bombers}`);
  // interact button
  const info = extra.interact;
  if (info && !(G.mode === 'foot' && info.kind === 'exit')) { els.actBtn.classList.add('show'); setText(els.actBtn.querySelector('span'), info.label); }
  else els.actBtn.classList.remove('show');
  // damage vignette & suppression
  dmgFlash = Math.max(0, dmgFlash - dt * 1.4);
  const low = P.state === 'alive' ? clamp(1 - P.hp / (P.maxHp * 0.45), 0, 1) : 1;
  const vig = Math.max(dmgFlash, low * (0.55 + 0.25 * Math.sin(G.time * 5)));
  els.vignette.style.opacity = vig.toFixed(2);
  suppress = Math.max(0, suppress - dt * 0.8); els.suppress.style.opacity = (suppress * 0.8).toFixed(2);
  // crosshair spread
  const sp = Math.hypot(P.vel.x, P.vel.z);
  const gap = 6 + sp * 2 + (P.heat || 0) * 6;
  els.crosshair.style.setProperty('--g', gap.toFixed(1) + 'px');
  // down screen
  if (P.state === 'down') setText(els.downTime, Math.ceil(P.downTimer) + ' с');
  // vehicle HUD
  if (G.mode === 'tank' && G.vehicle) {
    const t = G.vehicle;
    setText(els.vhName, t.T.name + (G.tankView === 'third' ? ' (3-е лицо)' : ''));
    setW(els.vhHp, clamp(t.hp / t.maxHp, 0, 1));
    setW(els.vhReload, clamp(1 - Math.max(0, t.reloadT) / t.T.reload, 0, 1));
    setText(els.vhInfo, `${t.T.gun === 'autocannon' ? '30мм ∞' : 'Снаряды: ' + t.shells}  •  ${Math.round(Math.abs(t.speed) * 3.6)} км/ч  •  ${Math.round(t.hp)} HP`);
    const gd = extra.gunDir; if (gd) {
      const p = new THREE.Vector3().copy(t.model.muzzle.getWorldPosition(new THREE.Vector3())).addScaledVector(gd, 150);
      toScreen(p, scr); els.gunMark.style.display = scr.vis ? 'block' : 'none'; els.gunMark.style.transform = `translate(${scr.x}px,${scr.y}px)`;
    }
  } else if (G.mode === 'aa' && G.vehicle) {
    const a = G.vehicle;
    setText(els.vhName, 'ПВО ЗУ-23-2'); setW(els.vhHp, clamp(a.hp / a.maxHp, 0, 1)); setW(els.vhReload, 1);
    const n = G.drones.filter(d => d.alive && d.team === ENEMY).length;
    setText(els.vhInfo, `Целей в воздухе: ${n}  •  Упреждение включено`);
  }
  // AA lead markers / drone indicators
  updateLeads(extra);
  // drone HUD
  if (G.mode === 'drone' && G.vehicle) {
    const d = G.vehicle;
    setText(els.dAlt, `ВЫС ${Math.round(d.pos.y - extra.groundY)} м`);
    setText(els.dSpd, `СКР ${Math.round(d.vel.length() * 3.6)} км/ч`);
    const bat = clamp(d.battery / d.maxBattery, 0, 1);
    setText(els.dBat, `🔋 ${Math.round(bat * 100)}%`); els.dBat.classList.toggle('low', bat < 0.2);
    const bars = Math.round(clamp(d.signal, 0, 1) * 5);
    setText(els.dSig, '📶 ' + '▮'.repeat(bars) + '▯'.repeat(5 - bars)); els.dSig.classList.toggle('low', bars <= 1);
    setText(els.dDist, `ДИСТ ${Math.round(d.pos.distanceTo(P.pos))} м`);
    setText(els.dMode, G.droneMode === 'sport' ? 'СПОРТ' : 'СТАБ');
    setText(els.dBombs, d.type === 'fpv' ? 'БЧ: ПГ-7В' : `СБРОС: ${d.bombs}`);
    staticLevel = Math.max(staticLevel * Math.exp(-dt * 2), clamp(1 - d.signal * 1.5, 0, 1) * 0.6);
    if (d.type === 'bomber' && extra.impact) { toScreen(extra.impact, scr); els.dImpact.style.display = scr.vis ? 'block' : 'none'; els.dImpact.style.transform = `translate(${scr.x}px,${scr.y}px)`; }
    else els.dImpact.style.display = 'none';
  } else staticLevel = Math.max(0, staticLevel - dt * 1.5);
  drawStatic();
  // grenade warnings
  for (let i = grenWarn.length - 1; i >= 0; i--) if (!G.grenades.includes(grenWarn[i])) grenWarn.splice(i, 1);
  if (grenWarn.length && G.mode === 'foot') { toScreen(grenWarn[0].pos, scr); els.grenW.style.display = 'block'; const r = app.getBoundingClientRect(); els.grenW.style.transform = `translate(${clamp(scr.vis ? scr.x : r.width / 2, 30, r.width - 30)}px,${clamp(scr.vis ? scr.y : r.height * 0.7, 80, r.height - 80)}px)`; }
  else els.grenW.style.display = 'none';
  // compass
  const deg = ((-P.camYaw * 180 / Math.PI) % 360 + 360) % 360;
  els.compass.style.backgroundPositionX = (-deg * 2) + 'px';
  // minimap
  mmT -= dt; if (mmT <= 0) { mmT = 0.12; drawMinimap(); }
}

const leadEls = [];
function updateLeads(extra) {
  const list = extra.leads || [];
  while (leadEls.length < list.length) { const e = document.createElement('div'); e.className = 'lead'; $('leads').appendChild(e); leadEls.push(e); }
  for (let i = 0; i < leadEls.length; i++) {
    const e = leadEls[i]; const L = list[i];
    if (!L) { e.style.display = 'none'; continue; }
    toScreen(L.p, scr); if (!scr.vis) { e.style.display = 'none'; continue; }
    e.style.display = 'block'; e.style.transform = `translate(${scr.x}px,${scr.y}px)`; e.className = 'lead ' + L.cls; e.dataset.d = L.label;
  }
}

let stCtx, stImg;
function drawStatic() {
  const c = $('static');
  if (staticLevel < 0.02) { if (c.style.display !== 'none') c.style.display = 'none'; return; }
  if (c.style.display !== 'block') c.style.display = 'block';
  if (!stCtx) { c.width = 96; c.height = 160; stCtx = c.getContext('2d'); stImg = stCtx.createImageData(96, 160); }
  const d = stImg.data;
  for (let i = 0; i < d.length; i += 4) { const v = Math.random() * 255; d[i] = d[i + 1] = d[i + 2] = v; d[i + 3] = 255; }
  stCtx.putImageData(stImg, 0, 0);
  c.style.opacity = staticLevel.toFixed(2);
}

function drawMinimap() {
  const c = $('minimap'); const x = c.getContext('2d'); const W = c.width, H = c.height;
  const sx = W / (MAP.maxX - MAP.minX), sz = H / (MAP.maxZ - MAP.minZ);
  const X = v => (v - MAP.minX) * sx, Z = v => (v - MAP.minZ) * sz;
  x.clearRect(0, 0, W, H);
  x.fillStyle = 'rgba(20,26,20,.75)'; x.fillRect(0, 0, W, H);
  x.strokeStyle = 'rgba(255,255,255,.08)'; x.lineWidth = 1;
  for (let i = 1; i < 6; i++) { x.beginPath(); x.moveTo(0, H * i / 6); x.lineTo(W, H * i / 6); x.stroke(); }
  for (const b of BASES) { x.fillStyle = b.team === ALLY ? 'rgba(61,139,255,.35)' : 'rgba(255,59,48,.35)'; x.fillRect(X(b.x - 38), Z(b.z - 24), 76 * sx, 48 * sz); }
  for (const f of G.flags) {
    x.fillStyle = f.owner === ALLY ? '#3d8bff' : f.owner === ENEMY ? '#ff3b30' : '#aaa';
    x.beginPath(); x.arc(X(f.x), Z(f.z), 6, 0, 7); x.fill();
    x.fillStyle = '#fff'; x.font = 'bold 8px sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText(f.name, X(f.x), Z(f.z) + 0.5);
  }
  const P = G.player;
  for (const u of G.units) {
    if (u.isPlayer || u.state === 'gone' || u.state === 'dead' || u.inVehicle) continue;
    if (u.team === ENEMY && !(G.time - (u.spottedByPlayer || -9) < 4 || u.pos.distanceTo(P.pos) < 18)) continue;
    x.fillStyle = u.team === ALLY ? (u.state === 'down' ? '#ff9' : '#6aa8ff') : '#ff5a50';
    x.fillRect(X(u.pos.x) - 1.5, Z(u.pos.z) - 1.5, 3, 3);
  }
  for (const t of G.tanks) { if (t.state !== 'alive') continue; if (t.team === ENEMY && t.pos.distanceTo(P.pos) > 90) continue; x.fillStyle = t.team === ALLY ? '#3d8bff' : '#ff3b30'; x.save(); x.translate(X(t.pos.x), Z(t.pos.z)); x.rotate(-t.yaw); x.fillRect(-3, -4, 6, 8); x.restore(); }
  for (const a of G.aas) { if (!a.alive) continue; x.strokeStyle = a.team === ALLY ? '#3d8bff' : '#ff3b30'; x.lineWidth = 1.5; x.beginPath(); x.arc(X(a.pos.x), Z(a.pos.z), 3, 0, 7); x.stroke(); }
  for (const d of G.drones) { if (!d.alive) continue; if (d.team === ENEMY && d.pos.distanceTo(P.pos) > 120) continue; x.fillStyle = d.team === ALLY ? '#9cf' : '#f90'; x.save(); x.translate(X(d.pos.x), Z(d.pos.z)); x.rotate(-d.yaw); x.beginPath(); x.moveTo(0, -4); x.lineTo(3, 3); x.lineTo(-3, 3); x.fill(); x.restore(); }
  // player arrow
  const pp = G.mode === 'drone' && G.vehicle ? G.vehicle.pos : P.pos;
  x.save(); x.translate(X(pp.x), Z(pp.z)); x.rotate(-P.camYaw);
  x.fillStyle = '#fff'; x.strokeStyle = '#000'; x.lineWidth = 1; x.beginPath(); x.moveTo(0, -6); x.lineTo(4, 4); x.lineTo(0, 2); x.lineTo(-4, 4); x.closePath(); x.fill(); x.stroke();
  x.restore();
  if (G.mode === 'drone') { x.fillStyle = '#fff'; x.fillRect(X(P.pos.x) - 2, Z(P.pos.z) - 2, 4, 4); }
}

// ======================= SHOP =======================
let shopOpen = false, shopCat = 'Оружие', droneMenuOpen = false;
function openShop() {
  const P = G.player; if (!P || P.state !== 'alive' || G.mode !== 'foot') return;
  const b = BASES[ALLY];
  if (Math.hypot(P.pos.x - b.x, P.pos.z - b.z) > 42) { ui.notice('Склад доступен только на базе'); SFX.denied(); return; }
  shopOpen = true; $('shop').classList.add('show'); input.clear(); resetAimToggle();
  if (document.pointerLockElement) document.exitPointerLock();
  renderShop();
}
export function closeShop() { shopOpen = false; $('shop').classList.remove('show'); if (!G.settings.mobile && G.running && !G.paused) $('c').requestPointerLock?.(); }
export const isShopOpen = () => shopOpen || droneMenuOpen;
function closeDroneMenu(type) {
  droneMenuOpen = false; $('droneMenu').classList.remove('show');
  if (type) hooks.drone(type);
  if (!G.settings.mobile && G.running && !G.paused) $('c').requestPointerLock?.();
}
function renderShop() {
  const P = G.player;
  $('shopCoins').textContent = P.coins;
  const cats = [...new Set(SHOP.map(s => s.cat))];
  $('shopTabs').innerHTML = cats.map(c => `<button class="tab ${c === shopCat ? 'on' : ''}" data-cat="${c}">${c}</button>`).join('');
  $('shopList').innerHTML = SHOP.filter(s => s.cat === shopCat).map(s => {
    const st = hooks.shopState(s);
    return `<div class="item ${st.owned ? 'owned' : ''}"><div class="in"><b>${s.name}</b><small>${s.desc}</small>${st.note ? `<em>${st.note}</em>` : ''}</div>
      <button data-buy="${s.id}" class="${P.coins < s.price && !st.owned ? 'poor' : ''}">${st.owned ? (st.btn || 'Есть') : s.price + ' 🪙'}</button></div>`;
  }).join('');
}
export function initShop() {
  $('shopTabs').addEventListener('click', e => { const b = e.target.closest('[data-cat]'); if (!b) return; shopCat = b.dataset.cat; SFX.uiClick(); renderShop(); });
  $('shopList').addEventListener('click', e => { const b = e.target.closest('[data-buy]'); if (!b) return; const it = SHOP.find(s => s.id === b.dataset.buy); hooks.buy(it); renderShop(); });
  $('shopClose').addEventListener('click', closeShop);
  $('dmFpv').addEventListener('click', () => closeDroneMenu('fpv'));
  $('dmBomber').addEventListener('click', () => closeDroneMenu('bomber'));
  $('dmClose').addEventListener('click', () => closeDroneMenu(null));
}

// ======================= MENU =======================
export function buildMenu(onStart) {
  let sel = 0;
  const list = $('chars');
  list.innerHTML = CHARACTERS.map((c, i) => `<button class="char ${i === 0 ? 'on' : ''}" data-i="${i}"><i>${c.icon}</i><b>${c.name}</b><span>${c.title}</span><small>${c.desc}</small></button>`).join('');
  list.addEventListener('click', e => { const b = e.target.closest('.char'); if (!b) return; sel = +b.dataset.i; list.querySelectorAll('.char').forEach(x => x.classList.toggle('on', x === b)); SFX.uiClick(); });
  const q = $('quality'); q.addEventListener('click', () => { G.settings.quality = G.settings.quality === 'high' ? 'low' : 'high'; q.textContent = 'Графика: ' + (G.settings.quality === 'high' ? 'Высокая' : 'Низкая'); });
  q.textContent = 'Графика: ' + (G.settings.quality === 'high' ? 'Высокая' : 'Низкая');
  const s = $('sens'); s.value = G.settings.sens; s.addEventListener('input', () => { G.settings.sens = +s.value; $('sens2').value = s.value; });
  const s2 = $('sens2'); s2.addEventListener('input', () => { G.settings.sens = +s2.value; s.value = s2.value; });
  $('startBtn').addEventListener('click', () => onStart(CHARACTERS[sel]));
}
