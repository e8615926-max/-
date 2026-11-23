// Procedural low-poly models
import * as THREE from '../lib/three.module.min.js';
import { ALLY } from './state.js';

const L = (c, o = {}) => new THREE.MeshLambertMaterial({ color: c, ...o });
const B = (w, h, d) => new THREE.BoxGeometry(w, h, d);
const C = (rt, rb, h, s = 10) => new THREE.CylinderGeometry(rt, rb, h, s);
const mesh = (g, m, x = 0, y = 0, z = 0) => { const o = new THREE.Mesh(g, m); o.position.set(x, y, z); return o; };

export const MAT = {
  skin: L(0xc79a7a), skinDark: L(0xa77b5e),
  allyUni: L(0x4d5a35), allyUni2: L(0x3d4a2a), allyVest: L(0x3a4528), allyHelmet: L(0x445231),
  enemyUni: L(0x5b5e66), enemyUni2: L(0x474a52), enemyVest: L(0x33363c), enemyHelmet: L(0x3f4249),
  boot: L(0x1d1a17), black: L(0x18191b), gunMetal: L(0x2a2c2f), wood: L(0x6b3e1f), woodDark: L(0x4a2a14),
  allyBand: new THREE.MeshBasicMaterial({ color: 0x2f7dff }), enemyBand: new THREE.MeshBasicMaterial({ color: 0xff2a20 }),
  white: L(0xd8d8d0), red: new THREE.MeshBasicMaterial({ color: 0xc81010 }),
  wound: new THREE.MeshBasicMaterial({ color: 0x4a0303 }), woundFresh: new THREE.MeshBasicMaterial({ color: 0x8a0606 }),
  glass: new THREE.MeshBasicMaterial({ color: 0x0a1a22 }), lens: new THREE.MeshBasicMaterial({ color: 0x3a6a8a }),
  rotor: new THREE.MeshBasicMaterial({ color: 0x222222, transparent: true, opacity: 0.35, side: THREE.DoubleSide, depthWrite: false }),
  sandbag: L(0x8a7a55), tire: L(0x161616),
  allyTank: L(0x4b5a33), allyTank2: L(0x3c4828), enemyTank: L(0x6f6a55), enemyTank2: L(0x57533f), tankTrack: L(0x262422),
  burnt: L(0x1c1a18),
};

const G_ = {
  torso: B(0.42, 0.56, 0.25), vest: B(0.47, 0.42, 0.3), pack: B(0.34, 0.42, 0.18),
  head: B(0.21, 0.24, 0.22), helmet: new THREE.SphereGeometry(0.16, 10, 6, 0, Math.PI * 2, 0, Math.PI / 2),
  cap: C(0.13, 0.14, 0.09, 10), visor: B(0.18, 0.02, 0.1),
  upperArm: B(0.12, 0.33, 0.12).translate(0, -0.165, 0), foreArm: B(0.105, 0.3, 0.105).translate(0, -0.15, 0), hand: B(0.09, 0.1, 0.09),
  leg: B(0.17, 0.9, 0.19).translate(0, -0.45, 0), boot: B(0.16, 0.11, 0.28), band: B(0.13, 0.06, 0.13),
  wound: new THREE.SphereGeometry(0.045, 6, 4), stain: new THREE.SphereGeometry(0.085, 6, 4),
  cross: B(0.14, 0.04, 0.012), antenna: C(0.006, 0.006, 0.7, 4), tube: C(0.06, 0.06, 1.0, 8),
};

