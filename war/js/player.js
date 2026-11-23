// Player: first-person controller, weapons, viewmodel, vehicles & drone control
import * as THREE from '../lib/three.module.min.js';
import { G, ALLY, ENEMY, rand, clamp, damp, angDiff } from './state.js';
import { heightAt, groundAt, pushOut, BASES } from './world.js';
import { makeViewModel } from './models.js';
import { WEAPONS } from './data.js';
import * as FX from './effects.js';
import * as SFX from './audio.js';
import { fireBullet, spawnProjectile, throwGrenade, award, killUnit, raycastAll } from './combat.js';
import { createUnit, healUnit, legFactor, markSpotted } from './units.js';
import { driveTank, fireTankGun, tankMG, gunDir, controlDrone, launchDrone, fireAA, poseAA, leadPoint, setVehicleHooks } from './vehicles.js';
import { ui, input } from './ui.js';

const _v = new THREE.Vector3(), _a = new THREE.Vector3(), _b = new THREE.Vector3(), _d = new THREE.Vector3();
const fwd = new THREE.Vector3(), right = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
const VM = {};
let vmCur = null, vmId = null;
const vmState = { kick: 0, kickRot: 0, swayX: 0, swayY: 0, bob: 0, ads: 0, reload: 0, switchT: 0, sprint: 0, flash: 0, throwT: 0 };
let muzzleSprite;

export function createPlayer(char) {
  const b = BASES[ALLY];
  const P = createUnit(ALLY, 'player', new THREE.Vector3(b.spawn.x, 0, b.spawn.z), { player: true, name: char.name, weapon: char.weapons[0], hp: char.hp });
  P.char = char; P.perks = char.perks || {};
  P.coins = 300; P.camYaw = 0; P.camPitch = 0; P.recoilP = 0; P.recoilY = 0;
  resetLoadout(P, true);
  P.model.visible = false;
  G.player = P;
  setVehicleHooks(endDrone, () => exitVehicle(true));
  return P;
}

export function resetLoadout(P, first) {
  const c = P.char;
  if (first) { P.owned = [...c.weapons]; }
  P.ammo = {};
  for (const id of P.owned) P.ammo[id] = { mag: WEAPONS[id].mag, reserve: WEAPONS[id].reserve };
  P.cur = 0; P.weapon = P.owned[0];
  P.grenades = Math.max(P.grenades || 0, c.grenades); P.bandages = Math.max(P.bandages || 0, c.bandages); P.medkits = Math.max(P.medkits || 0, c.medkits);
  P.fpv = Math.max(P.fpv || 0, c.fpv); P.bombers = Math.max(P.bombers || 0, c.bombers);
  P.armor = { helmet: !!c.helmet, vest: c.vest ? 120 : 0, heavy: false, maxVest: c.vest ? 120 : 0 };
  P.hp = P.maxHp; P.bleed = 0; P.wounds = []; P.state = 'alive'; P.reloadT = 0; P.fireCd = 0; P.actionT = 0; P.action = null;
  P.vy = 0; P.crouch = false; P.inVehicle = null; P.credited = false; P.spawnProt = 3; P.downTimer = 0;
  // clean wound decals from model
  P.model.traverse(o => { if (o.isMesh && o.geometry.type === 'SphereGeometry' && o.geometry.parameters.radius < 0.1) o.visible = false; });
  P.decals = 0;
  const b = BASES[ALLY];
  P.pos.set(b.spawn.x + rand(-6, 6), 0, b.spawn.z + rand(-2, 2)); P.pos.y = heightAt(P.pos.x, P.pos.z);
  P.camYaw = 0; P.camPitch = 0;
  const parts = P.model.userData.parts; parts.body.rotation.set(0, 0, 0); parts.body.position.y = 0;
  setViewModel(P.weapon);
}

export function initViewModels() {
  for (const id of [...Object.keys(WEAPONS), 'grenade']) { VM[id] = makeViewModel(id); VM[id].visible = false; G.vmScene.add(VM[id]); }
  const c = document.createElement('canvas'); c.width = c.height = 64; const x = c.getContext('2d');
  const g = x.createRadialGradient(32, 32, 2, 32, 32, 30); g.addColorStop(0, 'rgba(255,240,200,1)'); g.addColorStop(0.3, 'rgba(255,180,80,.8)'); g.addColorStop(1, 'rgba(255,120,20,0)');
  x.fillStyle = g; x.fillRect(0, 0, 64, 64);
  for (let i = 0; i < 6; i++) { x.strokeStyle = 'rgba(255,220,150,.7)'; x.lineWidth = 3; x.beginPath(); x.moveTo(32, 32); const a = i / 6 * 6.28; x.lineTo(32 + Math.cos(a) * 30, 32 + Math.sin(a) * 30); x.stroke(); }
  muzzleSprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: new THREE.CanvasTexture(c), blending: THREE.AdditiveBlending, depthTest: false, transparent: true }));
  muzzleSprite.scale.set(0.25, 0.25, 1); muzzleSprite.visible = false; G.vmScene.add(muzzleSprite);
}

