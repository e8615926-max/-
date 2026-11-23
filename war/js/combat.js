// Combat: ballistics, wounds, deaths, explosions, projectiles, grenades
import * as THREE from '../lib/three.module.min.js';
import { G, ALLY, ENEMY, rand, pick, clamp, raySphere, rayBox, pointRayDist } from './state.js';
import { rayWorld, losClear, heightAt, colliders } from './world.js';
import * as FX from './effects.js';
import * as SFX from './audio.js';
import { addWoundDecal } from './models.js';
import { COINS, LINES, WEAPONS } from './data.js';
import { ui } from './ui.js';
import { onUnitDown, onUnitDead, alertUnit } from './units.js';
import { damageTank, damageAA, destroyDrone } from './vehicles.js';

const _v = new THREE.Vector3(), _w = new THREE.Vector3(), _o = new THREE.Vector3(), _d = new THREE.Vector3(), _p = new THREE.Vector3();
const PART_MULT = { head: 3.2, torso: 1, armL: 0.55, armR: 0.55, legL: 0.65, legR: 0.65 };
export const PART_NAME = { head: 'голова', torso: 'корпус', armL: 'левая рука', armR: 'правая рука', legL: 'левая нога', legR: 'правая нога' };

export const byPlayer = src => !!src && (src === G.player || src.playerCtrl === true);
export const srcName = src => !src ? '—' : byPlayer(src) ? 'Вы' : (src.name || '—');
export const srcTeam = src => src ? src.team : -1;

// ---------- ray against everything ----------
export function raycastAll(o, d, maxT, ignore, opts = {}) {
  let best = maxT, hit = null;
  const wh = rayWorld(o, d, maxT, true, opts.coarse ? 2.5 : 0.9);
  if (wh) { best = wh.t; hit = { type: 'world', t: wh.t, n: wh.n, mat: wh.mat }; }
  // units
  for (const u of G.units) {
    if (u === ignore || u.state === 'gone' || u.inVehicle) continue;
    if (opts.skipTeam !== undefined && u.team === opts.skipTeam && u.state === 'alive') continue;
    _v.set(u.pos.x, u.pos.y + (u.state === 'alive' ? 0.9 : 0.3), u.pos.z);
    if (pointRayDist(_v, o, d, best) > 1.6) continue;
    for (const h of u.model.userData.hit) {
      _w.copy(h.off); h.o.localToWorld(_w);
      const t = raySphere(o, d, _w, h.r * (u.isPlayer ? 1.1 : 1.15));
      if (t >= 0 && t < best) { best = t; hit = { type: 'unit', t, u, part: h.part, obj: h.o, mat: 'flesh' }; }
    }
  }
  // tanks
  for (const tk of G.tanks) {
    if (tk === ignore || tk.state === 'gone') continue;
    if (o.distanceToSquared(tk.pos) > (best + 8) * (best + 8)) continue;
    _o.copy(o).applyMatrix4(tk.inv); _d.copy(d).transformDirection(tk.inv);
    const T = tk.T; const hb = tk.box;
    const r = rayBox(_o, _d, hb, best);
    if (r && r.t < best) { best = r.t; hit = { type: 'tank', t: r.t, tk, mat: 'metal', n: { x: 0, y: 1, z: 0 } }; }
    void T;
  }
  for (const a of G.aas) {
    if (a === ignore || !a.alive) continue;
    _v.set(a.pos.x, a.pos.y + 1.3, a.pos.z);
    const t = raySphere(o, d, _v, 1.3);
    if (t >= 0 && t < best) { best = t; hit = { type: 'aa', t, a, mat: 'metal', n: { x: -d.x, y: -d.y, z: -d.z } }; }
  }
  for (const dr of G.drones) {
    if (dr === ignore || !dr.alive) continue;
    const t = raySphere(o, d, dr.pos, dr.type === 'bomber' ? 0.85 : 0.6);
    if (t >= 0 && t < best) { best = t; hit = { type: 'drone', t, dr, mat: 'metal', n: { x: -d.x, y: -d.y, z: -d.z } }; }
  }
  if (hit) { hit.point = new THREE.Vector3().copy(d).multiplyScalar(hit.t).add(o); }
  return hit;
}

