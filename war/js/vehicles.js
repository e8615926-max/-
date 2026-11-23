// Tanks, AA guns (ПВО), drones — AI and player control
import * as THREE from '../lib/three.module.min.js';
import { G, ALLY, ENEMY, rand, randi, pick, clamp, angDiff, damp } from './state.js';
import { heightAt, pushOut, losClear, BASES, MAP, rayWorld, world } from './world.js';
import { makeTank, makeAA, makeDrone, TANK_TYPES, MAT } from './models.js';
import { COINS } from './data.js';
import * as FX from './effects.js';
import * as SFX from './audio.js';
import { fireBullet, spawnProjectile, explode, damageUnit, killUnit, award, byPlayer, srcName, srcTeam } from './combat.js';
import { ui } from './ui.js';
import { teamEvent } from './units.js';

const _v = new THREE.Vector3(), _a = new THREE.Vector3(), _b = new THREE.Vector3(), _d = new THREE.Vector3(), _q = new THREE.Vector3();
const respawnQ = [];
export const dynFires = [];

// ======================= TANKS =======================
export function spawnTank(team, type, pos, yaw, parked = false) {
  const T = TANK_TYPES[type]; const m = makeTank(type, team);
  G.scene.add(m.root);
  const tk = {
    kind: 'tank', id: G.nextId++, team, type, T, name: T.name, pos: pos.clone(), yaw, speed: 0, turretYaw: yaw, gunPitch: 0,
    hp: T.hp, maxHp: T.hp, reloadT: 1, mgCd: 0, burst: 0, model: m, driver: parked ? null : 'ai', state: 'alive', target: null, thinkT: rand(0, 0.5),
    goal: pos.clone(), stuckT: 0, revT: 0, inv: new THREE.Matrix4(), box: { minX: -T.w / 2, maxX: T.w / 2, minY: 0.1, maxY: 0.55 + T.h + 1.1, minZ: -T.l / 2, maxZ: T.l / 2 },
    engine: SFX.makeLoop('tank'), shells: 40, playerCtrl: false, wreckT: 0, kick: 0, canSee: false, parked,
    weaponName() { return this.T.name; },
  };
  placeTank(tk);
  G.tanks.push(tk);
  return tk;
}

function placeTank(tk) {
  const T = tk.T, r = tk.model.root, p = tk.pos;
  const c = Math.cos(tk.yaw), s = Math.sin(tk.yaw);
  const fx = -s * T.l * 0.4, fz = -c * T.l * 0.4, rx = c * T.w * 0.4, rz = -s * T.w * 0.4;
  const hF = heightAt(p.x + fx, p.z + fz), hB = heightAt(p.x - fx, p.z - fz), hL = heightAt(p.x - rx, p.z - rz), hR = heightAt(p.x + rx, p.z + rz);
  p.y = (hF + hB + hL + hR) / 4;
  r.position.copy(p); r.rotation.order = 'YXZ';
  r.rotation.set(Math.atan2(hF - hB, T.l * 0.8) + tk.kick * 0.05, tk.yaw, Math.atan2(hL - hR, T.w * 0.8));
  tk.model.turret.rotation.y = tk.turretYaw - tk.yaw;
  tk.model.gunPivot.rotation.x = tk.gunPitch;
  r.updateMatrixWorld(true);
  tk.inv.copy(r.matrixWorld).invert();
}

export function gunDir(tk, out) {
  return out.set(0, 0, -1).applyQuaternion(tk.model.gunPivot.getWorldQuaternion(new THREE.Quaternion()));
}

export function damageTank(tk, dmg, src) {
  if (tk.state !== 'alive' || dmg <= 0) return;
  if (src && src.team === tk.team) dmg *= 0.2;
  tk.hp -= dmg;
  if (byPlayer(src) && dmg > 5) ui.hit(tk.hp <= 0, false, true);
  if (tk.playerCtrl) { ui.damaged(dmg * 0.2, null, true); G.shake = Math.max(G.shake, Math.min(1.2, dmg / 200)); SFX.armorHit(); if (src && src.pos) ui.damageFrom(src.pos); }
  if (!tk.playerCtrl && src && src.pos && tk.driver === 'ai' && (!tk.target || Math.random() < 0.5) && src.team !== tk.team) tk.target = src;
  if (tk.hp <= 0) destroyTank(tk, src);
}

function destroyTank(tk, src) {
  tk.state = 'dead'; tk.hp = 0; tk.wreckT = 0;
  const p = _v.copy(tk.pos); p.y += 1.5;
  explode(p.clone(), 9, 130, src, { size: 2.2, tankDmg: 60 });
  setTimeout(() => SFX.explosion(tk.pos, 1.4), 350); // ammo cook-off
  // turret toss
  const tur = tk.model.turret; const wp = new THREE.Vector3(); tur.getWorldPosition(wp);
  const wq = new THREE.Quaternion(); tur.getWorldQuaternion(wq);
  tk.model.hull.remove(tur); G.scene.add(tur); tur.position.copy(wp); tur.quaternion.copy(wq);
  tk.flyTurret = { obj: tur, vel: new THREE.Vector3(rand(-3, 3), rand(9, 14), rand(-3, 3)), spin: new THREE.Vector3(rand(-3, 3), rand(-4, 4), rand(-3, 3)), done: false };
  tk.model.root.traverse(o => { if (o.isMesh) o.material = MAT.burnt; });
  tur.traverse(o => { if (o.isMesh) o.material = MAT.burnt; });
  dynFires.push({ x: tk.pos.x, y: tk.pos.y + 1.6, z: tk.pos.z, size: 1.6, t: 45 });
  if (tk.engine) { tk.engine.stop(); tk.engine = null; }
  if (tk.playerCtrl && G.player) { const P = G.player; exitVehicleForce(); killUnit(P, src, 'explosion', false); }
  if (byPlayer(src) && src.team !== tk.team) { G.stats.tanks++; award(COINS.tank, `${tk.T.name} уничтожен`); }
  ui.killfeed(srcName(src), srcTeam(src), tk.T.name, tk.team, '💥', false);
  G.teams[tk.team].tickets = Math.max(0, G.teams[tk.team].tickets - 5);
  G.teams[tk.team].morale = clamp(G.teams[tk.team].morale - 5, 5, 100);
  respawnQ.push({ what: 'tank', team: tk.team, type: tk.type, t: 50, parked: tk.parked });
}