function setViewModel(id) {
  if (vmCur) vmCur.visible = false;
  vmCur = VM[id]; vmId = id; if (vmCur) vmCur.visible = true;
  vmState.switchT = 0.45;
}

const W = () => WEAPONS[G.player.weapon];
export function switchWeapon(dir = 1, idx = null) {
  const P = G.player; if (P.reloadT > 0 || P.actionT > 0) return;
  P.cur = idx !== null ? idx : (P.cur + dir + P.owned.length) % P.owned.length;
  P.weapon = P.owned[P.cur];
  setViewModel(P.weapon); SFX.reloadSound(0.4, 'switch');
  ui.notice(WEAPONS[P.weapon].name);
}

function startReload() {
  const P = G.player; const w = W(); const a = P.ammo[P.weapon];
  if (P.reloadT > 0 || a.mag >= w.mag || a.reserve <= 0) return;
  P.reloadT = w.reload; vmState.reload = 0;
  SFX.reloadSound(w.reload, w.kind === 'shotgun' ? 'shotgun' : w.kind === 'rocket' ? 'rocket' : 'mag');
}

function playerFire(dt) {
  const P = G.player; const w = W(); const a = P.ammo[P.weapon];
  P.fireCd -= dt;
  if (P.reloadT > 0) {
    P.reloadT -= dt;
    if (P.reloadT <= 0) { const need = w.mag - a.mag; const n = Math.min(need, a.reserve); a.mag += n; a.reserve -= n; }
    return;
  }
  if (P.actionT > 0 || vmState.switchT > 0.1 || vmState.sprint > 0.5) return;
  const tapped = input.take('fire');
  const want = w.auto ? (input.fire || tapped) : tapped;
  if (!want || P.fireCd > 0) return;
  if (a.mag <= 0) { SFX.emptyClick(); P.fireCd = 0.3; if (a.reserve > 0) startReload(); else ui.notice('Нет патронов! Купите на складе'); input.take('fire'); return; }
  a.mag--; P.fireCd = 60 / w.rpm;
  const cam = G.camera;
  cam.getWorldDirection(fwd);
  const moving = Math.hypot(P.vel.x, P.vel.z) > 0.5;
  const armW = P.wounds.reduce((s, x) => s + (x.part.startsWith('arm') ? x.sev : 0), 0);
  let spread = (vmState.ads > 0.7 ? w.spread : w.hip) * (moving ? 1.8 : 1) * (P.crouch ? 0.75 : 1) * (1 + armW / 60) + P.heat * 0.012;
  if (P.perks.steady) spread *= 0.8;
  const muzzle = muzzleWorld(_a);
  if (w.projectile === 'rocket') {
    _d.copy(fwd); _d.x += rand(-spread, spread); _d.y += rand(-spread, spread); _d.normalize();
    spawnProjectile({ type: 'rocket', pos: _b.copy(cam.position).addScaledVector(fwd, 0.8), vel: _d.clone().multiplyScalar(75), src: P, grav: 1.2, life: 5, radius: 5, dmg: 130, tankDmg: 520, size: 0.9 });
    SFX.explosion(cam.position, 0.3); FX.muzzleFlash(muzzle, fwd, 2);
    for (let i = 0; i < 8; i++) FX.dustPuff(_v.copy(cam.position).addScaledVector(fwd, -1.5), 1, [0.6, 0.6, 0.6]);
  } else {
    const n = w.pellets || 1;
    for (let i = 0; i < n; i++) {
      _d.copy(fwd); _d.x += rand(-spread, spread); _d.y += rand(-spread, spread); _d.z += rand(-spread, spread); _d.normalize();
      const hit = fireBullet(P, cam.position, _d, w, muzzle);
      if (hit && hit.type === 'unit' && hit.u.team === ENEMY) markSpotted(hit.u);
    }
    SFX.shot(w.sound, null, true); SFX.shellCasing();
    FX.muzzleFlash(muzzle, fwd, w.kind === 'pistol' ? 0.6 : 1);
    right.crossVectors(fwd, up).normalize(); FX.casing(_v.copy(muzzle).addScaledVector(fwd, -0.4), right);
  }
  // recoil
  const steady = P.perks.steady || 1;
  const rk = w.recoil * steady * (P.crouch ? 0.75 : 1) * (vmState.ads > 0.7 ? 0.8 : 1);
  P.recoilP += rk * rand(0.8, 1.15); P.recoilY += rk * rand(-0.45, 0.45);
  P.heat = Math.min(3, (P.heat || 0) + 0.35);
  vmState.kick = Math.min(1.5, vmState.kick + (w.kind === 'sniper' || w.kind === 'shotgun' || w.kind === 'rocket' ? 1.4 : 0.6)); vmState.flash = 0.05;
  G.shake = Math.max(G.shake, w.kind === 'rocket' ? 0.5 : w.kind === 'sniper' || w.kind === 'shotgun' ? 0.25 : 0.06);
  if (a.mag === 0 && a.reserve > 0) setTimeout(startReload, 250);
}