// ---------- hitscan bullet ----------
export function fireBullet(src, origin, dir, w, muzzle, opts = {}) {
  const range = w.range || 300;
  const ignore = src.isUnit ? src : (opts.ignore || src);
  const hit = raycastAll(origin, dir, range, ignore, { skipTeam: src.team === undefined || byPlayer(src) ? undefined : (Math.random() < 0.85 ? src.team : undefined) });
  const end = hit ? hit.point : _p.copy(dir).multiplyScalar(range).add(origin).clone();
  // tracer
  const tracerChance = opts.tracer ?? (byPlayer(src) ? 0.45 : 0.3);
  if (Math.random() < tracerChance) FX.tracer(muzzle || origin, end, src.team === ENEMY ? [1, 0.45, 0.3] : [1, 0.85, 0.45], 500);
  // near miss crack for the player
  const P = G.player;
  if (P && P.state !== 'dead' && src.team !== P.team && G.mode === 'foot') {
    _v.set(P.pos.x, P.pos.y + 1.5, P.pos.z);
    const len = hit ? hit.t : range;
    const dd = pointRayDist(_v, origin, dir, len);
    if (dd < 2.2 && origin.distanceTo(_v) > 6 && !(hit && hit.u === P)) { SFX.whiz(_v); ui.suppress(0.3); }
  }
  if (!hit) return null;
  applyBulletHit(src, hit, dir, w);
  return hit;
}

export function applyBulletHit(src, hit, dir, w) {
  const dmg = (w.dmg || 30) * (hit.t > w.range * 0.5 ? 0.8 : 1);
  const n = hit.n || { x: -dir.x, y: -dir.y, z: -dir.z };
  if (hit.type === 'world') { FX.impactFx(hit.point, n, hit.mat); SFX.impact(hit.point, hit.mat); return; }
  if (hit.type === 'unit') {
    damageUnit(hit.u, dmg, hit.part, hit.point, dir, src, 'bullet', hit.obj, w);
    return;
  }
  if (hit.type === 'tank') {
    FX.impactFx(hit.point, n, 'metal'); SFX.impact(hit.point, 'metal');
    damageTank(hit.tk, dmg * (hit.tk.type === 'light' ? 0.1 : 0.02), src);
    if (byPlayer(src)) ui.hit(false, false, true);
    return;
  }
  if (hit.type === 'aa') { FX.impactFx(hit.point, n, 'metal'); SFX.impact(hit.point, 'metal'); damageAA(hit.a, dmg * 0.08, src); return; }
  if (hit.type === 'drone') {
    FX.sparks(hit.point, 6); SFX.impact(hit.point, 'metal');
    hit.dr.hp -= dmg; if (byPlayer(src)) ui.hit(hit.dr.hp <= 0, false);
    if (hit.dr.hp <= 0) destroyDrone(hit.dr, src);
  }
}