function tankThink(tk) {
  const T = tk.T;
  // targets
  let best = null, bs = 1e9;
  _a.set(tk.pos.x, tk.pos.y + 2.4, tk.pos.z);
  const consider = (e, score) => { if (score < bs) { _b.copy(e.pos); _b.y += e.kind === 'tank' ? 1.4 : e.isUnit ? 1.2 : 1; if (losClear(_a, _b)) { bs = score; best = e; } } };
  for (const e of G.tanks) if (e.team !== tk.team && e.state === 'alive') { const d = e.pos.distanceTo(tk.pos); if (d < 180) consider(e, d * 0.5); }
  for (const e of G.aas) if (e.team !== tk.team && e.alive) { const d = e.pos.distanceTo(tk.pos); if (d < 150) consider(e, d * 0.8); }
  for (const e of G.units) if (e.team !== tk.team && e.state === 'alive' && !e.inVehicle) { const d = e.pos.distanceTo(tk.pos); if (d < 120) consider(e, d * (e.isPlayer ? 0.9 : 1)); }
  tk.target = best; tk.canSee = !!best;
  if (best && best.kind === 'tank' && best.team === ENEMY && tk.team === ALLY) teamEvent(ALLY, 'tank');
  // goal: nearest flag not owned, else hold near own front flag
  const b = BASES[tk.team];
  const flags = [...G.flags].sort((f1, f2) => Math.abs(f1.z - b.z) - Math.abs(f2.z - b.z));
  const f = flags.find(fl => fl.owner !== tk.team) || flags[flags.length - 1];
  const side = tk.id % 2 ? 1 : -1;
  tk.goal.set(f.x + side * 16, 0, f.z - b.dir * 14);
}

function updateTankAI(tk, dt) {
  const T = tk.T;
  tk.thinkT -= dt; if (tk.thinkT <= 0) { tk.thinkT = 0.5; tankThink(tk); }
  // drive
  const dx = tk.goal.x - tk.pos.x, dz = tk.goal.z - tk.pos.z; const dist = Math.hypot(dx, dz);
  let throttle = 0, steer = 0;
  const hold = tk.target && tk.target.kind === 'tank' && tk.pos.distanceTo(tk.target.pos) < 110;
  if (tk.revT > 0) { tk.revT -= dt; throttle = -0.6; steer = tk.revSteer; }
  else if (dist > 7 && !hold) {
    const want = Math.atan2(-dx, -dz); const da = angDiff(tk.yaw, want);
    steer = clamp(-da * 2, -1, 1); throttle = Math.abs(da) > 0.9 ? 0.15 : clamp(dist / 20, 0.3, 1);
  }
  driveTank(tk, dt, throttle, steer);
  if (Math.abs(throttle) > 0.2 && Math.abs(tk.speed) < 0.4) { tk.stuckT += dt; if (tk.stuckT > 2) { tk.revT = 2.2; tk.revSteer = pick([-1, 1]); tk.stuckT = 0; } } else tk.stuckT = 0;
  // turret
  const t = tk.target;
  if (t && (t.isUnit ? t.state === 'alive' && !t.inVehicle : t.kind === 'tank' ? t.state === 'alive' : t.alive)) {
    const mz = tk.model.muzzle.getWorldPosition(_a);
    _b.copy(t.pos); _b.y += t.kind === 'tank' ? 1.3 : t.isUnit ? 1.0 : 1.2;
    const hd = Math.hypot(_b.x - mz.x, _b.z - mz.z);
    const wantY = Math.atan2(-(_b.x - tk.pos.x), -(_b.z - tk.pos.z));
    const flight = hd / 220; const drop = 0.5 * 3 * flight * flight;
    const wantP = Math.atan2(_b.y - mz.y + drop, hd);
    const dy = angDiff(tk.turretYaw, wantY);
    tk.turretYaw += clamp(dy, -T.turretRate * dt, T.turretRate * dt);
    tk.gunPitch = damp(tk.gunPitch, clamp(wantP, -0.15, 0.35), 3, dt);
    if (Math.abs(dy) < 0.05 && tk.canSee) {
      const infantry = t.isUnit;
      if (infantry && T.mg) tankMG(tk, dt, 0.035);
      if (tk.reloadT <= 0 && (!infantry || Math.random() < 0.25 || T.gun === 'autocannon')) fireTankGun(tk, 0.009);
    }
  } else {
    const dy = angDiff(tk.turretYaw, tk.yaw); tk.turretYaw += clamp(dy, -T.turretRate * dt * 0.5, T.turretRate * dt * 0.5);
    tk.gunPitch = damp(tk.gunPitch, 0, 2, dt);
  }
}