function muzzleWorld(out) {
  const cam = G.camera; cam.getWorldDirection(fwd); right.crossVectors(fwd, up).normalize();
  const ads = vmState.ads;
  return out.copy(cam.position).addScaledVector(fwd, 0.9).addScaledVector(right, 0.16 * (1 - ads)).addScaledVector(up, -0.1 * (1 - ads) - 0.03);
}

function throwPlayerGrenade() {
  const P = G.player; if (P.grenades <= 0) { SFX.denied(); ui.notice('Нет гранат'); return; }
  if (P.actionT > 0 || P.reloadT > 0) return;
  P.grenades--; P.action = 'throw'; P.actionT = 0.75; vmState.throwT = 0;
  SFX.grenadePin();
  if (vmCur) vmCur.visible = false; VM.grenade.visible = true;
  setTimeout(() => {
    if (P.state !== 'alive') return;
    const cam = G.camera; cam.getWorldDirection(fwd);
    const v = fwd.clone().multiplyScalar(17).add(_v.set(0, 3.5, 0)).add(P.vel);
    throwGrenade(P, _a.copy(cam.position).addScaledVector(fwd, 0.5), v);
    SFX.throwWhoosh();
  }, 380);
  setTimeout(() => { VM.grenade.visible = false; if (vmCur && G.mode === 'foot') vmCur.visible = true; vmState.switchT = 0.3; }, 750);
}

export function useMedical() {
  const P = G.player; if (P.state !== 'alive' || P.actionT > 0) return;
  if (P.medkits > 0 && (P.hp < P.maxHp * 0.6 || (P.bandages <= 0 && P.hp < P.maxHp))) { P.medkits--; P.action = 'medkit'; P.actionT = 3.2; SFX.bandage(); ui.notice('Используется аптечка...'); return; }
  if (P.bandages > 0 && (P.bleed > 0 || P.hp < P.maxHp)) { P.bandages--; P.action = 'bandage'; P.actionT = 2.2; SFX.bandage(); ui.notice('Перевязка...'); return; }
  SFX.denied(); ui.notice(P.bandages <= 0 && P.medkits <= 0 ? 'Нет бинтов и аптечек' : 'Вы не ранены');
}

function finishAction() {
  const P = G.player;
  if (P.action === 'bandage') { P.bleed = 0; P.hp = Math.min(P.maxHp, P.hp + 15); P.wounds.forEach(w => w.sev *= 0.6); ui.notice('Кровотечение остановлено'); }
  else if (P.action === 'medkit') { P.bleed = 0; P.hp = Math.min(P.maxHp, P.hp + 60); P.wounds = []; ui.notice('Раны обработаны (+60)'); }
  else if (P.action === 'revive' && P.reviveTarget) {
    const t = P.reviveTarget; if (t.state === 'down' || t.state === 'alive') {
      const was = healUnit(t, P, 50); award(was ? 75 : 25, was ? `Поднят ${t.name}` : `Вылечен ${t.name}`); if (was) G.stats.revives++;
    }
    P.reviveTarget = null;
  }
  P.action = null;
}