// ---------- wounds ----------
export function damageUnit(u, dmg, part, point, dir, src, cause, hitObj, w) {
  if (u.state === 'dead' || u.state === 'gone' || u.inVehicle) return;
  if (u.spawnProt > 0 && cause !== 'crush') return;
  const P = u === G.player;
  const fromPlayer = byPlayer(src);
  if (src && src.team === u.team && src !== u) {
    if (fromPlayer && cause === 'bullet') { ui.notice('Не стреляй по своим!'); return; }
    dmg *= cause === 'bullet' ? 0.15 : 0.5;
  }
  let armored = false;
  const A = u.armor;
  if (part === 'head' && A.helmet) {
    if (cause === 'bullet' && Math.random() < 0.25 && dmg < 100) {
      SFX.ricochet(point || u.pos); if (P) { SFX.armorHit(); ui.notice('Рикошет от каски!'); G.shake = 0.4; }
      if (point) FX.sparks(point, 8);
      return;
    }
    dmg *= 0.5; armored = true;
  }
  if (cause === 'bullet') dmg *= PART_MULT[part] || 1;
  if (A.vest > 0 && (part === 'torso' || (A.heavy && part !== 'head'))) {
    const red = A.heavy ? 0.6 : 0.4; const abs = Math.min(A.vest, dmg * red);
    A.vest -= abs * 0.8; dmg -= abs; armored = true; if (P) SFX.armorHit();
  }
  if (u.role === 'commander' && cause === 'bullet') dmg *= 0.9;
  u.hp -= dmg;
  u.lastHitT = G.time; u.lastAttacker = src;
  // wound record + visible wound on the body
  const sev = dmg;
  u.wounds.push({ part, sev, t: G.time });
  if (u.wounds.length > 12) u.wounds.shift();
  if (part !== 'head' || cause !== 'bullet') u.bleed = Math.min(6, u.bleed + sev * (cause === 'explosion' ? 0.05 : 0.035));
  else u.bleed = Math.min(6, u.bleed + sev * 0.02);
  const hitEntry = hitObj ? { o: hitObj } : pick(u.model.userData.hit.filter(h => h.part === part)) || u.model.userData.hit[1];
  if (u.decals < 10) {
    const lp = point ? hitEntry.o.worldToLocal(point.clone()) : new THREE.Vector3(rand(-0.1, 0.1), rand(-0.3, 0), rand(-0.12, 0.12));
    if (point && hitObj) lp.multiplyScalar(0.92);
    addWoundDecal(hitEntry.o, lp, sev > 35); u.decals++;
  }
  if (point) { FX.blood(point, dir || _v.set(0, 0, 0), sev > 40 ? 2 : 1); SFX.impact(point, 'flesh'); }
  if (Math.random() < 0.5) FX.bloodPool(u.pos);
  alertUnit(u, src);
  if (P) {
    if (src && src.pos) ui.damageFrom(src.pos);
    ui.damaged(dmg, part);
    G.shake = Math.max(G.shake, Math.min(1, dmg / 50));
    if (dmg > 6 && u.hp > 0) SFX.grunt(null, 1);
  } else if (u.hp > 0 && G.time > u.screamCd && Math.random() < 0.85) {
    u.screamCd = G.time + rand(1.2, 2.5);
    SFX.scream(u.pos, u.voice, clamp(dmg / 40, 0.5, 1.2));
  }
  if (fromPlayer) ui.hit(false, part === 'head');
  if (u.hp <= 0) resolveFatal(u, -u.hp, part, cause, src, armored);
}

function resolveFatal(u, overkill, part, cause, src, armored) {
  if (u.state === 'down') { killUnit(u, src, cause, false); return; }
  const head = part === 'head' && cause === 'bullet';
  const lethal = (head && !(armored && overkill < 25)) || overkill > 75 || (cause === 'explosion' && overkill > 55) || cause === 'crush' || cause === 'fall';
  const surviveChance = lethal ? 0 : clamp(0.85 - overkill / 90, 0.25, 0.85);
  if (Math.random() < surviveChance) downUnit(u, src);
  else killUnit(u, src, cause, head);
}

export function downUnit(u, src) {
  u.state = 'down'; u.hp = 1; u.downTimer = u.isPlayer ? 40 : rand(35, 55); u.fallT = 0; u.fallDir = 1;
  u.target = null;
  SFX.scream(u.pos, u.voice, 1.2);
  credit(u, src, false, true);
  onUnitDown(u, src);
  if (u.team === ALLY && !u.isPlayer && G.player && u.pos.distanceTo(G.player.pos) < 45) ui.chat(u.name, pick(LINES.medic), ALLY);
}