export function driveTank(tk, dt, throttle, steer) {
  const T = tk.T;
  const target = throttle * (throttle < 0 ? T.speed * 0.45 : T.speed);
  tk.speed = damp(tk.speed, target, throttle === 0 ? 1.6 : 0.9, dt);
  tk.yaw -= steer * T.turn * dt * (0.6 + 0.4 * Math.min(1, Math.abs(tk.speed) / 3));
  const ox = tk.pos.x, oz = tk.pos.z;
  tk.pos.x += -Math.sin(tk.yaw) * tk.speed * dt; tk.pos.z += -Math.cos(tk.yaw) * tk.speed * dt;
  const r = T.w * 0.62;
  // two circles along the hull
  const fx = -Math.sin(tk.yaw) * T.l * 0.28, fz = -Math.cos(tk.yaw) * T.l * 0.28;
  _q.set(tk.pos.x + fx, tk.pos.y, tk.pos.z + fz); const h1 = pushOut(_q, r, tk.pos.y + 0.4, 2);
  tk.pos.x = _q.x - fx; tk.pos.z = _q.z - fz;
  _q.set(tk.pos.x - fx, tk.pos.y, tk.pos.z - fz); const h2 = pushOut(_q, r, tk.pos.y + 0.4, 2);
  tk.pos.x = _q.x + fx; tk.pos.z = _q.z + fz;
  // other tanks
  for (const o of G.tanks) { if (o === tk || o.state === 'gone') continue; const dx = tk.pos.x - o.pos.x, dz = tk.pos.z - o.pos.z; const d = Math.hypot(dx, dz); const md = (T.l + o.T.l) * 0.42; if (d < md && d > 0.01) { tk.pos.x += dx / d * (md - d) * 0.5; tk.pos.z += dz / d * (md - d) * 0.5; } }
  if (h1 || h2) tk.speed *= 0.9;
  const moved = Math.hypot(tk.pos.x - ox, tk.pos.z - oz) / Math.max(dt, 1e-4);
  tk.realSpeed = moved;
  // crush infantry
  for (const u of G.units) {
    if (u.inVehicle || u.state === 'gone') continue;
    _v.subVectors(u.pos, tk.pos); _v.y = 0;
    const lx = _v.x * Math.cos(tk.yaw) - _v.z * Math.sin(tk.yaw), lz = _v.x * Math.sin(tk.yaw) + _v.z * Math.cos(tk.yaw);
    if (Math.abs(lx) < T.w / 2 + 0.3 && Math.abs(lz) < T.l / 2 + 0.3) {
      if (moved > 2.5 && u.state !== 'dead' && u.team !== tk.team) damageUnit(u, 400, 'torso', null, _v.normalize(), tk, 'crush');
      else { // push out sideways
        const px = Math.sign(lx || 1) * (T.w / 2 + 0.35 - Math.abs(lx));
        u.pos.x += px * Math.cos(tk.yaw); u.pos.z -= px * Math.sin(tk.yaw);
      }
    }
  }
  if (moved > 3 && Math.random() < dt * 6) { const s = Math.random() < 0.5 ? -1 : 1; FX.dustPuff(_v.set(tk.pos.x + Math.cos(tk.yaw) * s * T.w * 0.4 + Math.sin(tk.yaw) * T.l * 0.45, tk.pos.y, tk.pos.z - Math.sin(tk.yaw) * s * T.w * 0.4 + Math.cos(tk.yaw) * T.l * 0.45), 2, [0.26, 0.22, 0.17]); }
}

export function fireTankGun(tk, err = 0) {
  const T = tk.T;
  const mz = tk.model.muzzle.getWorldPosition(new THREE.Vector3());
  const dir = gunDir(tk, new THREE.Vector3());
  dir.x += rand(-err, err); dir.y += rand(-err, err) * 0.5; dir.z += rand(-err, err); dir.normalize();
  const near = G.camera.position.distanceTo(mz) < 80;
  if (T.gun === 'autocannon') {
    spawnProjectile({ type: 'ac', pos: mz, vel: dir.clone().multiplyScalar(320), src: tk, ignore: tk, grav: 2, life: 2.5 });
    SFX.shot('autocannon', mz, tk.playerCtrl);
    FX.muzzleFlash(mz, dir, 1.6, near);
    tk.burst++;
    tk.reloadT = tk.burst % 5 === 0 && !tk.playerCtrl ? 1.6 : T.reload;
    tk.kick = 0.25;
  } else {
    if (tk.playerCtrl && tk.shells <= 0) { SFX.emptyClick(); ui.notice('Нет снарядов! Вернитесь на базу'); tk.reloadT = 1; return; }
    if (tk.playerCtrl) tk.shells--;
    spawnProjectile({ type: 'shell', pos: mz, vel: dir.clone().multiplyScalar(220), src: tk, ignore: tk, grav: 3, life: 4, radius: 6.5, dmg: 150, tankDmg: tk.type === 'heavy' ? 430 : 380, size: 1.3 });
    SFX.explosion(mz, 0.9); SFX.shot('sniper', mz, tk.playerCtrl);
    FX.muzzleFlash(mz, dir, 5, true);
    for (let i = 0; i < 14; i++) FX.dustPuff(_v.set(mz.x + rand(-3, 3), heightAt(mz.x, mz.z), mz.z + rand(-3, 3)), 1);
    tk.reloadT = T.reload * (tk.playerCtrl && G.player.perks.tankReload ? G.player.perks.tankReload : 1);
    tk.kick = 1;
    if (tk.playerCtrl) G.shake = Math.max(G.shake, 0.6);
  }
}