// ---------- interaction context ----------
export function interactInfo() {
  const P = G.player; if (!P || P.state !== 'alive') return null;
  if (G.mode !== 'foot') return { kind: 'exit', label: G.mode === 'drone' ? 'Выйти из дрона' : 'Выйти' };
  let best = null, bd = 6.5;
  for (const t of G.tanks) if (t.team === ALLY && t.state === 'alive') { const d = t.pos.distanceTo(P.pos) - t.T.l * 0.35; if (d < bd) { bd = d; best = { kind: 'tank', obj: t, label: `Сесть: ${t.T.name}` }; } }
  for (const a of G.aas) if (a.team === ALLY && a.alive) { const d = a.pos.distanceTo(P.pos); if (d < 4 && d < bd + 1) { bd = d; best = { kind: 'aa', obj: a, label: 'Занять ПВО ЗУ-23-2' }; } }
  for (const u of G.units) if (u.team === ALLY && u !== P && (u.state === 'down' || (u.state === 'alive' && u.hp < u.maxHp * 0.7)) && !u.inVehicle) {
    const d = u.pos.distanceTo(P.pos); if (d < 2.2 && (P.perks.medic || P.bandages > 0 || u.state === 'down')) { best = { kind: 'revive', obj: u, label: u.state === 'down' ? `Поднять ${u.name}` : `Перевязать ${u.name}` }; break; }
  }
  const b = BASES[ALLY];
  if (!best && Math.hypot(P.pos.x - b.shop.x, P.pos.z - b.shop.z) < 7) best = { kind: 'shop', label: 'Склад — купить снаряжение' };
  return best;
}

export function doInteract() {
  const P = G.player; const info = interactInfo(); if (!info) return;
  if (info.kind === 'exit') { if (G.mode === 'drone') endDrone(true); else exitVehicle(); return; }
  if (info.kind === 'tank') enterTank(info.obj);
  else if (info.kind === 'aa') enterAA(info.obj);
  else if (info.kind === 'shop') ui.openShop();
  else if (info.kind === 'revive') {
    if (P.actionT > 0) return;
    const t = info.obj;
    if (!P.perks.medic && t.state !== 'down') { if (P.bandages <= 0) return; P.bandages--; }
    P.action = 'revive'; P.reviveTarget = t; P.actionT = P.perks.medic ? 2 : 3.5; SFX.bandage();
    ui.notice(t.state === 'down' ? `Поднимаю ${t.name}...` : `Перевязываю ${t.name}...`);
  }
}

function enterTank(t) {
  const P = G.player;
  G.mode = 'tank'; G.vehicle = t; t.driver = 'player'; t.playerCtrl = true; P.inVehicle = t;
  P.camYaw = t.turretYaw; P.camPitch = t.gunPitch;
  if (vmCur) vmCur.visible = false;
  ui.setMode('tank'); ui.message(`🛡 ${t.T.name} — вы за рычагами`, 2);
  SFX.reloadSound(0.5, 'rocket');
}
function enterAA(a) {
  const P = G.player;
  G.mode = 'aa'; G.vehicle = a; a.operator = 'player'; a.playerCtrl = true; P.inVehicle = a;
  P.camYaw = a.yaw; P.camPitch = a.pitch;
  if (vmCur) vmCur.visible = false;
  ui.setMode('aa'); ui.message('🎯 ПВО ЗУ-23-2 — сбивайте дроны!', 2);
}
export function exitVehicle(forced = false) {
  const P = G.player; const v = G.vehicle; if (!v) return;
  if (v.kind === 'tank') {
    v.playerCtrl = false; v.driver = v.parked ? null : 'ai'; v.speed = 0;
    if (!forced) {
      const s = Math.cos(v.yaw), c = Math.sin(v.yaw);
      P.pos.set(v.pos.x + s * (v.T.w / 2 + 1.2), 0, v.pos.z - c * (v.T.w / 2 + 1.2)); P.pos.y = heightAt(P.pos.x, P.pos.z);
    }
  } else if (v.kind === 'aa') {
    v.playerCtrl = false; v.operator = 'ai';
    if (!forced) { P.pos.set(v.pos.x + Math.sin(v.yaw) * 3, 0, v.pos.z + Math.cos(v.yaw) * 3); P.pos.y = heightAt(P.pos.x, P.pos.z); }
  }
  SFX.servo(false);
  P.inVehicle = null; G.vehicle = null; G.mode = 'foot';
  if (vmCur) vmCur.visible = true;
  ui.setMode('foot');
}