// ---------- third-person guns ----------
function tpGun(kind) {
  const g = new THREE.Group();
  const m = MAT.gunMetal;
  const len = { pistol: 0.2, rifle: 0.75, smg: 0.6, shotgun: 0.8, sniper: 1.15, mg: 1.05, rocket: 1.0 }[kind] || 0.75;
  if (kind === 'rocket') {
    g.add(mesh(C(0.045, 0.045, 1.0, 8).rotateX(Math.PI / 2), L(0x4b5532), 0, 0, -0.2));
    g.add(mesh(C(0.01, 0.075, 0.25, 8).rotateX(-Math.PI / 2), L(0x4b5532), 0, 0, -0.82));
  } else {
    g.add(mesh(B(0.06, 0.09, len * 0.55), m, 0, 0, -len * 0.25));
    g.add(mesh(C(0.014, 0.014, len * 0.5, 6).rotateX(Math.PI / 2), m, 0, 0.015, -len * 0.75));
    if (kind !== 'pistol') g.add(mesh(B(0.05, 0.08, 0.25), kind === 'sniper' || kind === 'rifle' ? MAT.wood : m, 0, -0.02, 0.12));
    if (kind === 'rifle' || kind === 'smg') g.add(mesh(B(0.04, 0.16, 0.06).translate(0, -0.08, 0).rotateX(0.3), m, 0, -0.04, -len * 0.33));
    if (kind === 'mg') g.add(mesh(B(0.12, 0.12, 0.12), m, 0.02, -0.07, -0.25));
    if (kind === 'sniper') g.add(mesh(C(0.025, 0.025, 0.3, 6).rotateX(Math.PI / 2), MAT.black, 0, 0.07, -0.3));
  }
  return g;
}

// ---------- soldier ----------
export function makeSoldier(team, role, weaponKind) {
  const ally = team === ALLY;
  const uni = ally ? MAT.allyUni : MAT.enemyUni, uni2 = ally ? MAT.allyUni2 : MAT.enemyUni2;
  const root = new THREE.Group();
  const body = new THREE.Group(); root.add(body);
  const hips = new THREE.Group(); hips.position.y = 0.93; body.add(hips);
  const legL = new THREE.Group(); legL.position.x = -0.11; hips.add(legL);
  const legR = new THREE.Group(); legR.position.x = 0.11; hips.add(legR);
  for (const lg of [legL, legR]) { lg.add(mesh(G_.leg, uni2)); lg.add(mesh(G_.boot, MAT.boot, 0, -0.87, -0.04)); }
  const torso = new THREE.Group(); hips.add(torso);
  const chest = mesh(G_.torso, uni, 0, 0.3, 0); torso.add(chest);
  torso.add(mesh(G_.vest, ally ? MAT.allyVest : MAT.enemyVest, 0, 0.34, 0));
  const packMat = role === 'medic' ? MAT.white : (ally ? MAT.allyVest : MAT.enemyVest);
  torso.add(mesh(G_.pack, packMat, 0, 0.32, 0.22));
  if (role === 'medic') { const c1 = mesh(G_.cross, MAT.red, 0, 0.38, 0.315); const c2 = c1.clone(); c2.rotation.z = Math.PI / 2; torso.add(c1, c2); }
  if (role === 'commander' || role === 'operator') torso.add(mesh(G_.antenna, MAT.black, 0.12, 0.85, 0.24));
  if (role === 'at') { const t = mesh(G_.tube, L(0x4b5532), 0.1, 0.4, 0.3); t.rotation.z = 0.5; torso.add(t); }
  const head = new THREE.Group(); head.position.y = 0.7; torso.add(head);
  const headM = mesh(G_.head, MAT.skin); head.add(headM);
  if (role === 'commander') { head.add(mesh(G_.cap, uni, 0, 0.14, 0)); head.add(mesh(G_.visor, MAT.black, 0, 0.11, -0.12)); }
  else { const h = mesh(G_.helmet, ally ? MAT.allyHelmet : MAT.enemyHelmet, 0, 0.04, 0); h.scale.set(1.05, 1.1, 1.1); head.add(h); }
  head.add(mesh(B(0.16, 0.04, 0.02), MAT.black, 0, 0.02, -0.112)); // eyes shadow
  const armL = new THREE.Group(); armL.position.set(-0.27, 0.52, 0); torso.add(armL);
  const armR = new THREE.Group(); armR.position.set(0.27, 0.52, 0); torso.add(armR);
  const fore = [];
  for (const a of [armL, armR]) {
    a.add(mesh(G_.upperArm, uni));
    const f = new THREE.Group(); f.position.y = -0.32; a.add(f); fore.push(f);
    f.add(mesh(G_.foreArm, uni)); f.add(mesh(G_.hand, MAT.skin, 0, -0.32, 0));
  }
  const band = mesh(G_.band, role === 'medic' ? MAT.white : (ally ? MAT.allyBand : MAT.enemyBand), 0, -0.1, 0); armL.add(band);
  const band2 = mesh(G_.band, ally ? MAT.allyBand : MAT.enemyBand, 0, -0.1, 0); armR.add(band2);
  // rifle pose
  armR.rotation.set(-0.9, 0, -0.15); fore[1].rotation.x = -0.7;
  armL.rotation.set(-1.25, 0, 0.55); fore[0].rotation.x = -0.25;
  const gun = tpGun(weaponKind); gun.position.set(0.06, 0.4, -0.38); torso.add(gun);
  root.userData.parts = { body, hips, torso, chest, head: headM, headG: head, legL, legR, armL, armR, foreL: fore[0], foreR: fore[1], gun };
  root.userData.hit = [
    { part: 'head', o: headM, off: new THREE.Vector3(0, 0.02, 0), r: 0.15 },
    { part: 'torso', o: chest, off: new THREE.Vector3(0, 0.12, 0), r: 0.26 },
    { part: 'torso', o: chest, off: new THREE.Vector3(0, -0.18, 0), r: 0.24 },
    { part: 'armL', o: armL, off: new THREE.Vector3(0, -0.22, 0), r: 0.09 },
    { part: 'armR', o: armR, off: new THREE.Vector3(0, -0.22, 0), r: 0.09 },
    { part: 'legL', o: legL, off: new THREE.Vector3(0, -0.25, 0), r: 0.13 },
    { part: 'legL', o: legL, off: new THREE.Vector3(0, -0.65, 0), r: 0.11 },
    { part: 'legR', o: legR, off: new THREE.Vector3(0, -0.25, 0), r: 0.13 },
    { part: 'legR', o: legR, off: new THREE.Vector3(0, -0.65, 0), r: 0.11 },
  ];
  root.traverse(o => { if (o.isMesh) o.castShadow = true; });
  return root;
}

