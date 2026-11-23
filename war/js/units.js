// Soldiers: creation, squads, AI, medics, commanders, reinforcements
import * as THREE from '../lib/three.module.min.js';
import { G, ALLY, ENEMY, rand, randi, pick, clamp, angDiff, CALLSIGNS, ENEMY_CALLSIGNS, damp } from './state.js';
import { heightAt, groundAt, pushOut, losClear, BASES, MAP } from './world.js';
import { makeSoldier, replaceTpGun } from './models.js';
import { WEAPONS, LINES, COINS } from './data.js';
import * as FX from './effects.js';
import * as SFX from './audio.js';
import { fireBullet, spawnProjectile, throwGrenade, tossVelocity, killUnit, award } from './combat.js';
import { ui } from './ui.js';
import { launchDrone } from './vehicles.js';

const _v = new THREE.Vector3(), _a = new THREE.Vector3(), _b = new THREE.Vector3(), _d = new THREE.Vector3();
const names = [[...CALLSIGNS], [...ENEMY_CALLSIGNS]];
let squadId = 1;
export const squads = [];

const ROLE_WEAPON = { commander: 'ak', rifleman: 'ak', medic: 'smg', mg: 'pkm', sniper: 'svd', at: 'ak', operator: 'ak', basemedic: 'pm', player: 'ak' };
export const ROLE_NAME = { commander: 'Командир', rifleman: 'Стрелок', medic: 'Медик', mg: 'Пулемётчик', sniper: 'Снайпер', at: 'Гранатомётчик', operator: 'Оператор БПЛА', basemedic: 'Врач', player: 'Вы' };

// ---------- markers above heads ----------
function markerTex(draw) { const c = document.createElement('canvas'); c.width = c.height = 64; draw(c.getContext('2d')); const t = new THREE.CanvasTexture(c); return new THREE.SpriteMaterial({ map: t, depthTest: false, depthWrite: false, transparent: true, sizeAttenuation: false }); }
const MK = {
  ally: markerTex(x => { x.fillStyle = '#3d8bff'; x.strokeStyle = '#001a40'; x.lineWidth = 4; x.beginPath(); x.moveTo(12, 14); x.lineTo(52, 14); x.lineTo(32, 46); x.closePath(); x.fill(); x.stroke(); }),
  medic: markerTex(x => { x.fillStyle = '#fff'; x.fillRect(8, 8, 48, 48); x.fillStyle = '#d01010'; x.fillRect(26, 12, 12, 40); x.fillRect(12, 26, 40, 12); }),
  down: markerTex(x => { x.fillStyle = '#d01010'; x.beginPath(); x.arc(32, 32, 28, 0, 7); x.fill(); x.fillStyle = '#fff'; x.fillRect(27, 12, 10, 40); x.fillRect(12, 27, 40, 10); }),
  enemy: markerTex(x => { x.fillStyle = '#ff3b30'; x.strokeStyle = '#400'; x.lineWidth = 4; x.beginPath(); x.moveTo(32, 8); x.lineTo(54, 32); x.lineTo(32, 56); x.lineTo(10, 32); x.closePath(); x.fill(); x.stroke(); }),
  cmd: markerTex(x => { x.fillStyle = '#ffd23d'; x.strokeStyle = '#3a2a00'; x.lineWidth = 4; x.beginPath(); for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2 - Math.PI / 2; const r = i % 2 ? 12 : 28; x.lineTo(32 + Math.cos(a) * r, 32 + Math.sin(a) * r); } x.closePath(); x.fill(); x.stroke(); }),
};

