// Entry point: setup, game rules, main loop
import * as THREE from '../lib/three.module.min.js';
import { G, ALLY, ENEMY, clamp, rand, pick } from './state.js';
import { buildWorld, updateWorld, BASES, heightAt } from './world.js';
import { initEffects, updateEffects, setParticleScale, healFx } from './effects.js';
import { initAudio, setPausedAudio, speak, radioBeep, coin, denied, audio } from './audio.js';
import { updateUnits, spawnSquad, spawnBaseMedics, commanderShout } from './units.js';
import { updateVehicles, spawnTeamTank, spawnAA, bombImpact, leadPoint } from './vehicles.js';
import { updateProjectiles, updateGrenades, award, killUnit } from './combat.js';
import { createPlayer, updatePlayer, initViewModels, resetLoadout, interactInfo, startDrone, endDrone, exitVehicle, playerGunDir, switchWeapon } from './player.js';
import { ui, input, initInput, updateHUD, buildMenu, initShop, isShopOpen, closeShop } from './ui.js';
import { WEAPONS, COINS } from './data.js';

const $ = id => document.getElementById(id);
const app = $('app'), canvas = $('c');
G.settings.mobile = matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window;
G.settings.quality = G.settings.mobile ? 'low' : 'high';
G.droneMode = 'stab'; G.tankView = 'first';
app.classList.toggle('mobile', G.settings.mobile);

let last = performance.now();
let tickT = 0, flagT = 0;

function start(char) {
  initAudio();
  if (G.settings.mobile) { // go fullscreen and lock to landscape where supported
    const el = document.documentElement;
    const req = el.requestFullscreen || el.webkitRequestFullscreen;
    try { const pr = req && req.call(el, { navigationUI: 'hide' }); if (pr && pr.then) pr.then(() => screen.orientation?.lock?.('landscape').catch(() => {})).catch(() => {}); } catch (e) {}
  }
  $('menu').classList.remove('show');
  $('loading').classList.add('show');
  setTimeout(() => setup(char), 60);
}

function setup(char) {
  const hi = G.settings.quality === 'high';
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: hi, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(devicePixelRatio, hi ? 1.75 : 1.2));
  renderer.shadowMap.enabled = hi; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.15;
  renderer.autoClear = false;
  G.renderer = renderer;
  G.scene = new THREE.Scene();
  G.camera = new THREE.PerspectiveCamera(80, 0.5, 0.08, 800);
  G.vmScene = new THREE.Scene();
  G.vmCamera = new THREE.PerspectiveCamera(58, 0.5, 0.01, 10);
  G.vmScene.add(new THREE.HemisphereLight(0xb8c4d0, 0x3a3428, 1.6));
  const vl = new THREE.DirectionalLight(0xffffff, 1.2); vl.position.set(1, 2, 1); G.vmScene.add(vl);

  buildWorld(G.scene, G.settings.quality);
  initEffects(G.scene);
  initViewModels();
  createPlayer(char);
  app.classList.toggle('tankRepair', !!(char.perks && char.perks.repair));
  for (let i = 0; i < 3; i++) { const extra = i === 2 ? 'operator' : i === 1 ? 'at' : undefined; spawnSquad(ALLY, extra, 34 + i * 6); spawnSquad(ENEMY, extra, 34 + i * 6); }
  spawnBaseMedics();
  spawnTeamTank(ALLY, 'light'); spawnTeamTank(ALLY, 'medium'); spawnTeamTank(ALLY, 'heavy', true);
  spawnTeamTank(ENEMY, 'light'); spawnTeamTank(ENEMY, 'medium'); spawnTeamTank(ENEMY, 'heavy');
  for (const b of BASES) {
    spawnAA(b.team, new THREE.Vector3(b.x + 22, 0, b.z + b.dir * 14));
    spawnAA(b.team, new THREE.Vector3(b.x - 30, 0, b.z + b.dir * 16));
  }
  spawnAA(ALLY, new THREE.Vector3(34, 0, 64)); spawnAA(ENEMY, new THREE.Vector3(32, 0, -64));
  resize();
  ui.setMode('foot');
  $('loading').classList.remove('show');
  G.running = true; G.paused = false;
  setPausedAudio(false);
  if (!G.settings.mobile) canvas.requestPointerLock?.();
  setTimeout(() => {
    radioBeep();
    const cmd = G.units.find(u => u.team === ALLY && u.role === 'commander');
    const line = 'Бойцы! Задача — захватить точки Бэ и Цэ. Танки поддержат. Вперёд, за мной!';
    speak(line, { pitch: 0.7, rate: 1.1, force: true });
    ui.subtitle(`📻 Командир ${cmd ? cmd.name : ''}`, line, ALLY);
  }, 1500);
  ui.message('⚔ Захватите точки B и C', 3);
}