export function replaceTpGun(model, kind) {
  const p = model.userData.parts; const old = p.gun; const g = tpGun(kind); g.position.copy(old.position); g.rotation.copy(old.rotation);
  old.parent.add(g); old.parent.remove(old); p.gun = g;
}

export function addWoundDecal(obj, localPoint, severe) {
  const w = mesh(G_.wound, severe ? MAT.woundFresh : MAT.wound); w.position.copy(localPoint);
  const s = mesh(G_.stain, MAT.wound); s.position.copy(localPoint); s.scale.set(1, 1.6, 0.35);
  w.scale.setScalar(severe ? 1.3 : 1);
  obj.add(w); obj.add(s);
  return [w, s];
}

// ---------- tanks ----------
export const TANK_TYPES = {
  light: { name: 'БМП-3', hp: 650, speed: 12, turn: 0.9, w: 3.0, h: 1.05, l: 5.8, turretRate: 1.6, gun: 'autocannon', reload: 0.18, mg: true, armor: 0.85, price: 0 },
  medium: { name: 'Т-72Б3', hp: 1200, speed: 9, turn: 0.65, w: 3.4, h: 1.2, l: 6.8, turretRate: 0.75, gun: 'cannon', reload: 3.6, mg: true, armor: 0.6, price: 0 },
  heavy: { name: 'Т-90М «Прорыв»', hp: 1800, speed: 7, turn: 0.5, w: 3.7, h: 1.35, l: 7.2, turretRate: 0.6, gun: 'cannon', reload: 4.4, mg: true, armor: 0.45, price: 0 },
};