export function createUnit(team, role, pos, opts = {}) {
  const wId = opts.weapon || ROLE_WEAPON[role] || 'ak';
  const W = WEAPONS[wId];
  const model = makeSoldier(team, role, W.kind);
  model.position.copy(pos);
  G.scene.add(model);
  const pool = names[team]; const name = opts.name || (pool.length ? pool.splice(randi(0, pool.length - 1), 1)[0] : 'Боец-' + G.nextId);
  const maxHp = opts.hp || (role === 'commander' ? 120 : 100);
  const u = {
    id: G.nextId++, isUnit: true, team, role, name, isPlayer: !!opts.player,
    pos: pos.clone(), vel: new THREE.Vector3(), yaw: team === ALLY ? 0 : Math.PI, pitch: 0, vy: 0,
    hp: maxHp, maxHp, armor: { helmet: role !== 'commander', vest: role === 'mg' || role === 'commander' ? 60 : 0, heavy: false },
    wounds: [], bleed: 0, state: 'alive', downTimer: 0, fallT: 0, fallDir: 1, deadT: 0,
    weapon: wId, mag: W.mag, fireCd: rand(0, 1), burst: randi(3, 6), reloadT: 0,
    target: null, thinkT: rand(0, 0.4), squad: null, model, crouch: false, inVehicle: null,
    voice: rand(0.8, 1.25), screamCd: 0, decals: 0, step: 0, stepDist: 0, grenades: role === 'rifleman' || role === 'commander' ? 2 : 1,
    healT: 0, patient: null, medicBy: null, moraleBuff: 0, flee: null, stuckT: 0, detour: null, detourT: 0,
    spawnProt: 2.5, shoutT: rand(6, 14), lastHitT: -99, credited: false, goal: new THREE.Vector3().copy(pos), wantSpeed: 0,
    canSee: false, seenT: 0, spotted: 0, throwT: 0, droneT: G.time + rand(10, 30), rpgT: 0, retreating: false, aimYaw: 0,
    lastPos: pos.clone(), formation: new THREE.Vector3(),
    weaponName() { return WEAPONS[this.weapon].name; },
  };
  const mk = new THREE.Sprite(team === ALLY ? (role === 'medic' ? MK.medic : role === 'commander' ? MK.cmd : MK.ally) : MK.enemy);
  mk.scale.set(0.022, 0.022, 1); mk.position.y = 2.25; mk.renderOrder = 999; model.add(mk); u.marker = mk; u.markerBase = mk.material;
  if (u.isPlayer) mk.visible = false;
  G.units.push(u);
  return u;
}

const FORM = [[0, 0], [-3.5, 3], [3.5, 3], [-7, 6], [7, 6], [0, 7]];
export function spawnSquad(team, extraRoles, forward = 0) {
  const b = BASES[team];
  const roles = ['commander', 'rifleman', 'medic', 'mg', extraRoles || pick(['rifleman', 'sniper', 'at', 'operator', 'at', 'rifleman'])];
  const sq = { id: squadId++, team, members: [], leader: null, objective: new THREE.Vector3(b.x, 0, b.z + b.dir * 40), flag: null, objT: 0, engaged: 0 };
  const cx = b.spawn.x + rand(-14, 14), cz = b.spawn.z + rand(-3, 3) + b.dir * forward;
  roles.forEach((r, i) => {
    const p = new THREE.Vector3(cx + FORM[i][0] * 0.6, 0, cz - b.dir * FORM[i][1] * -0.4);
    p.y = heightAt(p.x, p.z);
    const u = createUnit(team, r, p);
    u.squad = sq; u.formIdx = i; sq.members.push(u);
  });
  sq.leader = sq.members[0];
  squads.push(sq);
  chooseObjective(sq);
  return sq;
}

function chooseObjective(sq) {
  const team = sq.team; const b = BASES[team];
  const flags = [...G.flags].sort((f1, f2) => Math.abs(f1.z - b.z) - Math.abs(f2.z - b.z));
  let target = null;
  // some squads defend contested owned flags
  const threatened = flags.find(f => f.owner === team && f.contested);
  if (threatened && sq.id % 3 === 0) target = threatened;
  if (!target) target = flags.find(f => f.owner !== team || (team === ALLY ? f.progress < 1 : f.progress > -1));
  if (!target) {
    const eb = BASES[1 - team];
    sq.objective.set(rand(-25, 25), 0, eb.z + eb.dir * 32);
    sq.flag = null;
  } else {
    if (sq.flag !== target || sq.objective.distanceTo(target.pos) > 9) sq.objective.set(target.x + rand(-6, 6), 0, target.z + rand(-6, 6));
    sq.flag = target;
  }
}

// ---------- events ----------
export function onUnitDown(u) {
  u.target = null; u.patient = null;
  if (u.marker && u.team === ALLY && !u.isPlayer) { u.marker.material = MK.down; u.marker.visible = true; }
  if (u.isPlayer) ui.playerDown(true);
}
export function onUnitDead(u) {
  if (u.marker) u.marker.visible = false;
  if (u.squad) { const sq = u.squad; if (sq.leader === u) sq.leader = sq.members.find(m => m.state === 'alive' && !m.isPlayer) || null; }
  for (const m of G.units) if (m.patient === u) m.patient = null;
  if (u.isPlayer) ui.playerDead();
}
export function alertUnit(u, src) {
  if (u.isPlayer || !src || src.team === u.team || u.state !== 'alive') return;
  if (!u.target && src.isUnit && src.state === 'alive') { u.target = src; u.seenT = G.time; }
  if (src.pos) u.alertDir = Math.atan2(-(src.pos.x - u.pos.x), -(src.pos.z - u.pos.z));
  u.alertT = 2;
}