// ---------- flags & tickets ----------
function updateFlags(dt) {
  flagT -= dt; if (flagT > 0) return; const step = 0.25; flagT = step;
  for (const f of G.flags) {
    let a = 0, e = 0, playerIn = false;
    for (const u of G.units) {
      if (u.state !== 'alive' || u.inVehicle || u.role === 'basemedic') continue;
      if (Math.hypot(u.pos.x - f.x, u.pos.z - f.z) < 10) { if (u.team === ALLY) a++; else e++; if (u.isPlayer) playerIn = true; }
    }
    for (const t of G.tanks) if (t.state === 'alive' && Math.hypot(t.pos.x - f.x, t.pos.z - f.z) < 12) { if (t.team === ALLY) a += 2; else e += 2; if (t.playerCtrl) playerIn = true; }
    f.contested = a > 0 && e > 0;
    const diff = a - e;
    const prevOwner = f.owner;
    if (diff !== 0) f.progress = clamp(f.progress + clamp(diff, -4, 4) * 0.035 * step, -1, 1);
    if (f.progress >= 1) f.owner = ALLY; else if (f.progress <= -1) f.owner = ENEMY;
    else if ((f.owner === ALLY && f.progress < 0) || (f.owner === ENEMY && f.progress > 0)) f.owner = -1;
    f.playerIn = playerIn;
    if (f.owner !== prevOwner) {
      const col = f.owner === ALLY ? 0x2f6ad0 : f.owner === ENEMY ? 0xc0281e : 0xbbbbbb;
      f.model.userData.clothMat.color.setHex(col);
      if (f.owner === ALLY) {
        ui.message(`🚩 Точка ${f.name} захвачена!`, 2.5);
        G.teams[ALLY].morale = clamp(G.teams[ALLY].morale + 8, 5, 100);
        if (playerIn) award(COINS.capture, `Захват ${f.name}`);
        const c = G.units.find(u => u.team === ALLY && u.role === 'commander' && u.state === 'alive'); if (c) commanderShout(c, 'captured');
      } else if (prevOwner === ALLY) {
        ui.message(`⚠ Точка ${f.name} потеряна!`, 2.5);
        G.teams[ALLY].morale = clamp(G.teams[ALLY].morale - 8, 5, 100);
        const c = G.units.find(u => u.team === ALLY && u.role === 'commander' && u.state === 'alive'); if (c) commanderShout(c, 'lost');
      }
    }
    const ringCol = f.owner === ALLY ? 0x3d8bff : f.owner === ENEMY ? 0xff3b30 : 0xffffff;
    f.ring.material.color.setHex(ringCol); f.ring.material.opacity = f.contested ? 0.35 + 0.25 * Math.sin(G.time * 8) : 0.25;
  }
  tickT -= step;
  if (tickT <= 0) {
    tickT = 4;
    const own = [0, 0]; for (const f of G.flags) if (f.owner >= 0) own[f.owner]++;
    if (own[ALLY] > own[ENEMY]) G.teams[ENEMY].tickets = Math.max(0, G.teams[ENEMY].tickets - (own[ALLY] - own[ENEMY]));
    if (own[ENEMY] > own[ALLY]) G.teams[ALLY].tickets = Math.max(0, G.teams[ALLY].tickets - (own[ENEMY] - own[ALLY]));
    // morale drifts toward the flag balance
    for (const t of [ALLY, ENEMY]) G.teams[t].morale = clamp(G.teams[t].morale + (own[t] - own[1 - t]) * 0.6 + (60 - G.teams[t].morale) * 0.02, 5, 100);
  }
  if (!G.over && (G.teams[ALLY].tickets <= 0 || G.teams[ENEMY].tickets <= 0)) endGame(G.teams[ENEMY].tickets <= 0);
}