export function makeTank(type, team) {
  const T = TANK_TYPES[type]; const ally = team === ALLY;
  const m1 = ally ? MAT.allyTank : MAT.enemyTank, m2 = ally ? MAT.allyTank2 : MAT.enemyTank2;
  const root = new THREE.Group();
  const hull = new THREE.Group(); root.add(hull);
  const { w, h, l } = T;
  hull.add(mesh(B(w * 0.78, h * 0.6, l * 0.95), m1, 0, 0.55 + h * 0.5, 0));
  const glacis = mesh(B(w * 0.78, h * 0.55, 1.2), m1, 0, 0.5 + h * 0.4, -l * 0.47); glacis.rotation.x = 0.7; hull.add(glacis);
  hull.add(mesh(B(w * 0.98, 0.12, l * 0.9), m2, 0, 0.55 + h * 0.82, 0)); // fenders
  for (const sx of [-1, 1]) {
    hull.add(mesh(B(w * 0.22, 0.9, l), MAT.tankTrack, sx * w * 0.39, 0.5, 0));
    const nW = type === 'light' ? 6 : 6;
    for (let i = 0; i < nW; i++) {
      const wh = mesh(C(0.36, 0.36, 0.12, 10), MAT.tire, sx * (w * 0.5 + 0.02), 0.42, -l * 0.4 + i * (l * 0.8 / (nW - 1)));
      wh.rotation.z = Math.PI / 2; hull.add(wh);
    }
  }
  if (type === 'light') { // troop hatches + side boxes
    hull.add(mesh(B(w * 0.6, 0.25, 1.4), m2, 0, 0.6 + h + 0.05, 1.7));
  }
  hull.add(mesh(C(0.25, 0.25, 0.6, 8), MAT.black, -w * 0.3, 0.7 + h * 0.7, l * 0.48)); // exhaust
  if (type !== 'light') { // fuel barrels
    for (const sx of [-0.25, 0.25]) { const b = mesh(C(0.25, 0.25, w * 0.35, 10), m2, sx * w, 0.7 + h, l * 0.52); b.rotation.z = Math.PI / 2; hull.add(b); }
  }
  const turret = new THREE.Group(); turret.position.set(0, 0.55 + h * 0.85, type === 'light' ? -0.4 : 0.3); hull.add(turret);
  let tH;
  if (type === 'light') {
    tH = 0.55; turret.add(mesh(B(1.5, tH, 1.8), m1, 0, tH / 2, 0));
    turret.add(mesh(B(0.3, 0.3, 0.4), MAT.black, 0.5, tH + 0.15, 0.2));
  } else if (type === 'medium') {
    tH = 0.7; const t = mesh(new THREE.SphereGeometry(1.35, 14, 8, 0, Math.PI * 2, 0, Math.PI / 2), m1, 0, 0.05, 0.1); t.scale.set(1, 0.55, 1.15); turret.add(t);
    turret.add(mesh(C(0.35, 0.35, 0.25, 10), m2, 0.45, 0.75, 0.4));
  } else {
    tH = 0.85; turret.add(mesh(B(2.5, tH, 2.9), m1, 0, tH / 2, 0.2));
    for (let i = 0; i < 4; i++) for (const sx of [-1, 1]) { const e = mesh(B(0.45, 0.32, 0.5), m2, sx * 0.85, tH * 0.55, -1.0 - i * 0.02); e.rotation.y = sx * 0.6; if (i === 0) turret.add(e); }
    turret.add(mesh(B(2.6, 0.12, 0.6), m2, 0, tH * 0.85, -1.05)); // ERA brow
    turret.add(mesh(B(0.5, 0.35, 0.5), MAT.black, 0.7, tH + 0.17, 0.3)); // RWS
    turret.add(mesh(B(2.2, 0.5, 0.9), m2, 0, tH * 0.5, 1.9)); // bustle
  }
  // markings
  const mk = ally ? MAT.allyBand : MAT.enemyBand;
  for (const sx of [-1, 1]) { const s = mesh(B(0.03, 0.18, 0.6), mk, sx * (type === 'heavy' ? 1.26 : type === 'light' ? 0.76 : 1.15), tH * 0.55, 0.3); turret.add(s); }
  const gunPivot = new THREE.Group(); gunPivot.position.set(0, tH * 0.55, type === 'heavy' ? -1.3 : -0.9); turret.add(gunPivot);
  const bl = type === 'light' ? 2.4 : type === 'medium' ? 4.6 : 5.0, br = type === 'light' ? 0.06 : 0.11;
  gunPivot.add(mesh(C(br, br * 1.25, bl, 10).rotateX(Math.PI / 2), m2, 0, 0, -bl / 2));
  if (type !== 'light') gunPivot.add(mesh(C(br * 1.7, br * 1.7, 0.6, 10).rotateX(Math.PI / 2), m2, 0, 0, -bl * 0.55));
  gunPivot.add(mesh(B(0.5, 0.45, 0.5), m1, 0, 0, 0.0));
  const muzzle = new THREE.Object3D(); muzzle.position.set(0, 0, -bl - 0.1); gunPivot.add(muzzle);
  const mgMuzzle = new THREE.Object3D(); mgMuzzle.position.set(0.35, 0.05, -0.6); gunPivot.add(mgMuzzle);
  root.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = false; } });
  return { root, hull, turret, gunPivot, muzzle, mgMuzzle, eye: new THREE.Vector3(0.35, tH + 0.45, -0.2) };
}