function reviveUnit(u, medic) {
  u.state = 'alive'; u.hp = Math.max(u.hp, 45); u.bleed = 0; u.downTimer = 0; u.fallT = 0; u.credited = false;
  u.model.userData.parts.body.rotation.set(0, 0, 0); u.model.userData.parts.body.position.y = 0;
  if (u.marker) { u.marker.material = u.markerBase; u.marker.visible = !u.isPlayer; }
  if (u.isPlayer) { ui.playerDown(false); ui.message(`${medic.name} поднял вас! Продолжайте бой`, 2.5); }
}

export function healUnit(u, medic, amount = 55) {
  const wasDown = u.state === 'down';
  if (wasDown) reviveUnit(u, medic);
  u.hp = Math.min(u.maxHp, u.hp + amount); u.bleed = 0;
  u.wounds.forEach(w => w.sev *= 0.4); u.wounds = u.wounds.filter(w => w.sev > 6);
  SFX.bandage(); FX.healFx(u.pos);
  if (u.isPlayer && !wasDown) ui.message(`Медик ${medic.name} перевязал вас (+${amount})`, 2);
  return wasDown;
}

// ---------- visibility & targeting ----------
const eye = new THREE.Vector3(), tgt = new THREE.Vector3();
function aimPoint(t, out) {
  if (t.isUnit) return out.set(t.pos.x, t.pos.y + (t.state === 'down' ? 0.25 : t.crouch ? 0.85 : 1.25), t.pos.z);
  if (t.kind === 'tank') return out.set(t.pos.x, t.pos.y + 1.4, t.pos.z);
  if (t.kind === 'aa') return out.set(t.pos.x, t.pos.y + 1.3, t.pos.z);
  return out.copy(t.pos);
}
function canSee(u, t) {
  eye.set(u.pos.x, u.pos.y + (u.crouch ? 1.0 : 1.6), u.pos.z);
  aimPoint(t, tgt);
  return losClear(eye, tgt);
}
function findTarget(u) {
  const range = u.role === 'sniper' ? 190 : 115;
  const cands = [];
  for (const e of G.units) {
    if (e.team === u.team || e.state !== 'alive' || e.inVehicle) continue;
    let d = u.pos.distanceTo(e.pos);
    if (e.isPlayer && G.mode === 'drone') d *= 0.8; // operator is stationary - easier to spot
    if (d < range) cands.push([d * (e.crouch ? 1.25 : 1), e]);
  }
  for (const t of G.tanks) if (t.team !== u.team && t.state === 'alive') {
    const d = u.pos.distanceTo(t.pos);
    if (u.role === 'at' && d < 170) cands.push([d * 0.4, t]);
    else if (d < 30) cands.push([d * 3, t]);
  }
  for (const dr of G.drones) if (dr.team !== u.team && dr.alive) {
    const d = u.pos.distanceTo(dr.pos);
    if (d < 70) cands.push([d * (u.role === 'mg' ? 0.6 : 0.9), dr]);
  }
  cands.sort((a, b) => a[0] - b[0]);
  for (let i = 0; i < Math.min(4, cands.length); i++) if (canSee(u, cands[i][1])) return cands[i][1];
  return null;
}

function targetAlive(t) { return t && (t.isUnit ? t.state === 'alive' && !t.inVehicle : t.kind === 'tank' ? t.state === 'alive' : t.alive); }