// ---------- base medical tents ----------
let tentNoticeT = 0;
function baseHeal(dt) {
  for (const b of BASES) for (const u of G.units) {
    if (u.team !== b.team || u.inVehicle || u.state === 'dead' || u.state === 'gone') continue;
    if (Math.hypot(u.pos.x - b.med.x, u.pos.z - b.med.z) > 9) continue;
    if (u.state === 'down') { u.state = 'alive'; u.hp = 30; u.fallT = 0; u.model.userData.parts.body.rotation.set(0, 0, 0); if (u.isPlayer) ui.playerDown(false); }
    if (u.hp < u.maxHp || u.bleed > 0) {
      u.hp = Math.min(u.maxHp, u.hp + 14 * dt); u.bleed = 0;
      u.wounds.forEach(w => w.sev -= dt * 6); u.wounds = u.wounds.filter(w => w.sev > 0);
      if (Math.random() < dt * 3) healFx(u.pos);
      if (u.isPlayer && G.time > tentNoticeT) { tentNoticeT = G.time + 3; ui.notice('✚ Медпункт: вас лечат'); }
    }
  }
}

// ---------- shop ----------
function shopState(it) {
  const P = G.player;
  if (it.weapon) { const own = P.owned.includes(it.weapon); return { owned: own, btn: own ? (P.weapon === it.weapon ? 'В руках' : 'Взять') : null, note: own ? `${P.ammo[it.weapon].mag}/${P.ammo[it.weapon].reserve}` : '' }; }
  if (it.id === 'helmet') return { owned: P.armor.helmet };
  if (it.id === 'vest') return { owned: P.armor.vest >= 120 && !P.armor.heavy, note: P.armor.vest > 0 ? `Броня: ${Math.ceil(P.armor.vest)}` : '' };
  if (it.id === 'heavy') return { owned: P.armor.heavy && P.armor.vest >= 200 };
  if (it.id === 'grenades') return { note: `Есть: ${P.grenades}` };
  if (it.id === 'bandages') return { note: `Есть: ${P.bandages}` };
  if (it.id === 'medkit') return { note: `Есть: ${P.medkits}` };
  if (it.id === 'fpv') return { note: `Есть: ${P.fpv}` };
  if (it.id === 'bomber') return { note: `Есть: ${P.bombers}` };
  if (it.id === 'rockets') return { note: P.owned.includes('rpg') ? `Есть: ${P.ammo.rpg.reserve + P.ammo.rpg.mag}` : 'Нужен РПГ-7' };
  return {};
}
function buy(it) {
  const P = G.player; const st = shopState(it);
  if (it.weapon && st.owned) { switchWeapon(0, P.owned.indexOf(it.weapon)); return; }
  if (st.owned) { denied(); return; }
  if (P.coins < it.price) { denied(); ui.notice('Недостаточно монет'); return; }
  const lim = { grenades: [P.grenades, 8], bandages: [P.bandages, 10], medkit: [P.medkits, 4], fpv: [P.fpv, 5], bomber: [P.bombers, 3] }[it.id];
  if (lim && lim[0] >= lim[1]) { denied(); ui.notice('Максимум'); return; }
  if (it.id === 'rockets' && !P.owned.includes('rpg')) { denied(); ui.notice('Сначала купите РПГ-7'); return; }
  P.coins -= it.price; coin();
  if (it.weapon) { P.owned.push(it.weapon); P.ammo[it.weapon] = { mag: WEAPONS[it.weapon].mag, reserve: WEAPONS[it.weapon].reserve }; switchWeapon(0, P.owned.length - 1); }
  else switch (it.id) {
    case 'helmet': P.armor.helmet = true; break;
    case 'vest': P.armor.vest = Math.max(P.armor.vest, 120); P.armor.heavy = false; break;
    case 'heavy': P.armor.vest = 220; P.armor.heavy = true; break;
    case 'ammo': for (const id of P.owned) P.ammo[id].reserve = WEAPONS[id].reserve; break;
    case 'grenades': P.grenades = Math.min(8, P.grenades + 2); break;
    case 'bandages': P.bandages = Math.min(10, P.bandages + 3); break;
    case 'medkit': P.medkits++; break;
    case 'rockets': P.ammo.rpg.reserve += 2; break;
    case 'fpv': P.fpv++; break;
    case 'bomber': P.bombers++; break;
  }
  ui.notice(`Куплено: ${it.name}`);
}