// ---------- AA gun (ПВО) ----------
export function makeAA(team) {
  const ally = team === ALLY; const m1 = ally ? MAT.allyTank : MAT.enemyTank, m2 = ally ? MAT.allyTank2 : MAT.enemyTank2;
  const root = new THREE.Group();
  // sandbag ring
  const sb = B(0.9, 0.45, 0.5);
  for (let i = 0; i < 14; i++) { const a = i / 14 * Math.PI * 2; if (i === 3 || i === 4) continue; for (let k = 0; k < 2; k++) { const s = mesh(sb, MAT.sandbag, Math.cos(a + k * 0.2) * 2.4, 0.22 + k * 0.42, Math.sin(a + k * 0.2) * 2.4); s.rotation.y = -a; root.add(s); } }
  root.add(mesh(C(0.9, 1.1, 0.4, 12), m2, 0, 0.2, 0));
  const yawG = new THREE.Group(); yawG.position.y = 0.45; root.add(yawG);
  yawG.add(mesh(C(0.7, 0.8, 0.3, 12), m1, 0, 0.15, 0));
  yawG.add(mesh(B(0.2, 1.0, 0.8), m1, -0.55, 0.75, 0)); yawG.add(mesh(B(0.2, 1.0, 0.8), m1, 0.55, 0.75, 0));
  yawG.add(mesh(B(0.5, 0.1, 0.5), MAT.black, 0, 0.55, 0.7)); // seat
  yawG.add(mesh(B(1.4, 0.8, 0.06), m2, 0, 1.4, -0.35)); // shield
  const pitchG = new THREE.Group(); pitchG.position.y = 1.15; yawG.add(pitchG);
  pitchG.add(mesh(B(0.85, 0.4, 1.2), m1, 0, 0, 0));
  const muzzles = [];
  for (const sx of [-0.25, 0.25]) {
    pitchG.add(mesh(C(0.05, 0.05, 2.6, 8).rotateX(Math.PI / 2), MAT.gunMetal, sx, 0.05, -1.8));
    pitchG.add(mesh(C(0.09, 0.09, 0.35, 8).rotateX(Math.PI / 2), MAT.gunMetal, sx, 0.05, -3.0));
    pitchG.add(mesh(B(0.18, 0.3, 0.35), m2, sx * 2.4, 0.15, 0.1)); // ammo boxes
    const mz = new THREE.Object3D(); mz.position.set(sx, 0.05, -3.2); pitchG.add(mz); muzzles.push(mz);
  }
  // radar dish
  const radar = new THREE.Group(); radar.position.set(0.9, 1.7, 0.4); yawG.add(radar);
  radar.add(mesh(C(0.02, 0.02, 0.6, 4), MAT.black, 0, -0.3, 0));
  const dish = mesh(new THREE.SphereGeometry(0.35, 10, 6, 0, Math.PI * 2, 0, Math.PI / 3), MAT.white, 0, 0, 0); dish.rotation.x = Math.PI / 2; radar.add(dish);
  root.traverse(o => { if (o.isMesh) o.castShadow = true; });
  return { root, yawG, pitchG, muzzles, radar };
}