export function startDrone(type) {
  const P = G.player; if (G.mode !== 'foot' || P.state !== 'alive') return;
  if (type === 'fpv' && P.fpv <= 0) { SFX.denied(); ui.notice('Нет FPV-дронов (склад)'); return; }
  if (type === 'bomber' && P.bombers <= 0) { SFX.denied(); ui.notice('Нет дронов-бомберов (склад)'); return; }
  if (type === 'fpv') P.fpv--; else P.bombers--;
  const dr = launchDrone(ALLY, type, _v.set(P.pos.x, P.pos.y + 0.5, P.pos.z), P, true);
  dr.yaw = P.camYaw; dr.vel.set(-Math.sin(P.camYaw) * 3, 4, -Math.cos(P.camYaw) * 3);
  G.mode = 'drone'; G.vehicle = dr; P.crouch = true; P.droneRoll = 0;
  P.savedYaw = P.camYaw; P.savedPitch = P.camPitch; P.camPitch = -0.25;
  if (vmCur) vmCur.visible = false;
  P.model.visible = true;
  ui.setMode('drone'); ui.droneStatic(0.6);
  ui.message(type === 'fpv' ? '🛸 FPV-камикадзе: огонь = подрыв' : '🛸 Бомбер: огонь = сброс', 2.2);
  SFX.radioBeep();
}

export function endDrone(manual = false) {
  const P = G.player; const dr = G.vehicle;
  if (G.mode !== 'drone') return;
  if (manual && dr && dr.alive) {
    if (dr.type === 'bomber' && dr.bombs >= 0) { dr.controller = 'ai'; dr.playerCtrl = false; dr.state = 'return'; ui.notice('Бомбер возвращается на базу'); }
    else { dr.controller = 'ai'; dr.playerCtrl = false; dr.state = 'cruise'; ui.notice('FPV переведён в автономный режим'); }
  }
  G.mode = 'foot'; G.vehicle = null;
  P.camYaw = P.savedYaw ?? P.camYaw; P.camPitch = P.savedPitch ?? 0; P.crouch = false;
  P.model.visible = false;
  SFX.fpvBuzz(false); SFX.radioStatic(0);
  if (P.state === 'alive' && vmCur) vmCur.visible = true;
  ui.setMode('foot');
}

// ---------- main update ----------
export function updatePlayer(dt) {
  const P = G.player; if (!P) return;
  // look
  const sens = G.settings.sens * (vmState.ads > 0.5 && G.mode === 'foot' ? 1 / W().zoom : 1) * (G.mode === 'aa' && input.aim ? 0.4 : 1) * (G.mode === 'tank' && input.aim ? 0.4 : 1);
  P.camYaw -= input.lookX * 0.0042 * sens; P.camPitch -= input.lookY * 0.0042 * sens;
  input.lookX = 0; input.lookY = 0;
  // recoil recovery
  const rec = Math.min(1, dt * 10);
  P.camPitch += P.recoilP * rec; P.camYaw += P.recoilY * rec; P.recoilP *= 1 - rec; P.recoilY *= 1 - rec;
  P.heat = Math.max(0, (P.heat || 0) - dt * 3);
  P.camPitch = clamp(P.camPitch, -1.45, 1.45);

  if (P.state === 'alive' && P.perks.regen && P.hp < P.maxHp && G.time - P.lastHitT > 6) P.hp = Math.min(P.maxHp, P.hp + P.perks.regen * dt);
  if (P.state === 'alive' && P.armor.maxVest && G.mode === 'foot') void 0;

  if (G.mode === 'foot') footUpdate(dt);
  else if (G.mode === 'tank') tankUpdate(dt);
  else if (G.mode === 'aa') aaUpdate(dt);
  else if (G.mode === 'drone') droneUpdate(dt);

  // interaction button
  if (input.take('act')) doInteract();
  if (input.take('shop')) ui.openShop();
  updateCamera(dt);
}