export function killUnit(u, src, cause, head) {
  if (u.state === 'dead' || u.state === 'gone') return;
  const wasDown = u.state === 'down';
  u.state = 'dead'; u.hp = 0; u.deadT = 0; if (!wasDown) { u.fallT = 0; u.fallDir = Math.random() < 0.5 ? 1 : -1; }
  G.teams[u.team].tickets = Math.max(0, G.teams[u.team].tickets - 1);
  G.teams[u.team].morale = clamp(G.teams[u.team].morale - 1.5, 5, 100);
  if (src && src.team !== undefined && src.team !== u.team) G.teams[src.team].morale = clamp(G.teams[src.team].morale + 0.8, 5, 100);
  if (!wasDown) { SFX.grunt(u.pos, u.voice); credit(u, src, head, false); }
  const wName = src && src.weaponName ? src.weaponName() : cause === 'explosion' ? '💥' : '';
  ui.killfeed(srcName(src), srcTeam(src), u.isPlayer ? 'Вы' : u.name, u.team, wName, head);
  onUnitDead(u, src);
}

function credit(u, src, head, down) {
  if (u.credited) return; u.credited = true;
  if (!src || src.team === u.team) return;
  G.teams[src.team].kills++;
  if (byPlayer(src)) {
    G.stats.kills++; if (head) G.stats.headshots++;
    award(COINS.kill + (head ? COINS.head : 0), head ? 'Хэдшот' : down ? 'Выведен из строя' : 'Убит');
    ui.hit(true, head);
  }
}

export function award(n, reason) {
  const P = G.player; if (!P) return;
  P.coins += n; G.stats.earned += n; ui.reward(n, reason); SFX.coin();
}

// ---------- explosions ----------
export function explode(pos, radius, dmg, src, opts = {}) {
  const size = opts.size ?? radius / 6;
  FX.explosionFx(pos, size); SFX.explosion(pos, size);
  _p.copy(pos); _p.y += 0.4;
  for (const u of G.units) {
    if (u.state === 'dead' || u.state === 'gone' || u.inVehicle) continue;
    const d = u.pos.distanceTo(pos); if (d > radius) continue;
    _v.set(u.pos.x, u.pos.y + 0.9, u.pos.z);
    const cover = losClear(_p, _v) ? 1 : 0.25;
    const k = Math.pow(1 - d / radius, 1.4) * cover;
    if (k < 0.02) continue;
    const parts = ['torso', 'torso', 'legL', 'legR', 'armL', 'armR', 'head'];
    const nHits = d < radius * 0.4 ? 3 : 1 + (Math.random() < 0.5 ? 1 : 0);
    _d.subVectors(u.pos, pos).normalize();
    for (let i = 0; i < nHits; i++) damageUnit(u, dmg * k / nHits * rand(0.8, 1.2), pick(parts), null, _d, src, 'explosion');
    if (u.isPlayer && d < radius) G.shake = Math.max(G.shake, 1.2);
  }
  const tankDmg = opts.tankDmg ?? dmg;
  for (const tk of G.tanks) {
    if (tk.state !== 'alive') continue;
    const d = Math.max(0, tk.pos.distanceTo(pos) - tk.T.l * 0.4);
    if (opts.direct === tk) damageTank(tk, tankDmg, src);
    else if (d < radius * 0.8) damageTank(tk, tankDmg * 0.5 * (1 - d / radius), src);
  }
  for (const a of G.aas) { if (!a.alive) continue; const d = a.pos.distanceTo(pos); if (d < radius) damageAA(a, tankDmg * 0.7 * (1 - d / radius) + (opts.direct === a ? tankDmg : 0), src); }
  for (const dr of G.drones) { if (!dr.alive) continue; if (dr.pos.distanceTo(pos) < radius * 0.9 && dr !== opts.self) destroyDrone(dr, src); }
}

// ---------- projectiles ----------
const projGeo = { rocket: new THREE.CylinderGeometry(0.04, 0.05, 0.6, 6).rotateX(Math.PI / 2), bomb: new THREE.SphereGeometry(0.08, 6, 4) };
const projMat = new THREE.MeshLambertMaterial({ color: 0x3f4a30 });
export function spawnProjectile(p) {
  p.pos = p.pos.clone(); p.vel = p.vel.clone(); p.life = p.life ?? 6; p.age = 0;
  p.team = p.src ? p.src.team : -1;
  if (p.type === 'rocket' || p.type === 'bomb') { p.mesh = new THREE.Mesh(projGeo[p.type], projMat); p.mesh.position.copy(p.pos); G.scene.add(p.mesh); }
  G.projectiles.push(p);
  return p;
}