// ---------- drones ----------
export function makeDrone(type, team) {
  const ally = team === ALLY;
  const root = new THREE.Group();
  const big = type === 'bomber';
  const s = big ? 1.6 : 1;
  const bodyM = L(ally ? 0x3b4230 : 0x3a3a3e);
  root.add(mesh(B(0.22 * s, 0.08 * s, 0.32 * s), bodyM));
  root.add(mesh(B(0.06, 0.05, 0.05), MAT.lens, 0, 0.02, -0.17 * s));
  const rotors = [];
  const n = big ? 6 : 4;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + Math.PI / n;
    const r = 0.3 * s;
    const arm = mesh(B(0.025, 0.02, r), MAT.black, Math.sin(a) * r / 2, 0, Math.cos(a) * r / 2); arm.rotation.y = a; root.add(arm);
    root.add(mesh(C(0.025, 0.025, 0.05, 6), MAT.black, Math.sin(a) * r, 0.03, Math.cos(a) * r));
    const rot = mesh(new THREE.CircleGeometry(0.13 * (big ? 1.25 : 1), 12), MAT.rotor, Math.sin(a) * r, 0.065, Math.cos(a) * r); rot.rotation.x = -Math.PI / 2; root.add(rot); rotors.push(rot);
  }
  const led = mesh(B(0.03, 0.03, 0.03), ally ? MAT.allyBand : MAT.enemyBand, 0, 0.05, 0.16 * s); root.add(led);
  if (type === 'fpv') { // warhead
    root.add(mesh(C(0.04, 0.05, 0.3, 8).rotateX(Math.PI / 2), L(0x4b5532), 0, -0.07, -0.05));
    root.add(mesh(C(0.0, 0.04, 0.08, 8).rotateX(-Math.PI / 2), L(0x4b5532), 0, -0.07, -0.24));
  } else {
    for (const sx of [-0.12, 0.12]) root.add(mesh(new THREE.SphereGeometry(0.05, 6, 4), L(0x3a4a2a), sx, -0.1, 0));
  }
  return { root, rotors };
}

// ---------- first-person viewmodels ----------
export const VM_MAT = {
  metal: new THREE.MeshLambertMaterial({ color: 0x2b2d31 }), metal2: new THREE.MeshLambertMaterial({ color: 0x3d4045 }),
  wood: new THREE.MeshLambertMaterial({ color: 0x7a4422 }), poly: new THREE.MeshLambertMaterial({ color: 0x1e1f21 }),
  glove: new THREE.MeshLambertMaterial({ color: 0x2a2a22 }), sleeve: new THREE.MeshLambertMaterial({ color: 0x4d5a35 }),
  skin: new THREE.MeshLambertMaterial({ color: 0xc79a7a }), green: new THREE.MeshLambertMaterial({ color: 0x4b5532 }),
  lens: new THREE.MeshBasicMaterial({ color: 0x1c3e55 }), sight: new THREE.MeshBasicMaterial({ color: 0xff3020 }),
};