const mgW = { dmg: 30, range: 250, kind: 'mg' };
export function tankMG(tk, dt, err = 0.02) {
  tk.mgCd -= dt; if (tk.mgCd > 0) return;
  tk.mgCd = 0.09;
  const mz = tk.model.mgMuzzle.getWorldPosition(new THREE.Vector3());
  const dir = gunDir(tk, new THREE.Vector3()); dir.x += rand(-err, err); dir.y += rand(-err, err); dir.z += rand(-err, err); dir.normalize();
  fireBullet(tk, mz, dir, mgW, mz, { ignore: tk, tracer: 0.5 });
  SFX.shot('mg', mz, tk.playerCtrl);
  FX.muzzleFlash(mz, dir, 0.8, false);
}

function updateTankVisual(tk, dt) {
  tk.kick = damp(tk.kick, 0, 5, dt);
  placeTank(tk);
  if (tk.engine) {
    const d = G.camera.position.distanceTo(tk.pos);
    const vol = tk.playerCtrl ? 0.32 : d > 160 ? 0 : 0.9;
    tk.engine.set(tk.pos, 0.3 + Math.min(1, Math.abs(tk.speed) / tk.T.speed) * 0.7, vol, Math.abs(tk.speed));
  }
  if (tk.hp < tk.maxHp * 0.45 && Math.random() < dt * 8) FX.smokeTrail(_v.set(tk.pos.x + Math.sin(tk.yaw) * tk.T.l * 0.35, tk.pos.y + 1.8, tk.pos.z + Math.cos(tk.yaw) * tk.T.l * 0.35), 2);
  if (tk.hp < tk.maxHp * 0.2) FX.fireFx(_v.set(tk.pos.x + Math.sin(tk.yaw) * tk.T.l * 0.35, tk.pos.y + 1.8, tk.pos.z + Math.cos(tk.yaw) * tk.T.l * 0.35), 0.6, dt);
}

// ======================= AA (ПВО) =======================
export function spawnAA(team, pos) {
  const m = makeAA(team); m.root.position.copy(pos); m.root.position.y = heightAt(pos.x, pos.z); G.scene.add(m.root);
  const a = {
    kind: 'aa', id: G.nextId++, team, pos: m.root.position.clone(), yaw: team === ALLY ? 0 : Math.PI, pitch: 0.3, hp: 500, maxHp: 500, model: m, cd: 0, burst: 0,
    alive: true, operator: 'ai', target: null, thinkT: 0, barrel: 0, playerCtrl: false, name: 'ЗУ-23-2', rebuildT: 0, kick: 0,
    weaponName() { return 'ЗУ-23-2'; },
  };
  G.aas.push(a); return a;
}

export function damageAA(a, dmg, src) {
  if (!a.alive || dmg <= 0) return;
  if (src && src.team === a.team) dmg *= 0.2;
  a.hp -= dmg;
  if (a.playerCtrl) { ui.damaged(dmg * 0.3, null, true); SFX.armorHit(); if (src && src.pos) ui.damageFrom(src.pos); }
  if (a.hp <= 0) {
    a.alive = false;
    explode(_v.copy(a.pos).setY(a.pos.y + 1.2).clone(), 6, 90, src, { size: 1.4, tankDmg: 0 });
    a.model.root.traverse(o => { if (o.isMesh) o.material = MAT.burnt; });
    dynFires.push({ x: a.pos.x, y: a.pos.y + 1, z: a.pos.z, size: 1, t: 30 });
    if (a.playerCtrl) { exitVehicleForce(); killUnit(G.player, src, 'explosion', false); }
    if (byPlayer(src) && src.team !== a.team) award(COINS.aa, 'ПВО уничтожено');
    ui.killfeed(srcName(src), srcTeam(src), 'ПВО ЗУ-23', a.team, '💥', false);
    respawnQ.push({ what: 'aa', aa: a, t: 70 });
  }
}

const flakSpeed = 420;
export function leadPoint(from, dr, out) {
  out.copy(dr.pos);
  for (let i = 0; i < 3; i++) { const t = from.distanceTo(out) / flakSpeed; out.copy(dr.pos).addScaledVector(dr.vel, t); out.y += 0.5 * 4 * t * t; }
  return out;
}

export function fireAA(a) {
  const mzObj = a.model.muzzles[a.barrel]; a.barrel ^= 1;
  const mz = mzObj.getWorldPosition(new THREE.Vector3());
  const dir = new THREE.Vector3(0, 0, -1).applyQuaternion(a.model.pitchG.getWorldQuaternion(new THREE.Quaternion()));
  const e = a.playerCtrl ? 0.003 : 0.012;
  dir.x += rand(-e, e); dir.y += rand(-e, e); dir.z += rand(-e, e); dir.normalize();
  const tgtDist = a.target && a.target.pos ? a.target.pos.distanceTo(mz) : 200;
  spawnProjectile({ type: 'flak', pos: mz, vel: dir.clone().multiplyScalar(flakSpeed), src: a, ignore: a, grav: 4, life: a.playerCtrl ? 1.6 : tgtDist / flakSpeed + 0.12 });
  SFX.shot('aa', mz, a.playerCtrl);
  FX.muzzleFlash(mz, dir, 1.8, G.camera.position.distanceTo(mz) < 60);
  FX.casing(mz, _v.set(1, 0, 0));
  a.kick = 1;
}