// ---------- per-unit thinking ----------
function think(u) {
  const sq = u.squad; const b = BASES[u.team];
  // keep target or find new
  if (!targetAlive(u.target) || Math.random() < 0.25) {
    const t = findTarget(u);
    if (t) { if (t !== u.target) u.seenT = G.time; u.target = t; u.canSee = true; }
    else if (u.target && targetAlive(u.target)) { u.canSee = canSee(u, u.target); if (!u.canSee && G.time - u.seenT > 4) u.target = null; }
    else u.target = null;
  } else { u.canSee = canSee(u, u.target); if (u.canSee) u.seenT = G.time; else if (G.time - u.seenT > 4) u.target = null; }
  if (u.target && u.canSee) { u.spotted = G.time; if (sq) sq.engaged = G.time; }

  // retreat when badly wounded
  const medicNear = G.units.some(m => m.team === u.team && m.role === 'medic' && m.state === 'alive' && m !== u && m.pos.distanceTo(u.pos) < 45);
  if (!u.retreating && u.hp < u.maxHp * 0.3 && u.bleed > 0.3 && !medicNear && u.role !== 'basemedic') u.retreating = true;
  if (u.retreating && u.hp > u.maxHp * 0.85) u.retreating = false;

  // weapon choice for anti-tank
  if (u.role === 'at') {
    const wantRpg = u.target && u.target.kind === 'tank';
    const w = wantRpg ? 'rpg' : 'ak';
    if (u.weapon !== w) { u.weapon = w; u.mag = WEAPONS[w].mag; replaceTpGun(u.model, WEAPONS[w].kind); u.reloadT = 0.8; }
  }
  // medic duty
  if (u.role === 'medic' || u.role === 'basemedic') {
    if (u.patient && (u.patient.state === 'dead' || u.patient.state === 'gone' || (u.patient.state === 'alive' && u.patient.hp > u.patient.maxHp * 0.8))) { if (u.patient.medicBy === u) u.patient.medicBy = null; u.patient = null; }
    if (!u.patient) {
      let best = null, bd = u.role === 'basemedic' ? 14 : 60;
      for (const m of G.units) {
        if (m.team !== u.team || m === u || m.inVehicle || (m.medicBy && m.medicBy !== u)) continue;
        if (!(m.state === 'down' || (m.state === 'alive' && m.hp < m.maxHp * 0.6))) continue;
        const d = m.pos.distanceTo(u.pos) * (m.state === 'down' ? 0.5 : 1) * (m.isPlayer ? 0.6 : 1);
        if (d < bd) { bd = d; best = m; }
      }
      if (best && (!u.target || u.pos.distanceTo(u.target.pos) > 18 || best.state === 'down')) { u.patient = best; best.medicBy = u; u.healT = 0; }
    }
  }
  // drone operator launches drones
  if (u.role === 'operator' && G.time > u.droneT && u.state === 'alive') {
    const mine = G.drones.filter(d => d.alive && d.team === u.team && d.controller === 'ai').length;
    if (mine < 2) { launchDrone(u.team, Math.random() < 0.65 ? 'fpv' : 'bomber', u.pos, u); u.droneT = G.time + rand(28, 45); }
    else u.droneT = G.time + 8;
  }
  // grenades
  if (u.target && u.target.isUnit && u.canSee && u.grenades > 0 && G.time > u.throwT) {
    const d = u.pos.distanceTo(u.target.pos);
    if (d > 9 && d < 26 && Math.random() < 0.09) {
      u.grenades--; u.throwT = G.time + 6; u.throwAnim = 0.6;
      const from = _a.set(u.pos.x, u.pos.y + 1.7, u.pos.z);
      const to = _b.copy(u.target.pos).add(_d.set(rand(-2.5, 2.5), 0, rand(-2.5, 2.5)));
      setTimeout(() => { if (u.state === 'alive') { throwGrenade(u, from, tossVelocity(from, to)); } }, 350);
    }
  }
  // goal selection
  const g = u.goal; let speed = 3.6;
  if (u.flee && u.flee.t > 0) { const l = Math.hypot(u.flee.x, u.flee.z) || 1; g.set(u.pos.x + u.flee.x / l * 8, 0, u.pos.z + u.flee.z / l * 8); speed = 5.5; }
  else if (u.patient) { g.copy(u.patient.pos); speed = 5.2; }
  else if (u.role === 'basemedic') { g.set(b.med.x + 1.5, 0, b.med.z - b.dir * 2.5); speed = 2.5; }
  else if (u.retreating) { g.set(b.med.x + rand(-3, 3), 0, b.med.z + rand(-3, 3)); speed = 4.6; }
  else if (u.target && u.canSee) {
    const d = u.pos.distanceTo(u.target.pos); const ideal = u.role === 'sniper' ? 90 : u.weapon === 'smg' ? 22 : 38;
    if (d > ideal * 1.4) { _d.subVectors(u.target.pos, u.pos).normalize(); g.copy(u.pos).addScaledVector(_d, 6); speed = 3.2; }
    else if (d < ideal * 0.4 && u.target.isUnit) { _d.subVectors(u.pos, u.target.pos).normalize(); g.copy(u.pos).addScaledVector(_d, 4); speed = 2.8; }
    else { // strafe a little
      if (Math.random() < 0.35) { const s = Math.random() < 0.5 ? -1 : 1; g.set(u.pos.x + Math.cos(u.yaw) * s * 3, 0, u.pos.z - Math.sin(u.yaw) * s * 3); }
      speed = 1.8;
    }
    u.crouch = u.role === 'sniper' || u.role === 'mg' || Math.random() < 0.4;
  } else if (sq && sq.leader && sq.leader !== u && sq.leader.state === 'alive') {
    const L = sq.leader; const f = FORM[u.formIdx % FORM.length];
    const c = Math.cos(L.yaw), s = Math.sin(L.yaw);
    g.set(L.pos.x + f[0] * c + f[1] * s, 0, L.pos.z - f[0] * s + f[1] * c);
    speed = u.pos.distanceTo(g) > 8 ? 5 : 3.6; u.crouch = false;
  } else if (sq) {
    g.copy(sq.objective); u.crouch = false;
    if (u.pos.distanceTo(g) < 4) { // reached: wait and look around
      g.copy(u.pos); speed = 0;
    }
  }
  if (u.alertT > 0 && !u.target) u.yawGoal = u.alertDir;
  u.wantSpeed = speed;
}