// ---------- death / respawn ----------
let respawnT = 0;
function onPlayerDead() {
  const P = G.player; G.dead = true; G.stats.deaths++;
  if (G.mode === 'drone') endDrone(); else if (G.mode !== 'foot') exitVehicle(true);
  ui.playerDown(false);
  const k = P.lastAttacker;
  $('deadBy').textContent = k ? (k.isUnit ? `Вас убил: ${k.name} (${k.weaponName ? k.weaponName() : ''})` : `Вас уничтожил: ${k.name}`) : 'Вы погибли';
  const parts = {}; for (const w of P.wounds) parts[w.part] = (parts[w.part] || 0) + w.sev;
  const names = { head: 'голова', torso: 'корпус', armL: 'л. рука', armR: 'п. рука', legL: 'л. нога', legR: 'п. нога' };
  $('deadWounds').textContent = 'Ранения: ' + (Object.keys(parts).map(p => `${names[p]} (${Math.round(parts[p])})`).join(', ') || '—');
  $('deadScreen').classList.add('show'); respawnT = 6; $('respawnBtn').disabled = true;
  if (document.pointerLockElement) document.exitPointerLock();
  input.clear();
}
function respawn() {
  const P = G.player; if (respawnT > 0) return;
  $('deadScreen').classList.remove('show'); G.dead = false;
  resetLoadout(P, false);
  P.lastAttacker = null;
  if (!G.settings.mobile) canvas.requestPointerLock?.();
  ui.message('Вы снова в строю. Подкрепление на базе', 2);
}

// ---------- pause / end ----------
function pause(on) {
  if (!G.running || G.over) return;
  G.paused = on; $('pause').classList.toggle('show', on); setPausedAudio(on); input.clear();
  if (on && document.pointerLockElement) document.exitPointerLock();
  if (!on && !G.settings.mobile) canvas.requestPointerLock?.();
}
function endGame(win) {
  G.over = true;
  $('endTitle').textContent = win ? 'ПОБЕДА' : 'ПОРАЖЕНИЕ';
  $('endTitle').className = win ? 'win' : 'lose';
  const s = G.stats;
  $('endStats').innerHTML = `<div>Убито: <b>${s.kills}</b> (в голову ${s.headshots})</div><div>Смертей: <b>${s.deaths}</b></div><div>Танков: <b>${s.tanks}</b> • Дронов: <b>${s.drones}</b></div><div>Поднято раненых: <b>${s.revives}</b></div><div>Заработано: <b>${s.earned} 🪙</b></div>`;
  $('end').classList.add('show');
  if (document.pointerLockElement) document.exitPointerLock();
  speak(win ? 'Победа! Враг отступает! Отличная работа, бойцы!' : 'Отступаем! Всем отходить!', { force: true, pitch: 0.7 });
}

// ---------- layout ----------
function resize() {
  const r = app.getBoundingClientRect();
  const w = Math.max(1, Math.round(r.width)), h = Math.max(1, Math.round(r.height));
  if (!G.renderer) return;
  G.renderer.setSize(w, h, false);
  const asp = w / h;
  G.baseFov = asp < 1 ? 86 : 70;
  G.vmScale = asp < 1 ? 0.7 : 0.55;
  G.camera.aspect = asp; G.camera.fov = G.baseFov; G.camera.updateProjectionMatrix();
  G.vmCamera.aspect = asp; G.vmCamera.fov = asp < 1 ? 92 : 68; G.vmCamera.updateProjectionMatrix();
  setParticleScale(G.renderer.domElement.height, G.camera.fov);
  const mm = $('minimap'); mm.width = mm.clientWidth * 2; mm.height = mm.clientHeight * 2;
}
addEventListener('resize', resize);
addEventListener('orientationchange', () => setTimeout(resize, 300));