function updateAA(a, dt) {
  a.kick = damp(a.kick, 0, 12, dt);
  if (!a.alive) return;
  a.model.radar.rotation.y += dt * 2.5;
  if (a.playerCtrl) return;
  a.thinkT -= dt; a.cd -= dt;
  if (a.thinkT <= 0) {
    a.thinkT = 0.25;
    let best = null, bd = 190;
    for (const dr of G.drones) if (dr.alive && dr.team !== a.team) { const d = dr.pos.distanceTo(a.pos); if (d < bd) { bd = d; best = dr; } }
    if (!best) {
      bd = 90; _a.set(a.pos.x, a.pos.y + 1.6, a.pos.z);
      for (const u of G.units) if (u.team !== a.team && u.state === 'alive' && !u.inVehicle) { const d = u.pos.distanceTo(a.pos); if (d < bd) { _b.copy(u.pos); _b.y += 1.2; if (losClear(_a, _b)) { bd = d; best = u; } } }
    }
    a.target = best;
    if (best && best.kind === 'drone' && a.team === ALLY && G.player && best.pos.distanceTo(G.player.pos) < 120) teamEvent(ALLY, 'drone');
  }
  const t = a.target;
  if (t && (t.kind === 'drone' ? t.alive : t.state === 'alive')) {
    const from = a.model.pitchG.getWorldPosition(_a);
    const aim = t.kind === 'drone' ? leadPoint(from, t, _b) : _b.copy(t.pos).setY(t.pos.y + 1.1);
    const wy = Math.atan2(-(aim.x - from.x), -(aim.z - from.z)); const wp = Math.atan2(aim.y - from.y, Math.hypot(aim.x - from.x, aim.z - from.z));
    const dy = angDiff(a.yaw, wy); a.yaw += clamp(dy, -2.4 * dt, 2.4 * dt);
    a.pitch += clamp(wp - a.pitch, -1.8 * dt, 1.8 * dt);
    if (Math.abs(dy) < 0.06 && Math.abs(wp - a.pitch) < 0.06 && a.cd <= 0) {
      if (t.kind === 'drone') { fireAA(a); a.burst++; a.cd = a.burst % 12 === 0 ? 0.7 : 0.075; }
      else { // ground fire (heavy rounds)
        const mz = a.model.muzzles[a.barrel].getWorldPosition(new THREE.Vector3()); a.barrel ^= 1;
        const dir = _d.subVectors(_b, mz).normalize(); dir.x += rand(-0.02, 0.02); dir.y += rand(-0.01, 0.01); dir.normalize();
        fireBullet(a, mz, dir, { dmg: 55, range: 200 }, mz, { ignore: a, tracer: 0.7 }); SFX.shot('aa', mz, false); FX.muzzleFlash(mz, dir, 1.5, false);
        a.burst++; a.cd = a.burst % 6 === 0 ? 1.4 : 0.12;
      }
    }
  } else { a.pitch = damp(a.pitch, 0.5, 0.5, dt); a.yaw += dt * 0.3; }
  poseAA(a);
}
export function poseAA(a) {
  a.model.yawG.rotation.y = a.yaw - (a.team === ALLY ? 0 : 0);
  a.model.pitchG.rotation.x = clamp(a.pitch, -0.1, 1.45);
  a.model.pitchG.position.z = a.kick * 0.06;
}

// ======================= DRONES =======================
export function launchDrone(team, type, from, owner, player = false) {
  const m = makeDrone(type, team);
  const pos = new THREE.Vector3(from.x, from.y + 1.5, from.z);
  m.root.position.copy(pos); G.scene.add(m.root);
  const perkBat = player && G.player.perks.droneBat ? G.player.perks.droneBat : 1;
  const dr = {
    kind: 'drone', id: G.nextId++, type, team, pos, vel: new THREE.Vector3(0, 2, 0), yaw: team === ALLY ? 0 : Math.PI, tiltX: 0, tiltZ: 0,
    hp: type === 'fpv' ? 25 : 50, battery: (type === 'fpv' ? 110 : 170) * perkBat, maxBattery: (type === 'fpv' ? 110 : 170) * perkBat,
    bombs: type === 'bomber' ? 4 : 0, controller: player ? 'player' : 'ai', owner, target: null, state: 'climb', model: m, alive: true,
    loop: SFX.makeLoop('drone'), thinkT: 0, playerCtrl: player, name: type === 'fpv' ? 'FPV-дрон' : 'Дрон-бомбер', dropT: 0, weave: rand(0, 6), thr: 0.5,
    cruise: type === 'fpv' ? rand(20, 28) : rand(28, 36), signal: 1, launchT: G.time,
    weaponName() { return this.name; },
  };
  G.drones.push(dr);
  return dr;
}