// ---------- commander voice ----------
export function commanderShout(u, kind) {
  const P = G.player; if (!P) return;
  const lines = u.team === ALLY ? (LINES[kind] || LINES.advance) : LINES.enemy;
  const text = pick(lines);
  const d = u.pos.distanceTo(P.pos);
  if (u.team === ALLY) {
    if (d > 70) { SFX.radioBeep(); }
    else SFX.scream(u.pos, 0.7, 0.4, true);
    const spoke = SFX.speak(text, { pitch: 0.7, rate: 1.12, volume: d > 70 ? 0.8 : 1 });
    ui.subtitle(`${d > 70 ? '📻 ' : ''}Командир ${u.name}`, text, ALLY);
    void spoke;
  } else if (d < 55) {
    SFX.speak(text, { pitch: 0.45, rate: 1.2, volume: 0.6 });
    ui.subtitle('Вражеский командир', text, ENEMY);
  }
  // morale boost for nearby squad
  G.teams[u.team].morale = clamp(G.teams[u.team].morale + 2.5, 5, 100);
  for (const m of G.units) if (m.team === u.team && m.state === 'alive' && m.pos.distanceTo(u.pos) < 35) m.moraleBuff = 14;
}

let globalShoutT = 6;
const eventCd = { tank: 0, drone: 0 };
export function teamEvent(team, kind) {
  if (G.time < eventCd[kind] || team !== ALLY) return;
  eventCd[kind] = G.time + 25;
  const cmd = G.units.find(u => u.team === team && u.role === 'commander' && u.state === 'alive');
  if (cmd) { commanderShout(cmd, kind); globalShoutT = G.time + 9; }
}

// ---------- AI fire ----------
function aiFire(u, dt) {
  const t = u.target; if (!t || !u.canSee || u.patient || u.flee?.t > 0) return;
  if (u.reloadT > 0) return;
  const W = WEAPONS[u.weapon];
  aimPoint(t, tgt);
  const muzzle = _a.set(0, 0, -0.75); u.model.userData.parts.gun.localToWorld(muzzle);
  const origin = _b.set(u.pos.x, u.pos.y + (u.crouch ? 1.0 : 1.45), u.pos.z);
  _d.subVectors(tgt, origin); const dist = _d.length(); _d.divideScalar(dist);
  const want = Math.atan2(-_d.x, -_d.z);
  if (Math.abs(angDiff(u.yaw, want)) > 0.3) return;
  if (u.fireCd > 0) return;
  if (u.mag <= 0) { u.reloadT = W.reload * 1.2; u.mag = W.mag; u.reloadAnim = W.reload; return; }
  // accuracy model: distance, morale, wounds, movement
  const morale = G.teams[u.team].morale;
  const armW = u.wounds.reduce((s, w) => s + (w.part.startsWith('arm') ? w.sev : 0), 0);
  let err = 0.022 + dist * 0.00022;
  err *= (u.moraleBuff > 0 ? 0.72 : 1) * (1.35 - morale / 200) * (1 + armW / 70) * (u.vel.lengthSq() > 2 ? 1.6 : 1) * (u.crouch ? 0.8 : 1);
  err *= W.ai || 1;
  if (u.role === 'sniper') err *= 0.35;
  if (t.isPlayer) err *= 1.25;
  if (t.kind === 'drone') err *= 1.4;
  _d.x += rand(-err, err); _d.y += rand(-err, err) * 0.7; _d.z += rand(-err, err); _d.normalize();
  const near = G.camera.position.distanceTo(origin) < 45;
  if (W.projectile === 'rocket') {
    if (G.time < u.rpgT) return;
    u.rpgT = G.time + rand(6, 10);
    spawnProjectile({ type: 'rocket', pos: muzzle, vel: _d.clone().multiplyScalar(70), src: u, grav: 1.5, life: 5, radius: 4.5, dmg: 120, tankDmg: 420, size: 0.8 });
    SFX.explosion(muzzle, 0.25); FX.muzzleFlash(muzzle, _d, 2, near);
    u.mag = 0; u.fireCd = 2; return;
  }
  const pellets = W.pellets || 1;
  for (let i = 0; i < pellets; i++) {
    const dd = pellets > 1 ? _v.copy(_d).add(new THREE.Vector3(rand(-W.spread, W.spread), rand(-W.spread, W.spread), rand(-W.spread, W.spread))).normalize() : _d;
    fireBullet(u, origin, dd, W, muzzle);
  }
  SFX.shot(W.sound, muzzle, false);
  FX.muzzleFlash(muzzle, _d, W.kind === 'mg' ? 1.2 : 0.9, near);
  u.mag--; u.recoil = 1;
  u.fireCd = 60 / W.rpm * (W.auto ? 1 : rand(1.5, 3));
  if (--u.burst <= 0) { u.burst = u.role === 'mg' ? randi(6, 14) : randi(2, 6); u.fireCd = u.role === 'sniper' ? rand(2, 3.5) : rand(0.35, 1.1); }
}