export function updateProjectiles(dt) {
  for (let i = G.projectiles.length - 1; i >= 0; i--) {
    const p = G.projectiles[i];
    p.age += dt; p.life -= dt;
    _o.copy(p.pos);
    p.vel.y -= (p.grav || 0) * dt;
    if (p.type === 'rocket' && p.age > 0.15) p.vel.multiplyScalar(1 + dt * 0.6).clampLength(0, 145);
    _d.copy(p.vel).multiplyScalar(dt); const len = _d.length(); _d.divideScalar(len || 1);
    let detonate = false, at = null, hit = null;
    if (len > 0) {
      hit = raycastAll(_o, _d, len, p.ignore || p.src, { coarse: false });
      if (hit && hit.type === 'unit' && p.age < 0.08 && hit.u === p.src) hit = null;
      if (hit) { detonate = true; at = hit.point; }
    }
    if (!detonate) p.pos.addScaledVector(_d, len);
    if (p.type === 'flak' && !detonate) {
      for (const dr of G.drones) if (dr.alive && dr.team !== p.team && dr.pos.distanceTo(p.pos) < 3.8) { detonate = true; at = p.pos; break; }
    }
    if (p.mesh) { p.mesh.position.copy(p.pos); p.mesh.lookAt(_v.copy(p.pos).add(p.vel)); }
    if (p.type === 'rocket') FX.smokeTrail(p.pos, 1);
    else if (p.type === 'shell' || p.type === 'ac') { if (Math.random() < 0.7) FX.tracer(_o, p.pos, [1, 0.7, 0.35], 2000); }
    else if (p.type === 'flak') { if (Math.random() < 0.6) FX.tracer(_o, p.pos, p.team === ENEMY ? [1, 0.4, 0.3] : [1, 0.9, 0.5], 1500); }
    if (p.life <= 0 && !detonate) { if (p.type === 'flak') { detonate = true; at = p.pos; } else { removeProj(i); continue; } }
    if (detonate) {
      const pos = at.clone();
      if (hit) pos.addScaledVector(_d, -0.15);
      if (p.type === 'flak') {
        FX.flakFx(pos); SFX.explosion(pos, 0.35);
        for (const dr of G.drones) if (dr.alive && dr.team !== p.team && dr.pos.distanceTo(pos) < 4.5) destroyDrone(dr, p.src);
        if (hit && hit.type === 'unit') damageUnit(hit.u, 45, hit.part, hit.point, _d, p.src, 'bullet', hit.obj);
        for (const u of G.units) if (u.state === 'alive' && !u.inVehicle && u.pos.distanceTo(pos) < 2.5) damageUnit(u, 30, 'torso', null, _d, p.src, 'explosion');
      } else if (p.type === 'ac') {
        if (hit && hit.type === 'unit') damageUnit(hit.u, 70, hit.part, hit.point, _d, p.src, 'bullet', hit.obj);
        explode(pos, 3, 45, p.src, { size: 0.35, tankDmg: 0, direct: null });
        if (hit && hit.type === 'tank') damageTank(hit.tk, 32, p.src);
        if (hit && hit.type === 'aa') damageAA(hit.a, 30, p.src);
      } else {
        const direct = hit ? (hit.tk || hit.a || null) : null;
        if (hit && hit.type === 'unit') damageUnit(hit.u, 200, hit.part, hit.point, _d, p.src, 'explosion', hit.obj);
        explode(pos, p.radius || 6, p.dmg || 140, p.src, { size: p.size || 1, tankDmg: p.tankDmg || 300, direct });
        if (hit && hit.type === 'drone') destroyDrone(hit.dr, p.src);
      }
      removeProj(i);
    }
  }
}
function removeProj(i) { const p = G.projectiles[i]; if (p.mesh) G.scene.remove(p.mesh); G.projectiles.splice(i, 1); }