export function makeViewModel(id) {
  const M = VM_MAT; const g = new THREE.Group(); const gun = new THREE.Group(); g.add(gun);
  let muzzleZ = -0.6, sightY = 0.07, ejectZ = -0.15;
  const add = (geo, m, x, y, z) => { const o = mesh(geo, m, x, y, z); gun.add(o); return o; };
  const barrel = (r, len, z, y = 0.03) => add(C(r, r, len, 8).rotateX(Math.PI / 2), M.metal, 0, y, z);
  switch (id) {
    case 'pm':
      add(B(0.04, 0.05, 0.19), M.metal2, 0, 0.03, -0.12); add(B(0.038, 0.11, 0.06), M.poly, 0, -0.04, -0.06).rotation.x = 0.25;
      add(B(0.008, 0.012, 0.01), M.metal, 0, 0.06, -0.2); muzzleZ = -0.23; sightY = 0.062; break;
    case 'ak':
      add(B(0.05, 0.075, 0.38), M.metal, 0, 0.02, -0.2); add(B(0.052, 0.05, 0.22), M.wood, 0, 0.015, -0.48);
      barrel(0.012, 0.42, -0.65); add(B(0.04, 0.03, 0.2), M.metal2, 0, 0.065, -0.3);
      const mag = add(B(0.035, 0.19, 0.08).translate(0, -0.09, 0), M.wood, 0, -0.02, -0.25); mag.rotation.x = 0.35; mag.material = new THREE.MeshLambertMaterial({ color: 0x8a4a22 });
      add(B(0.04, 0.09, 0.05).translate(0, -0.045, 0), M.wood, 0, -0.01, -0.07).rotation.x = 0.4;
      add(B(0.045, 0.07, 0.3), M.wood, 0, -0.005, 0.12); add(B(0.01, 0.03, 0.01), M.metal, 0, 0.07, -0.84);
      muzzleZ = -0.88; sightY = 0.075; break;
    case 'smg':
      add(B(0.05, 0.07, 0.42), M.metal, 0, 0.02, -0.18); barrel(0.012, 0.2, -0.47);
      add(C(0.04, 0.04, 0.42, 10).rotateX(Math.PI / 2), M.poly, 0, -0.035, -0.2); // helical mag
      add(B(0.04, 0.09, 0.05).translate(0, -0.045, 0), M.poly, 0, -0.01, -0.02).rotation.x = 0.4;
      add(B(0.02, 0.04, 0.22), M.metal2, 0, 0.0, 0.15); add(B(0.01, 0.025, 0.01), M.metal, 0, 0.065, -0.55);
      muzzleZ = -0.6; sightY = 0.07; break;
    case 'shotgun':
      add(B(0.055, 0.08, 0.36), M.poly, 0, 0.02, -0.18); barrel(0.018, 0.5, -0.6);
      add(B(0.05, 0.16, 0.09).translate(0, -0.08, 0), M.poly, 0, -0.02, -0.22).rotation.x = 0.1;
      add(B(0.045, 0.09, 0.05).translate(0, -0.045, 0), M.poly, 0, -0.01, -0.05).rotation.x = 0.4;
      add(B(0.05, 0.07, 0.3), M.poly, 0, -0.01, 0.13); add(B(0.01, 0.02, 0.01), M.sight, 0, 0.07, -0.83);
      muzzleZ = -0.87; sightY = 0.072; break;
    case 'svd':
      add(B(0.05, 0.07, 0.4), M.metal, 0, 0.02, -0.18); add(B(0.05, 0.05, 0.3), M.wood, 0, 0.012, -0.5); barrel(0.011, 0.6, -0.9);
      add(B(0.03, 0.14, 0.08).translate(0, -0.07, 0), M.poly, 0, -0.02, -0.25).rotation.x = 0.15;
      add(B(0.045, 0.14, 0.3), M.wood, 0, -0.02, 0.15); add(B(0.03, 0.07, 0.18), M.wood, 0, 0.01, 0.05);
      add(C(0.025, 0.025, 0.3, 10).rotateX(Math.PI / 2), M.poly, 0, 0.1, -0.2);
      add(C(0.033, 0.03, 0.06, 10).rotateX(Math.PI / 2), M.poly, 0, 0.1, -0.37); add(new THREE.CircleGeometry(0.025, 10), M.lens, 0, 0.1, -0.05);
      muzzleZ = -1.22; sightY = 0.1; break;
    case 'pkm':
      add(B(0.065, 0.09, 0.45), M.metal, 0, 0.02, -0.18); barrel(0.016, 0.6, -0.7); add(C(0.025, 0.025, 0.12, 8).rotateX(Math.PI / 2), M.metal2, 0, 0.03, -0.42);
      add(B(0.1, 0.13, 0.14), M.green, 0.06, -0.07, -0.22); // ammo box
      add(B(0.04, 0.09, 0.05).translate(0, -0.045, 0), M.wood, 0, -0.02, -0.03).rotation.x = 0.4;
      add(B(0.045, 0.08, 0.32), M.wood, 0, -0.015, 0.16); add(B(0.01, 0.03, 0.01), M.metal, 0, 0.075, -0.95);
      add(C(0.006, 0.006, 0.3, 4), M.metal, -0.05, -0.12, -0.85).rotation.x = 0.4; add(C(0.006, 0.006, 0.3, 4), M.metal, 0.05, -0.12, -0.85).rotation.x = 0.4;
      muzzleZ = -1.0; sightY = 0.08; break;
    case 'rpg':
      add(C(0.042, 0.042, 1.0, 10).rotateX(Math.PI / 2), M.green, 0, 0.0, -0.25);
      add(C(0.012, 0.085, 0.25, 10).rotateX(-Math.PI / 2), M.green, 0, 0.0, -0.88);
      add(C(0.06, 0.042, 0.15, 10).rotateX(Math.PI / 2), M.metal, 0, 0.0, 0.28);
      add(B(0.04, 0.1, 0.05).translate(0, -0.05, 0), M.wood, 0, -0.045, -0.1); add(B(0.04, 0.1, 0.05).translate(0, -0.05, 0), M.wood, 0, -0.045, -0.3);
      add(B(0.03, 0.05, 0.08), M.metal, -0.05, 0.06, -0.15);
      muzzleZ = -1.02; sightY = 0.07; break;
    case 'grenade':
      add(new THREE.SphereGeometry(0.04, 10, 8), M.green, 0, 0, 0); add(C(0.012, 0.012, 0.04, 6), M.metal, 0, 0.045, 0);
      break;
  }
  // hands & sleeves
  const handR = new THREE.Group(); handR.position.set(0.0, -0.04, id === 'pm' ? -0.06 : -0.06); gun.add(handR);
  handR.add(mesh(B(0.06, 0.07, 0.1), M.glove, 0, -0.03, 0)); const slR = mesh(B(0.075, 0.075, 0.24), M.sleeve, 0.02, -0.06, 0.16); slR.rotation.x = 0.2; handR.add(slR);
  const handL = new THREE.Group(); handL.position.set(-0.01, -0.035, id === 'pm' ? -0.1 : id === 'rpg' ? -0.3 : -0.4); gun.add(handL);
  handL.add(mesh(B(0.07, 0.06, 0.1), M.glove, 0, -0.01, 0)); const slL = mesh(B(0.075, 0.075, 0.26), M.sleeve, -0.06, -0.06, 0.16); slL.rotation.set(0.25, -0.5, 0); handL.add(slL);
  const muzzle = new THREE.Object3D(); muzzle.position.set(0, 0.03, muzzleZ); gun.add(muzzle);
  g.userData = { gun, muzzle, sightY, ejectZ, handL };
  return g;
}

// flag on a pole
export function makeFlag() {
  const g = new THREE.Group();
  g.add(mesh(C(0.07, 0.09, 9, 8), MAT.gunMetal, 0, 4.5, 0));
  const clothMat = new THREE.MeshLambertMaterial({ color: 0xbbbbbb, side: THREE.DoubleSide });
  const geo = new THREE.PlaneGeometry(2.4, 1.4, 8, 4); geo.translate(1.2, 0, 0);
  const cloth = new THREE.Mesh(geo, clothMat); cloth.position.y = 8.1; g.add(cloth);
  g.userData = { cloth, clothMat, base: geo.attributes.position.array.slice() };
  return g;
}