export function destroyDrone(dr, src, quiet = false) {
  if (!dr.alive) return;
  dr.alive = false;
  if (!quiet) {
    if (dr.type === 'fpv') explode(dr.pos.clone(), 3.5, 60, dr, { size: 0.6, tankDmg: 60, self: dr });
    else { FX.explosionFx(dr.pos, 0.4); SFX.explosion(dr.pos, 0.4); }
    FX.sparks(dr.pos, 20);
  }
  G.scene.remove(dr.model.root);
  if (dr.loop) { dr.loop.stop(); dr.loop = null; }
  if (src && src !== dr && src.team !== dr.team) {
    if (byPlayer(src)) { G.stats.drones++; award(COINS.drone, `${dr.name} сбит`); }
    ui.killfeed(srcName(src), srcTeam(src), dr.name, dr.team, '✈', false);
  }
  if (dr.playerCtrl) { ui.message(src && src !== dr ? 'Дрон сбит!' : 'Связь с дроном потеряна', 2); setTimeout(() => endDroneControl(), 700); ui.droneStatic(1); }
}

function droneDetonate(dr) {
  if (!dr.alive) return;
  const p = dr.pos.clone();
  dr.alive = false; G.scene.remove(dr.model.root); if (dr.loop) { dr.loop.stop(); dr.loop = null; }
  explode(p, 6, 150, dr, { size: 1.1, tankDmg: 440, self: dr });
  if (dr.playerCtrl) { ui.droneStatic(1); setTimeout(() => endDroneControl(), 900); }
}

function droneTargets(dr) {
  let best = null, bs = 1e9;
  for (const t of G.tanks) if (t.team !== dr.team && t.state === 'alive') { const s = t.pos.distanceTo(dr.pos) * 0.4; if (s < bs) { bs = s; best = t; } }
  for (const a of G.aas) if (a.team !== dr.team && a.alive) { const s = a.pos.distanceTo(dr.pos) * 0.9; if (s < bs) { bs = s; best = a; } }
  for (const u of G.units) if (u.team !== dr.team && u.state === 'alive' && !u.inVehicle && u.role !== 'basemedic') {
    let n = 0; for (const o of G.units) if (o.team === u.team && o.state === 'alive' && o.pos.distanceTo(u.pos) < 7) n++;
    const s = u.pos.distanceTo(dr.pos) / (1 + n * 0.5) * (u.isPlayer ? 0.8 : 1);
    if (s < bs && Math.abs(u.pos.z - BASES[u.team].z) > 30) { bs = s; best = u; }
  }
  return best;
}

function updateDroneAI(dr, dt) {
  dr.thinkT -= dt;
  if (dr.thinkT <= 0) { dr.thinkT = 1; if (dr.state !== 'attack' || !dr.target) dr.target = droneTargets(dr); }
  const t = dr.target; const b = BASES[dr.team];
  const ground = heightAt(dr.pos.x, dr.pos.z);
  let want = _a.set(0, 0, 0); let spd = dr.type === 'fpv' ? 20 : 11;
  dr.weave += dt * 1.7;
  if (dr.state === 'return') {
    want.set(b.x + 24 - dr.pos.x, ground + 20 - dr.pos.y, b.z - dr.pos.z);
    if (Math.hypot(want.x, want.z) < 6) { destroyDrone(dr, null, true); return; }
  } else if (dr.state === 'climb') {
    want.set(0, dr.cruise + ground - dr.pos.y, -b.dir * -3);
    if (dr.pos.y - ground > dr.cruise - 3) dr.state = 'cruise';
  } else if (t && (t.isUnit ? t.state === 'alive' : t.kind === 'tank' ? t.state === 'alive' : t.alive)) {
    _b.copy(t.pos); _b.y += t.kind === 'tank' ? 1.4 : t.isUnit ? 0.8 : 1.2;
    const hd = Math.hypot(_b.x - dr.pos.x, _b.z - dr.pos.z);
    if (dr.type === 'fpv') {
      if (dr.state === 'attack' || hd < 42) {
        dr.state = 'attack'; spd = 30;
        want.subVectors(_b, dr.pos);
        if (want.length() < 2.4) { droneDetonate(dr); return; }
      } else want.set(_b.x - dr.pos.x, ground + dr.cruise - dr.pos.y, _b.z - dr.pos.z);
    } else {
      want.set(_b.x - dr.pos.x, Math.max(heightAt(_b.x, _b.z) + dr.cruise, ground + 15) - dr.pos.y, _b.z - dr.pos.z);
      if (hd < 3.5 && dr.bombs > 0 && G.time > dr.dropT) {
        dr.bombs--; dr.dropT = G.time + 2.6;
        spawnProjectile({ type: 'bomb', pos: _v.copy(dr.pos).setY(dr.pos.y - 0.3), vel: _q.copy(dr.vel).multiplyScalar(0.5), src: dr, ignore: dr, grav: 9.8, life: 8, radius: 6.5, dmg: 140, tankDmg: 240, size: 0.9 });
        SFX.bounce(dr.pos, true);
      }
      if (dr.bombs <= 0) dr.state = 'return';
      if (hd < 5) spd = 3;
    }
  } else {
    // loiter towards the front
    const f = G.flags.find(fl => fl.owner !== dr.team) || G.flags[1];
    want.set(f.x + Math.cos(dr.weave * 0.3) * 30 - dr.pos.x, ground + dr.cruise - dr.pos.y, f.z + Math.sin(dr.weave * 0.3) * 30 - dr.pos.z);
  }
  if (dr.battery < 15 && dr.type === 'bomber' && dr.state !== 'return') dr.state = 'return';
  const l = want.length();
  if (l > 0.01) want.multiplyScalar(Math.min(spd, l * 2) / l);
  // evasive weave
  if (dr.state !== 'attack') { want.x += Math.cos(dr.weave) * 3; want.y += Math.sin(dr.weave * 1.3) * 1.5; }
  dr.vel.x = damp(dr.vel.x, want.x, 1.6, dt); dr.vel.y = damp(dr.vel.y, want.y, 2.5, dt); dr.vel.z = damp(dr.vel.z, want.z, 1.6, dt);
  dr.pos.addScaledVector(dr.vel, dt);
  if (Math.hypot(dr.vel.x, dr.vel.z) > 1) dr.yaw = Math.atan2(-dr.vel.x, -dr.vel.z);
}