// ---------- grenades ----------
const grenGeo = new THREE.SphereGeometry(0.065, 8, 6); const grenMat = new THREE.MeshLambertMaterial({ color: 0x3e4a2c });
export function throwGrenade(src, pos, vel) {
  const m = new THREE.Mesh(grenGeo, grenMat); m.position.copy(pos); G.scene.add(m);
  const g = { pos: pos.clone(), vel: vel.clone(), fuse: rand(3.0, 3.6), src, team: src.team, mesh: m, warned: false };
  G.grenades.push(g);
  return g;
}

export function updateGrenades(dt) {
  for (let i = G.grenades.length - 1; i >= 0; i--) {
    const g = G.grenades[i]; g.fuse -= dt;
    g.vel.y -= 13 * dt;
    const prev = _o.copy(g.pos);
    g.pos.addScaledVector(g.vel, dt);
    const h = heightAt(g.pos.x, g.pos.z);
    if (g.pos.y < h + 0.065) {
      g.pos.y = h + 0.065;
      if (Math.abs(g.vel.y) > 1.5) SFX.bounce(g.pos, false);
      g.vel.y = Math.abs(g.vel.y) * 0.3; g.vel.x *= 0.55; g.vel.z *= 0.55;
    }
    for (const c of colliders) {
      if (c.dead) continue;
      if (g.pos.x > c.minX && g.pos.x < c.maxX && g.pos.y > c.minY && g.pos.y < c.maxY && g.pos.z > c.minZ && g.pos.z < c.maxZ) {
        const inX = prev.x > c.minX && prev.x < c.maxX, inZ = prev.z > c.minZ && prev.z < c.maxZ, inY = prev.y > c.minY && prev.y < c.maxY;
        if (!inY) { g.pos.y = prev.y; g.vel.y = Math.abs(g.vel.y) * 0.3; g.vel.x *= 0.6; g.vel.z *= 0.6; }
        else if (!inX) { g.pos.x = prev.x; g.vel.x *= -0.4; }
        else if (!inZ) { g.pos.z = prev.z; g.vel.z *= -0.4; }
        else g.pos.copy(prev);
        SFX.bounce(g.pos, c.mat === 'metal');
      }
    }
    g.mesh.position.copy(g.pos); g.mesh.rotation.x += g.vel.length() * dt * 3;
    if (!g.warned && g.vel.lengthSq() < 4) {
      g.warned = true;
      for (const u of G.units) {
        if (u.isPlayer || u.state !== 'alive' || u.inVehicle) continue;
        if (u.pos.distanceTo(g.pos) < 9) {
          u.flee = { x: u.pos.x - g.pos.x, z: u.pos.z - g.pos.z, t: 1.8 };
          if (u.team === ALLY && G.player && u.pos.distanceTo(G.player.pos) < 25 && Math.random() < 0.5) { ui.chat(u.name, pick(LINES.grenade), ALLY); SFX.scream(u.pos, u.voice * 1.1, 0.8); }
        }
      }
      if (G.player && G.player.pos.distanceTo(g.pos) < 10 && g.team !== ALLY) ui.grenadeWarn(g);
    }
    if (g.fuse <= 0) {
      G.scene.remove(g.mesh); G.grenades.splice(i, 1);
      const p = g.pos.clone(); p.y += 0.15;
      explode(p, 8, 170, g.src, { size: 1.0, tankDmg: 40 });
    }
  }
}

// helper: ballistic launch velocity for AI grenade toss
export function tossVelocity(from, to, angle = 0.75) {
  const dx = to.x - from.x, dz = to.z - from.z; const d = Math.hypot(dx, dz);
  const dy = to.y - from.y; const g = 13;
  const c = Math.cos(angle), s = Math.sin(angle);
  const denom = 2 * c * c * (d * Math.tan(angle) - dy);
  const v = denom > 0 ? Math.sqrt(g * d * d / denom) : 14;
  const vv = Math.min(v, 22);
  return new THREE.Vector3(dx / d * vv * c, vv * s, dz / d * vv * c);
}

export function weaponOf(id) { return WEAPONS[id]; }