// ---------- movement ----------
function moveAI(u, dt) {
  const speedMul = (u.moraleBuff > 0 ? 1.1 : 1) * legFactor(u) * (u.crouch ? 0.55 : 1);
  let gx = u.goal.x - u.pos.x, gz = u.goal.z - u.pos.z;
  if (u.detourT > 0) { u.detourT -= dt; gx = u.detour.x; gz = u.detour.z; }
  const gl = Math.hypot(gx, gz);
  let vx = 0, vz = 0;
  if (gl > 0.7 && u.wantSpeed > 0) { const s = Math.min(u.wantSpeed * speedMul, gl * 2); vx = gx / gl * s; vz = gz / gl * s; }
  // separation
  for (const o of G.units) {
    if (o === u || o.state !== 'alive' || o.inVehicle) continue;
    const dx = u.pos.x - o.pos.x, dz = u.pos.z - o.pos.z; const d2 = dx * dx + dz * dz;
    if (d2 < 1.4 && d2 > 1e-4) { const d = Math.sqrt(d2); vx += dx / d * (1.2 - d) * 3; vz += dz / d * (1.2 - d) * 3; }
  }
  u.vel.x = damp(u.vel.x, vx, 8, dt); u.vel.z = damp(u.vel.z, vz, 8, dt);
  const ox = u.pos.x, oz = u.pos.z;
  u.pos.x += u.vel.x * dt; u.pos.z += u.vel.z * dt;
  pushOut(u.pos, 0.35, u.pos.y);
  // stuck detection
  const moved = Math.hypot(u.pos.x - ox, u.pos.z - oz), expect = Math.hypot(u.vel.x, u.vel.z) * dt;
  if (expect > 0.01 && moved < expect * 0.3) { u.stuckT += dt; if (u.stuckT > 0.6 && u.detourT <= 0) { const s = Math.random() < 0.5 ? -1 : 1; u.detour = { x: -gz * s + rand(-1, 1), z: gx * s + rand(-1, 1) }; u.detourT = rand(0.8, 1.6); u.stuckT = 0; } }
  else u.stuckT = Math.max(0, u.stuckT - dt);
  u.pos.y = groundAt(u.pos.x, u.pos.z, u.pos.y + 0.3);
  // facing
  let want = null;
  if (u.target && (u.canSee || G.time - u.seenT < 2)) { aimPoint(u.target, tgt); want = Math.atan2(-(tgt.x - u.pos.x), -(tgt.z - u.pos.z)); const dy = tgt.y - (u.pos.y + 1.4); u.pitch = damp(u.pitch, Math.atan2(dy, Math.hypot(tgt.x - u.pos.x, tgt.z - u.pos.z)), 6, dt); }
  else if (u.patient) want = Math.atan2(-(u.patient.pos.x - u.pos.x), -(u.patient.pos.z - u.pos.z));
  else if (u.yawGoal !== undefined && u.alertT > 0) want = u.yawGoal;
  else if (Math.hypot(u.vel.x, u.vel.z) > 0.5) want = Math.atan2(-u.vel.x, -u.vel.z);
  if (want !== null) { const d = angDiff(u.yaw, want); u.yaw += clamp(d, -6 * dt, 6 * dt); }
  if (!u.target) u.pitch = damp(u.pitch, 0, 3, dt);
  // footsteps
  const sp = Math.hypot(u.vel.x, u.vel.z);
  u.stepDist += sp * dt;
  if (u.stepDist > 1.7) { u.stepDist = 0; SFX.footstep(u.pos, false, sp > 4.5); if (sp > 4 && Math.random() < 0.15) FX.splash(u.pos); }
}

export function legFactor(u) {
  let s = 0; for (const w of u.wounds) if (w.part.startsWith('leg')) s += w.sev;
  return clamp(1 - s / 140, 0.45, 1);
}