function footUpdate(dt) {
  const P = G.player; const w = W();
  if (P.state === 'down') { P.vel.set(0, 0, 0); P.yaw = P.camYaw; return; }
  if (P.state !== 'alive') return;
  if (P.actionT > 0) { P.actionT -= dt; if (P.actionT <= 0) finishAction(); }
  if (P.action === 'revive' && P.reviveTarget && P.reviveTarget.pos.distanceTo(P.pos) > 3) { P.action = null; P.actionT = 0; ui.notice('Прервано'); }
  if (input.take('crouch')) P.crouch = !P.crouch;
  if (input.take('reload')) startReload();
  if (input.take('switch')) switchWeapon(1);
  for (let i = 0; i < 4; i++) if (input.take('w' + i) && i < P.owned.length) switchWeapon(0, i);
  if (input.take('grenade')) throwPlayerGrenade();
  if (input.take('heal')) useMedical();
  if (input.take('drone')) ui.droneMenu();
  // movement
  const leg = legFactor(P);
  const heavy = P.armor.heavy ? 0.85 : 1;
  const sprint = (input.sprint || input.my < -0.92) && !P.crouch && vmState.ads < 0.3 && P.reloadT <= 0 && input.my < -0.3;
  const speed = (sprint ? 6.6 : P.crouch ? 2.2 : 4.3) * leg * heavy * (vmState.ads > 0.5 ? 0.6 : 1) * (P.actionT > 0 ? 0.4 : 1);
  P.sprinting = sprint;
  const cy = Math.cos(P.camYaw), sy = Math.sin(P.camYaw);
  let mx = input.mx, my = input.my; const ml = Math.hypot(mx, my); if (ml > 1) { mx /= ml; my /= ml; }
  const wx = (-sy * -my + cy * mx) * speed, wz = (-cy * -my - sy * mx) * speed;
  const grounded = P.pos.y <= groundAt(P.pos.x, P.pos.z, P.pos.y) + 0.05;
  const acc = grounded ? 10 : 2;
  P.vel.x = damp(P.vel.x, wx, acc, dt); P.vel.z = damp(P.vel.z, wz, acc, dt);
  if (input.take('jump') && grounded && !P.crouch) { P.vy = 4.6; }
  P.vy -= 14 * dt;
  P.pos.x += P.vel.x * dt; P.pos.z += P.vel.z * dt; P.pos.y += P.vy * dt;
  pushOut(P.pos, 0.35, P.pos.y, P.crouch ? 1.1 : 1.7);
  const g = groundAt(P.pos.x, P.pos.z, P.pos.y);
  if (P.pos.y <= g) {
    if (P.vy < -12) { const dmg = (-P.vy - 12) * 12; ui.notice('Неудачное падение!'); P.hp -= dmg; P.wounds.push({ part: 'legL', sev: dmg, t: G.time }); }
    if (P.vy < -3) SFX.jumpLand();
    P.pos.y = g; P.vy = 0;
  }
  P.yaw = P.camYaw; P.pitch = P.camPitch;
  // footsteps & breathing
  const sp = Math.hypot(P.vel.x, P.vel.z);
  if (grounded) {
    P.stepDist += sp * dt;
    const stride = sprint ? 2.0 : P.crouch ? 1.2 : 1.65;
    if (P.stepDist > stride) { P.stepDist = 0; if (!(P.perks.quiet && !sprint)) SFX.footstep(null, true, sprint); else SFX.footstep(null, true, false); if (Math.random() < 0.3) FX.splash(P.pos); }
  }
  if (sprint) SFX.breath(true);
  if (P.hp < P.maxHp * 0.35) { SFX.heartbeat(P.hp < P.maxHp * 0.15 ? 120 : 85); SFX.breath(true); }
  // aim & fire
  const wantAds = input.aim && P.reloadT <= 0 && !sprint;
  vmState.ads = damp(vmState.ads, wantAds ? 1 : 0, 14, dt);
  vmState.sprint = damp(vmState.sprint, sprint ? 1 : 0, 8, dt);
  playerFire(dt);
  // spot enemies under crosshair
  if (Math.random() < 0.2) {
    G.camera.getWorldDirection(fwd);
    const h = raycastAll(G.camera.position, fwd, 150, P, { coarse: true });
    if (h && h.type === 'unit' && h.u.team === ENEMY) markSpotted(h.u);
  }
}

function tankUpdate(dt) {
  const P = G.player; const t = G.vehicle;
  if (!t || t.state !== 'alive') { exitVehicle(true); return; }
  const thr = -input.my, steer = input.mx;
  driveTank(t, dt, Math.abs(thr) < 0.1 ? 0 : thr, Math.abs(steer) < 0.1 ? 0 : steer);
  P.pos.copy(t.pos);
  const dy = angDiff(t.turretYaw, P.camYaw);
  const step = t.T.turretRate * dt;
  t.turretYaw += clamp(dy, -step, step);
  SFX.servo(Math.abs(dy) > 0.02);
  t.gunPitch = damp(t.gunPitch, clamp(P.camPitch, -0.15, 0.35), 4, dt);
  P.camPitch = clamp(P.camPitch, -0.35, 0.5);
  const auto = t.T.gun === 'autocannon';
  if ((auto ? input.fire : input.take('fire')) && t.reloadT <= 0) fireTankGun(t, 0.002);
  if (input.mg) tankMG(t, dt, 0.012);
  if (input.take('view')) G.tankView = G.tankView === 'third' ? 'first' : 'third';
  if (input.take('repair') && P.perks.repair && t.hp < t.maxHp) { t.hp = Math.min(t.maxHp, t.hp + 300); ui.notice('Ремонт +300'); SFX.reloadSound(1, 'mag'); }
  // resupply & repair at base
  const b = BASES[ALLY];
  if (Math.hypot(t.pos.x - b.x, t.pos.z - b.z) < 30) { if (t.shells < 40) t.shells = 40; t.hp = Math.min(t.maxHp, t.hp + dt * 40); }
}