// ---------- loop ----------
const _v = new THREE.Vector3();
function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (!G.running) return;
  if (G.dead) { respawnT -= dt; const b = $('respawnBtn'); b.disabled = respawnT > 0; b.textContent = respawnT > 0 ? `В бой через ${Math.ceil(respawnT)}…` : 'В БОЙ'; }
  if (!G.paused) {
    G.time += dt; G.dt = dt;
    if (isShopOpen()) input.clear();
    updatePlayer(dt);
    updateUnits(dt);
    updateVehicles(dt);
    updateProjectiles(dt);
    updateGrenades(dt);
    updateFlags(dt);
    baseHeal(dt);
    updateWorld(dt, G.camera.position);
    updateEffects(dt);
    // HUD extras
    const extra = { interact: interactInfo(), leads: [] };
    const P = G.player;
    if (G.mode === 'tank') extra.gunDir = playerGunDir();
    if (G.mode === 'aa' && G.vehicle) {
      const from = G.vehicle.model.pitchG.getWorldPosition(new THREE.Vector3());
      for (const d of G.drones) if (d.alive && d.team === ENEMY && d.pos.distanceTo(from) < 320) {
        extra.leads.push({ p: leadPoint(from, d, new THREE.Vector3()), cls: 'aa', label: Math.round(d.pos.distanceTo(from)) + 'м' });
        extra.leads.push({ p: d.pos.clone(), cls: 'dronebox', label: d.type === 'fpv' ? 'FPV' : 'БОМБ' });
      }
    } else if (G.mode === 'drone' && G.vehicle) {
      const dp = G.vehicle.pos;
      for (const t of G.tanks) if (t.state === 'alive' && t.team === ENEMY && t.pos.distanceTo(dp) < 260) extra.leads.push({ p: _v.copy(t.pos).setY(t.pos.y + 2).clone(), cls: 'tgt', label: 'ТАНК ' + Math.round(t.pos.distanceTo(dp)) + 'м' });
      for (const a of G.aas) if (a.alive && a.team === ENEMY && a.pos.distanceTo(dp) < 260) extra.leads.push({ p: a.pos.clone().setY(a.pos.y + 2), cls: 'threat', label: 'ПВО!' });
      for (const u of G.units) if (u.team === ENEMY && u.state === 'alive' && u.pos.distanceTo(dp) < 70) extra.leads.push({ p: u.pos.clone().setY(u.pos.y + 1), cls: 'inf', label: '' });
      extra.groundY = heightAt(dp.x, dp.z);
      if (G.vehicle.type === 'bomber') extra.impact = bombImpact(G.vehicle, new THREE.Vector3());
    } else {
      for (const d of G.drones) if (d.alive && d.team === ENEMY && d.pos.distanceTo(P.pos) < 110) extra.leads.push({ p: d.pos.clone(), cls: 'droneWarn', label: Math.round(d.pos.distanceTo(P.pos)) + 'м' });
    }
    updateHUD(dt, extra);
    app.classList.toggle('tank3', G.tankView === 'third');
  }
  const r = G.renderer;
  r.clear(); r.render(G.scene, G.camera);
  r.clearDepth(); r.render(G.vmScene, G.vmCamera);
}

// ---------- boot ----------
initInput({ pause, dead: onPlayerDead, buy, shopState, drone: t => startDrone(t) });
initShop();
buildMenu(start);
$('resumeBtn').addEventListener('click', () => pause(false));
$('restartBtn').addEventListener('click', () => location.reload());
$('againBtn').addEventListener('click', () => location.reload());
$('respawnBtn').addEventListener('click', respawn);
$('giveUpBtn').addEventListener('click', () => { const P = G.player; if (P && P.state === 'down') killUnit(P, P.lastAttacker, 'bleed', false); });
document.addEventListener('visibilitychange', () => { if (document.hidden && G.running && !G.paused) pause(true); });
requestAnimationFrame(frame);
window.G = G; G.input = input; G.audio = audio; // debug handle