// ---------- animation ----------
export function animateUnit(u, dt) {
  const P = u.model.userData.parts; const m = u.model;
  m.position.copy(u.pos); m.rotation.y = u.yaw;
  if (u.state === 'alive') {
    const sp = Math.hypot(u.vel.x, u.vel.z);
    u.step += sp * dt * 2.4;
    const k = Math.min(1, sp / 3.5);
    let legW = 0; for (const w of u.wounds) if (w.part === 'legL') legW += w.sev;
    const swing = Math.sin(u.step) * 0.75 * k;
    const crouchK = u.crouch || u.healing ? 1 : 0;
    u.crouchAnim = damp(u.crouchAnim || 0, crouchK, 10, dt);
    const c = u.crouchAnim;
    P.hips.position.y = 0.93 - c * 0.42;
    P.legL.rotation.x = swing * (legW > 20 ? 0.5 : 1) * (1 - c * 0.5) - c * 1.25;
    P.legR.rotation.x = -swing * (1 - c * 0.5) - c * 0.35;
    P.body.position.y = Math.abs(Math.cos(u.step)) * 0.05 * k;
    P.body.rotation.set(0, 0, 0);
    P.torso.rotation.x = u.pitch * 0.7 + c * 0.15 + (u.healing ? 0.5 : 0);
    P.torso.rotation.z = Math.sin(u.step) * 0.04 * k;
    // arms
    u.recoil = damp(u.recoil || 0, 0, 14, dt);
    P.armR.rotation.x = -0.9 - u.recoil * 0.15; P.armL.rotation.x = -1.25;
    if (u.throwAnim > 0) { u.throwAnim -= dt; P.armR.rotation.x = -2.6 + (0.6 - u.throwAnim) * 5; }
    if (u.reloadAnim > 0) { u.reloadAnim -= dt; P.armL.rotation.x = -0.6 + Math.sin(u.reloadAnim * 6) * 0.3; P.gun.rotation.z = 0.4; } else P.gun.rotation.z = 0;
    if (u.healing) { P.armL.rotation.x = -0.9 + Math.sin(G.time * 10) * 0.2; P.armR.rotation.x = -1.0 + Math.cos(G.time * 10) * 0.2; }
  } else {
    // falling / lying
    u.fallT = Math.min(1, u.fallT + dt * 2.2);
    const f = u.fallT; const e = f * f * (3 - 2 * f);
    P.body.rotation.x = u.fallDir * 1.5 * e;
    P.body.position.y = 0.14 * e;
    P.hips.position.y = 0.93;
    P.legL.rotation.x = 0.2 * e; P.legR.rotation.x = -0.15 * e;
    if (u.state === 'down') {
      const t = G.time + u.id;
      P.armL.rotation.x = -0.5 + Math.sin(t * 2.2) * 0.4; P.armR.rotation.x = -1.6 + Math.sin(t * 1.7 + 1) * 0.5;
      P.legL.rotation.x = 0.2 + Math.sin(t * 1.3) * 0.25;
      P.headG.rotation.y = Math.sin(t * 0.9) * 0.5;
    } else { P.armL.rotation.x = -2.5 * e; P.armR.rotation.x = -0.3; }
  }
}