function aaUpdate(dt) {
  const P = G.player; const a = G.vehicle;
  if (!a || !a.alive) { exitVehicle(true); return; }
  P.camPitch = clamp(P.camPitch, -0.08, 1.4);
  const dy = angDiff(a.yaw, P.camYaw);
  a.yaw += clamp(dy, -3 * dt, 3 * dt); a.pitch = damp(a.pitch, P.camPitch, 12, dt);
  SFX.servo(Math.abs(dy) > 0.03);
  poseAA(a);
  a.cd -= dt;
  if (input.fire && a.cd <= 0) { fireAA(a); a.cd = 0.075; G.shake = Math.max(G.shake, 0.12); P.recoilP += 0.004; P.recoilY += rand(-0.003, 0.003); }
  P.pos.copy(a.pos);
}

function droneUpdate(dt) {
  const P = G.player; const dr = G.vehicle;
  if (!dr || !dr.alive) return;
  if (input.take('droneMode')) { G.droneMode = G.droneMode === 'sport' ? 'stab' : 'sport'; ui.notice(G.droneMode === 'sport' ? 'Режим: СПОРТ (FPV)' : 'Режим: СТАБИЛИЗАЦИЯ'); }
  P.camPitch = clamp(P.camPitch, -1.5, 0.4);
  controlDrone(dr, dt, input, P);
  if (P.state !== 'alive') { endDrone(); }
  if (G.time - P.lastHitT < 0.3) ui.notice('⚠ Ваш оператор под огнём!');
}

// ---------- camera ----------
const camQ = new THREE.Quaternion(), eul = new THREE.Euler(0, 0, 0, 'YXZ');
function updateCamera(dt) {
  const P = G.player; const cam = G.camera;
  let fov = G.baseFov;
  const shake = G.shake; G.shake = Math.max(0, G.shake - dt * 2.2);
  const sx = (Math.random() - 0.5) * shake * 0.03, sy = (Math.random() - 0.5) * shake * 0.03;
  if (G.mode === 'foot') {
    const crouchH = P.state === 'down' ? 0.35 : P.crouch ? 1.12 : 1.62;
    P.eyeH = damp(P.eyeH || 1.62, crouchH, 10, dt);
    const sp = Math.hypot(P.vel.x, P.vel.z);
    vmState.bob += sp * dt * (P.sprinting ? 1.5 : 1.9);
    const bob = Math.sin(vmState.bob * 2) * 0.035 * Math.min(1, sp / 4);
    cam.position.set(P.pos.x, P.pos.y + P.eyeH + bob, P.pos.z);
    const roll = P.state === 'down' ? 0.5 : -input.mx * 0.015 + Math.sin(vmState.bob) * 0.004 * sp;
    eul.set(P.camPitch + sy, P.camYaw + sx, roll);
    const w = W();
    fov = G.baseFov / (1 + (w.zoom - 1) * vmState.ads);
    if (P.sprinting) fov *= 1.05;
  } else if (G.mode === 'tank') {
    const t = G.vehicle;
    if (G.tankView === 'third') {
      const d = 13; cam.position.set(t.pos.x + Math.sin(P.camYaw) * d * Math.cos(P.camPitch), t.pos.y + 5 - P.camPitch * 6, t.pos.z + Math.cos(P.camYaw) * d * Math.cos(P.camPitch));
      eul.set(P.camPitch - 0.18 + sy, P.camYaw + sx, 0);
    } else {
      const e = _v.copy(t.model.eye); t.model.turret.localToWorld(e);
      cam.position.copy(e);
      eul.set(P.camPitch + sy, P.camYaw + sx, 0);
    }
    if (input.aim) fov = G.baseFov / 3.2;
  } else if (G.mode === 'aa') {
    const a = G.vehicle; const e = _v.set(0, 1.75, 0.75); a.model.yawG.localToWorld(e);
    cam.position.copy(e);
    eul.set(P.camPitch + sy, P.camYaw + sx, 0);
    if (input.aim) fov = G.baseFov / 2.5;
  } else if (G.mode === 'drone') {
    const dr = G.vehicle;
    if (dr && dr.alive) {
      cam.position.copy(dr.pos); cam.position.y -= 0.05;
      const sport = G.droneMode === 'sport';
      eul.set(P.camPitch + (sport ? -dr.tiltX * 0.8 : 0) + sy, P.camYaw + sx, (P.droneRoll || 0) + (sport ? dr.tiltZ * 0.6 : 0));
    }
    fov = G.baseFov * 1.08;
  }
  cam.quaternion.setFromEuler(eul);
  if (Math.abs(cam.fov - fov) > 0.05) { cam.fov = damp(cam.fov, fov, 16, dt); cam.updateProjectionMatrix(); FX.setParticleScale(G.renderer.domElement.height, cam.fov); }
  cam.getWorldDirection(fwd);
  SFX.setListener(cam.position, fwd, up.set(0, 1, 0));
  updateViewModel(dt);
}