// collision & visuals common
function droneCommon(dr, dt) {
  dr.battery -= dt;
  if (dr.battery <= 0 && dr.state !== 'fall') { dr.state = 'fall'; if (dr.playerCtrl) ui.message('Батарея разряжена!', 2); }
  if (dr.state === 'fall') { dr.vel.y -= 9.8 * dt; dr.pos.addScaledVector(dr.vel, dt); }
  const h = heightAt(dr.pos.x, dr.pos.z);
  if (dr.pos.y < h + 0.25) {
    const sp = dr.vel.length();
    if (dr.type === 'fpv' && (sp > 5 || dr.state === 'attack' || dr.state === 'fall')) { droneDetonate(dr); return; }
    if (sp > 6 || dr.state === 'fall') { destroyDrone(dr, null); return; }
    dr.pos.y = h + 0.25; dr.vel.y = Math.max(0, dr.vel.y);
  }
  // obstacles
  const sp = dr.vel.length();
  if (sp > 0.5) {
    _d.copy(dr.vel).divideScalar(sp);
    const hit = rayWorld(dr.pos, _d, sp * dt + 0.35, false);
    if (hit) {
      if (dr.type === 'fpv' && sp > 5) { droneDetonate(dr); return; }
      if (sp > 8) { destroyDrone(dr, null); return; }
      dr.vel.multiplyScalar(-0.3);
    }
  }
  dr.pos.x = clamp(dr.pos.x, MAP.minX - 30, MAP.maxX + 30); dr.pos.z = clamp(dr.pos.z, MAP.minZ - 20, MAP.maxZ + 20); dr.pos.y = Math.min(dr.pos.y, h + 140);
  // visual
  const m = dr.model; m.root.position.copy(dr.pos);
  const fwd = -(dr.vel.x * -Math.sin(dr.yaw) + dr.vel.z * -Math.cos(dr.yaw)), side = dr.vel.x * Math.cos(dr.yaw) - dr.vel.z * Math.sin(dr.yaw);
  dr.tiltX = damp(dr.tiltX, clamp(fwd * 0.025, -0.6, 0.6), 6, dt); dr.tiltZ = damp(dr.tiltZ, clamp(-side * 0.025, -0.6, 0.6), 6, dt);
  m.root.rotation.set(dr.tiltX, dr.yaw, dr.tiltZ, 'YXZ');
  for (const r of m.rotors) r.rotation.z += dt * 60;
  if (dr.loop) {
    const d = G.camera.position.distanceTo(dr.pos);
    dr.thr = clamp(0.4 + sp / 40 + (dr.vel.y > 0 ? 0.2 : 0), 0, 1);
    dr.loop.set(dr.pos, dr.thr, dr.playerCtrl ? 0 : d > 160 ? 0 : 0.7);
  }
}

// ---------- player drone ----------
export function controlDrone(dr, dt, inp, P) {
  if (!dr.alive) return;
  const sport = G.droneMode === 'sport';
  const fpv = dr.type === 'fpv';
  const max = fpv ? (sport ? 40 : 24) * (inp.sprint ? 1.35 : 1) : (sport ? 19 : 13);
  const cy = Math.cos(P.camYaw), sy = Math.sin(P.camYaw);
  // forward along camera yaw (-z rotated)
  const fx = -sy, fz = -cy, rx = cy, rz = -sy;
  const f = -inp.my, s = inp.mx;
  let wx = (fx * f + rx * s) * max, wz = (fz * f + rz * s) * max;
  let wy = (inp.up ? 1 : 0) - (inp.down ? 1 : 0);
  wy *= fpv ? 9 : 6;
  if (sport && fpv) wy += -P.camPitch * f * max * 0.6; // fly where camera points
  if (dr.state === 'fall') { droneCommon(dr, dt); return; }
  const k = sport ? 1.5 : 3.2;
  const ax = (wx - dr.vel.x), az = (wz - dr.vel.z);
  dr.vel.x = damp(dr.vel.x, wx, k, dt); dr.vel.z = damp(dr.vel.z, wz, k, dt); dr.vel.y = damp(dr.vel.y, wy, 3, dt);
  dr.pos.addScaledVector(dr.vel, dt);
  dr.yaw = P.camYaw;
  // camera roll for feel
  const latAcc = ax * rx + az * rz;
  P.droneRoll = damp(P.droneRoll || 0, clamp(-latAcc * (sport ? 0.03 : 0.012), -0.45, 0.45), 5, dt);
  // signal
  const range = 420 * (P.perks.droneRange || 1);
  const dist = dr.pos.distanceTo(P.pos);
  const eb = BASES[1 - dr.team];
  const ew = Math.max(0, 1 - Math.hypot(dr.pos.x - eb.x, dr.pos.z - eb.z) / 75) * 0.9;
  dr.signal = clamp(1 - dist / range - ew + Math.min(0.3, (dr.pos.y - heightAt(dr.pos.x, dr.pos.z)) / 200), -0.2, 1);
  if (dr.signal <= 0) { destroyDrone(dr, null, false); return; }
  // actions
  if (inp.take('fire')) {
    if (fpv) { droneDetonate(dr); return; }
    if (dr.bombs > 0) {
      dr.bombs--;
      spawnProjectile({ type: 'bomb', pos: _v.copy(dr.pos).setY(dr.pos.y - 0.3), vel: _q.copy(dr.vel).multiplyScalar(0.9), src: dr, ignore: dr, grav: 9.8, life: 10, radius: 6.5, dmg: 150, tankDmg: 260, size: 0.9 });
      SFX.bounce(dr.pos, true); ui.notice(`Сброс! Осталось: ${dr.bombs}`);
    } else { SFX.denied(); ui.notice('Боезапас пуст'); }
  }
  droneCommon(dr, dt);
  SFX.fpvBuzz(true, dr.thr);
  SFX.radioStatic(clamp(1 - dr.signal * 1.6, 0, 1));
}