// ---------- main update ----------
let reinfT = 30;
const baseDroneT = [22, 16];
export function updateUnits(dt) {
  for (let i = G.units.length - 1; i >= 0; i--) {
    const u = G.units[i];
    if (u.spawnProt > 0) u.spawnProt -= dt;
    if (u.moraleBuff > 0) u.moraleBuff -= dt;
    if (u.alertT > 0) u.alertT -= dt;
    if (u.flee) { u.flee.t -= dt; if (u.flee.t <= 0) u.flee = null; }
    if (u.state === 'gone') { G.units.splice(i, 1); continue; }
    if (u.state === 'dead') {
      u.deadT += dt; if (!u.isPlayer) animateUnit(u, dt);
      if (u.deadT > 70 && !u.isPlayer) { u.state = 'gone'; G.scene.remove(u.model); if (u.squad) u.squad.members = u.squad.members.filter(m => m !== u); }
      continue;
    }
    if (u.inVehicle) continue;
    // bleeding
    if (u.bleed > 0) {
      if (u.state === 'alive') {
        u.hp -= u.bleed * dt;
        u.bleed = Math.max(0, u.bleed - dt * (u.bleed < 0.8 ? 0.06 : 0.015)); // light wounds clot
        if (Math.random() < u.bleed * dt * 1.5) FX.blood(_v.set(u.pos.x, u.pos.y + 0.9, u.pos.z), _d.set(0, -1, 0), 0.3);
        if (u.hp <= 0) { u.hp = 0; downOrDie(u); }
      }
    }
    if (u.state === 'down') {
      u.downTimer -= dt;
      if (!u.isPlayer && G.time > u.screamCd) { u.screamCd = G.time + rand(3, 7); SFX.scream(u.pos, u.voice, 0.8, Math.random() < 0.5); }
      if (u.downTimer <= 0) killUnit(u, u.lastAttacker, 'bleed', false);
      if (!u.isPlayer) animateUnit(u, dt);
      continue;
    }
    if (u.isPlayer) continue;
    // AI
    u.thinkT -= dt;
    if (u.thinkT <= 0) { u.thinkT = rand(0.28, 0.42); think(u); }
    if (u.reloadT > 0) u.reloadT -= dt;
    u.fireCd -= dt;
    // medic treatment
    u.healing = false;
    if (u.patient) {
      const d = u.pos.distanceTo(u.patient.pos);
      if (d < 1.6) {
        u.healing = true; u.healT += dt; u.wantSpeed = 0; u.goal.copy(u.pos);
        if (Math.random() < dt * 4) FX.healFx(u.patient.pos);
        if (u.healT > (u.patient.state === 'down' ? 3.2 : 2.2)) {
          const revived = healUnit(u.patient, u);
          if (u.patient.medicBy === u) u.patient.medicBy = null;
          u.patient = null; u.healT = 0;
          void revived;
        }
      }
    }
    moveAI(u, dt);
    aiFire(u, dt);
    // commander morale shouts
    if (u.role === 'commander') {
      u.shoutT -= dt;
      if (u.shoutT <= 0 && G.time > globalShoutT) {
        u.shoutT = rand(16, 28); globalShoutT = G.time + 7;
        const sq = u.squad; const engaged = sq && G.time - sq.engaged < 5;
        const flag = sq && sq.flag;
        const kind = engaged ? pick(['fire', 'hold', 'morale']) : flag && flag.owner === u.team ? pick(['hold', 'morale']) : 'advance';
        commanderShout(u, kind);
      }
    }
    animateUnit(u, dt);
    // enemy markers visible when spotted (they fired recently / aimed at)
    if (u.team === ENEMY) u.marker.visible = G.time - u.spottedByPlayer < 3;
  }
  // squads
  for (const sq of squads) {
    sq.objT -= dt;
    if (sq.objT <= 0) { sq.objT = 3; chooseObjective(sq); }
    if (!sq.leader || sq.leader.state !== 'alive') sq.leader = sq.members.find(m => m.state === 'alive' && !m.isPlayer) || null;
    if (sq.leader && sq.leader !== G.player) {
      const L = sq.leader;
      if (!L.target && !L.patient && !L.retreating && !(L.flee && L.flee.t > 0)) { L.goal.copy(sq.objective); L.wantSpeed = L.pos.distanceTo(sq.objective) > 4 ? 3.4 : 0; }
    }
  }
  for (let i = squads.length - 1; i >= 0; i--) if (!squads[i].members.some(m => m.state !== 'gone' && m.state !== 'dead')) squads.splice(i, 1);
  // drone crews at the bases launch UAVs on a schedule
  for (const t of [ALLY, ENEMY]) {
    baseDroneT[t] -= dt;
    if (baseDroneT[t] > 0) continue;
    baseDroneT[t] = rand(28, 42);
    const n = G.drones.filter(d => d.alive && d.team === t && d.controller === 'ai').length;
    if (n < 2 && G.teams[t].tickets > 0 && !G.over) {
      const b = BASES[t];
      launchDrone(t, Math.random() < 0.6 ? 'fpv' : 'bomber', new THREE.Vector3(b.x + 24, heightAt(b.x + 24, b.z + 3), b.z + 3), null);
    }
  }
  // reinforcements
  reinfT -= dt;
  if (reinfT <= 0) { reinfT = 30; reinforce(ALLY); reinforce(ENEMY); }
  ui.reinforceTimer(reinfT);
}

function downOrDie(u) {
  // bleeding out to 0 → incapacitated first, then death if untreated
  if (u.state === 'alive') {
    u.state = 'down'; u.hp = 1; u.downTimer = u.isPlayer ? 30 : rand(20, 35); u.fallT = 0; u.fallDir = 1; u.bleed = 0;
    SFX.scream(u.pos, u.voice, 1);
    onUnitDown(u);
  }
}

export function reinforce(team) {
  if (G.teams[team].tickets <= 0 || G.over) return;
  const alive = G.units.filter(u => u.team === team && !u.isPlayer && u.role !== 'basemedic' && (u.state === 'alive' || u.state === 'down')).length;
  const need = 15 - alive;
  let n = 0;
  for (let k = 0; k + 5 <= need + 2 && n < 3; k += 5) { spawnSquad(team); n++; }
  if (n && team === ALLY) {
    ui.message('📻 Подкрепление прибыло!', 2.5);
    const sq = squads[squads.length - 1];
    if (sq && sq.leader) setTimeout(() => commanderShout(sq.leader, 'reinforce'), 1200);
  }
}

export function spawnBaseMedics() {
  for (const b of BASES) {
    const u = createUnit(b.team, 'basemedic', new THREE.Vector3(b.med.x + 1.5, 0, b.med.z + 2), { name: b.team === ALLY ? 'Доктор Айболит' : 'Вражеский врач' });
    u.armor.vest = 0;
  }
}

export function markSpotted(u) { u.spottedByPlayer = G.time; }
export { MAP };