function updateViewModel(dt) {
  const P = G.player;
  const show = G.mode === 'foot' && P.state === 'alive';
  if (!vmCur) return;
  if (!show) { vmCur.visible = false; muzzleSprite.visible = false; ui.scope(false); return; }
  if (P.action !== 'throw') vmCur.visible = true;
  const w = W(); const ads = vmState.ads;
  vmState.kick = damp(vmState.kick, 0, 12, dt);
  vmState.switchT = Math.max(0, vmState.switchT - dt);
  vmState.swayX = damp(vmState.swayX, clamp(-input.lookXRaw * 0.0006, -0.05, 0.05), 8, dt);
  vmState.swayY = damp(vmState.swayY, clamp(input.lookYRaw * 0.0006, -0.05, 0.05), 8, dt);
  input.lookXRaw = 0; input.lookYRaw = 0;
  const sp = Math.hypot(P.vel.x, P.vel.z);
  const bobX = Math.sin(vmState.bob) * 0.012 * Math.min(1, sp / 4) * (1 - ads * 0.85), bobY = Math.abs(Math.cos(vmState.bob)) * 0.012 * Math.min(1, sp / 4) * (1 - ads * 0.85);
  const sightY = vmCur.userData.sightY;
  const VS = 0.7; vmCur.scale.setScalar(VS);
  const hip = [0.12, -0.15, -0.42], adsP = [0, -sightY * VS, -0.3];
  const scoped = !!w.scope && ads > 0.85;
  let x = hip[0] + (adsP[0] - hip[0]) * ads, y = hip[1] + (adsP[1] - hip[1]) * ads, z = hip[2] + (adsP[2] - hip[2]) * ads;
  // reload animation
  let rx = 0, rz = 0;
  if (P.reloadT > 0) { const t = 1 - P.reloadT / w.reload; const k = Math.sin(t * Math.PI); y -= k * 0.12; rx = -k * 0.5; rz = k * 0.6; vmCur.userData.handL.position.y = -0.035 - Math.sin(t * Math.PI * 2) * 0.05 * k; }
  else vmCur.userData.handL.position.y = -0.035;
  if (P.actionT > 0 && (P.action === 'bandage' || P.action === 'medkit' || P.action === 'revive')) { y -= 0.25; rx = -0.6; }
  const sw = vmState.switchT / 0.45; y -= sw * 0.25; rx -= sw * 0.6;
  const spr = vmState.sprint; x += spr * 0.05; y -= spr * 0.06; rz += spr * 0.5; rx += spr * -0.25;
  const kick = vmState.kick;
  vmCur.position.set(x + bobX + vmState.swayX, y + bobY + vmState.swayY - kick * 0.008, z + kick * (w.kind === 'pistol' ? 0.05 : 0.07));
  vmCur.rotation.set(rx + kick * 0.09, vmState.swayX * 2, rz);
  vmCur.visible = !scoped && P.action !== 'throw';
  ui.scope(scoped);
  // grenade throw anim
  if (P.action === 'throw') {
    const t = 1 - P.actionT / 0.75; VM.grenade.visible = true;
    VM.grenade.position.set(0.15 - t * 0.1, -0.15 + Math.sin(t * Math.PI) * 0.15, -0.35 - t * 0.2);
  }
  // muzzle flash sprite
  vmState.flash -= dt;
  if (vmState.flash > 0 && !scoped) { const m = vmCur.userData.muzzle; m.getWorldPosition(muzzleSprite.position); muzzleSprite.visible = true; muzzleSprite.material.rotation = rand(0, 6); muzzleSprite.scale.setScalar(rand(0.18, 0.32) * (w.kind === 'mg' ? 1.3 : 1)); }
  else muzzleSprite.visible = false;
}

export function playerGunDir() { return G.mode === 'tank' && G.vehicle ? gunDir(G.vehicle, new THREE.Vector3()) : null; }
export { leadPoint, killUnit };