// bomb impact prediction for HUD
export function bombImpact(dr, out) {
  let px = dr.pos.x, py = dr.pos.y - 0.3, pz = dr.pos.z, vx = dr.vel.x * 0.9, vy = dr.vel.y * 0.9, vz = dr.vel.z * 0.9;
  for (let i = 0; i < 400; i++) { vy -= 9.8 * 0.02; px += vx * 0.02; py += vy * 0.02; pz += vz * 0.02; if (py < heightAt(px, pz)) break; }
  return out.set(px, heightAt(px, pz), pz);
}

let endDroneHook = null, exitHook = null;
export function setVehicleHooks(endDrone, exitForce) { endDroneHook = endDrone; exitHook = exitForce; }
function endDroneControl() { if (endDroneHook) endDroneHook(); }
function exitVehicleForce() { if (exitHook) exitHook(); }

// ======================= update all =======================
export function updateVehicles(dt) {
  for (let i = G.tanks.length - 1; i >= 0; i--) {
    const tk = G.tanks[i];
    if (tk.state === 'alive') {
      tk.reloadT -= dt;
      if (tk.driver === 'ai') updateTankAI(tk, dt);
      else if (!tk.playerCtrl) driveTank(tk, dt, 0, 0);
      updateTankVisual(tk, dt);
    } else if (tk.state === 'dead') {
      tk.wreckT += dt;
      const ft = tk.flyTurret;
      if (ft && !ft.done) {
        ft.vel.y -= 9.8 * dt; ft.obj.position.addScaledVector(ft.vel, dt);
        ft.obj.rotation.x += ft.spin.x * dt; ft.obj.rotation.y += ft.spin.y * dt; ft.obj.rotation.z += ft.spin.z * dt;
        const h = heightAt(ft.obj.position.x, ft.obj.position.z);
        if (ft.obj.position.y < h + 0.4) { ft.obj.position.y = h + 0.4; ft.done = true; SFX.explosion(ft.obj.position, 0.3); FX.dustPuff(ft.obj.position, 8); }
      }
      if (tk.wreckT > 100) { tk.state = 'gone'; G.scene.remove(tk.model.root); if (tk.flyTurret) G.scene.remove(tk.flyTurret.obj); G.tanks.splice(i, 1); }
    }
  }
  for (const a of G.aas) updateAA(a, dt);
  for (let i = G.drones.length - 1; i >= 0; i--) {
    const dr = G.drones[i];
    if (!dr.alive) { G.drones.splice(i, 1); continue; }
    if (dr.controller === 'ai') { updateDroneAI(dr, dt); if (dr.alive) droneCommon(dr, dt); }
  }
  for (let i = dynFires.length - 1; i >= 0; i--) { const f = dynFires[i]; f.t -= dt; FX.fireFx(f, f.size, dt); if (f.t < 0) dynFires.splice(i, 1); }
  for (const f of world.fires) FX.fireFx(f, f.size, dt);
  for (const c of world.smokeColumns) FX.smokeColumnFx(c, c.size, dt);
  // respawns
  for (let i = respawnQ.length - 1; i >= 0; i--) {
    const r = respawnQ[i]; r.t -= dt;
    if (r.t > 0) continue;
    respawnQ.splice(i, 1);
    if (G.teams[r.team ?? r.aa.team].tickets <= 0) continue;
    if (r.what === 'tank') { spawnTeamTank(r.team, r.type, r.parked); if (r.team === ALLY) ui.message(`🛡 Прибыла бронетехника: ${TANK_TYPES[r.type].name}`, 2.5); }
    else if (r.what === 'aa') { const a = r.aa; const idx = G.aas.indexOf(a); G.scene.remove(a.model.root); G.aas.splice(idx, 1); spawnAA(a.team, a.pos); }
  }
}

export function spawnTeamTank(team, type, parked) {
  const b = BASES[team];
  const slot = { light: -1, medium: 0, heavy: 1 }[type];
  const p = new THREE.Vector3(b.x - 18 + slot * 6 + (parked ? 30 : 0), 0, b.z - b.dir * 6 + (parked ? 4 : 0));
  return spawnTank(team, type, p, team === ALLY ? 0 : Math.PI, parked);
}
